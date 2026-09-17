// lib/core/network/interceptors/refresh_token_interceptor.dart
import 'dart:async';
import 'package:dio/dio.dart';

import '../../../features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';
import '../../session/session_expired_notifier.dart';

/// Interceptor responsable de capturar errores 401 y refrescar el token.
///
/// SOLID (SRP): Aísla toda la coreografía de "token expiró -> refrescar ->
/// reintentar" fuera del resto de la capa de red.
///
/// Contrato real (documentacion/api/auth/003-post-refresh.md, quesivo-api):
/// `POST /auth/refresh` con body `{ "refreshToken": "..." }` responde 200
/// `{ "accessToken": "...", "refreshToken": "..." }`. El refresh token
/// ROTA en cada llamada — el enviado queda revocado y hay que persistir
/// siempre el nuevo. Un 401 ahí significa sesión irrecuperable (token
/// inválido, expirado, o reuso detectado que revocó todas las sesiones):
/// se limpia storage y se notifica vía [SessionExpiredNotifier].
class RefreshTokenInterceptor extends Interceptor {
  final ILocalAuthDataSource localDataSource;
  final SessionExpiredNotifier sessionExpiredNotifier;

  /// Dio "principal" (con todos sus interceptores) para reintentar la
  /// petición original una vez refrescado el token. Se inyecta como
  /// función porque el propio Dio principal es quien registra este
  /// interceptor (evita dependencia circular en el contenedor de DI).
  final Dio Function() mainDioProvider;

  /// Dio "limpio" (sin interceptores) exclusivo para llamar al endpoint
  /// de refresh: evita recursión si este mismo interceptor volviera a
  /// interceptar su propia llamada. Inyectado para poder testearlo.
  final Dio Function() refreshDioProvider;

  /// Single-flight: un solo refresh en vuelo a la vez. Los 401 que llegan
  /// mientras hay un refresh corriendo esperan este completer y reintentan
  /// UNA vez con el token ya persistido (en vez de fallar directo).
  Completer<void>? _refreshCompleter;

  RefreshTokenInterceptor(
    this.localDataSource,
    this.sessionExpiredNotifier,
    this.mainDioProvider,
    this.refreshDioProvider,
  );

  static const String _refreshPath = '/auth/refresh';

  /// Endpoints exentos del flujo de refresh ante un 401:
  /// - `/auth/refresh`: un 401 es "sesión irrecuperable" — no hay nada
  ///   que refrescar.
  /// - `/auth/logout`: un 401 es "el token ya estaba muerto" — justo el
  ///   objetivo del logout. Refrescar acá rotaría el refresh token y
  ///   crearía una sesión nueva huérfana en el servidor mientras el
  ///   usuario se está yendo (propuesta 42).
  static const Set<String> _refreshExemptPaths = {_refreshPath, '/auth/logout'};

  /// Marca en `RequestOptions.extra` de que el request ya fue reintentado
  /// tras un refresh. Si vuelve a dar 401 se propaga el error en vez de
  /// re-entrar al flujo (guard anti-loop).
  static const String _retriedFlag = 'refreshRetried';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isExemptPath = _refreshExemptPaths.contains(err.requestOptions.path);
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    final hadAuthHeader = err.requestOptions.headers['Authorization'] != null;

    // Solo entra al flujo de refresh un 401 de petición autenticada aún no
    // reintentada. Un 401 sin Authorization (ej. login con credenciales
    // inválidas) no tiene sesión que refrescar; el 401 de una ruta exenta
    // o de un retry se propaga tal cual (sin loops ni rotaciones falsas).
    if (!isUnauthorized || isExemptPath || alreadyRetried || !hadAuthHeader) {
      return super.onError(err, handler);
    }

    // Otro request ya disparó el refresh: esperar a que termine y
    // reintentar UNA vez con el token ya guardado en storage.
    final inFlight = _refreshCompleter;
    if (inFlight != null) {
      try {
        await inFlight.future;
        return handler.resolve(await _retry(err.requestOptions));
      } catch (_) {
        return super.onError(err, handler);
      }
    }

    _refreshCompleter = Completer<void>();
    // Si el refresh falla sin que ningún request concurrente haya llegado
    // a esperar este completer, su error no tendría listeners y Dart lo
    // reportaría como async no manejado. ignore() solo silencia ese
    // reporte: quien sí haga await de inFlight.future recibe el error
    // normalmente.
    _refreshCompleter!.future.ignore();
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const _SessionDeadException();
      }

      final refreshResponse = await refreshDioProvider().post(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );

      final data = refreshResponse.data as Map<String, dynamic>;
      final newToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newToken == null || newRefreshToken == null) {
        // 200 sin los campos esperados: respuesta malformada del
        // servidor, no prueba de sesión muerta — transitorio.
        throw StateError('refresh response incompleta');
      }

      await localDataSource.saveTokens(
        token: newToken,
        refreshToken: newRefreshToken,
      );

      _refreshCompleter!.complete();
    } on DioException catch (e) {
      _refreshCompleter!.completeError(StateError('refresh failed'));
      // Solo un 401 del endpoint de refresh prueba sesión irrecuperable
      // (token inválido, expirado, o reuso detectado que revocó todas
      // las sesiones). Un timeout, un 5xx o red caída son transitorios:
      // se conserva la sesión y el próximo request reintentará.
      if (e.response?.statusCode == 401) {
        await _tryExpireSession();
      }
      return super.onError(err, handler);
    } on _SessionDeadException {
      _refreshCompleter!.completeError(StateError('refresh failed'));
      await _tryExpireSession();
      return super.onError(err, handler);
    } catch (_) {
      // Errores de storage, cast de la respuesta, etc.: transitorios,
      // la sesión se conserva.
      _refreshCompleter!.completeError(StateError('refresh failed'));
      return super.onError(err, handler);
    } finally {
      _refreshCompleter = null;
    }

    // El refresh salió bien — reintentar el request original. Si el
    // retry falla, es error del request (o de otro refresh posterior),
    // no de esta sesión: se propaga tal cual.
    try {
      return handler.resolve(await _retry(err.requestOptions));
    } catch (_) {
      return super.onError(err, handler);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final token = await localDataSource.getToken();
    options.headers['Authorization'] = 'Bearer $token';
    options.extra[_retriedFlag] = true;
    return mainDioProvider().fetch(options);
  }

  /// Wrapper que garantiza que un fallo de storage nunca impida propagar
  /// el error original del request — un throw acá puede dejar el
  /// handler sin resolver y colgar la petición del usuario.
  Future<void> _tryExpireSession() async {
    try {
      await _expireSession();
    } catch (_) {}
  }

  Future<void> _expireSession() async {
    // Si clearSession lanza (fallo del canal nativo de secure storage)
    // la notificación igual tiene que salir: es lo único que saca a la
    // UI del estado "logueado zombie".
    try {
      await localDataSource.clearSession();
    } finally {
      sessionExpiredNotifier.notifySessionExpired();
    }
  }
}

/// Marcador interno: el refresh token ni siquiera existe en storage —
/// sesión irrecuperable sin necesidad de pegarle a la API.
class _SessionDeadException implements Exception {
  const _SessionDeadException();
}
