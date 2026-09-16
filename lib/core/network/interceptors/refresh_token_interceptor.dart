// lib/core/network/interceptors/refresh_token_interceptor.dart
import 'package:dio/dio.dart';
import '../../constants/environment/environment.dart';
import '../../../features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';

/// Interceptor responsable de capturar errores 401 y refrescar el token.
///
/// SOLID (SRP): Aísla toda la coreografía de "token expiró -> refrescar ->
/// reintentar" fuera del resto de la capa de red.
///
/// ⚠️ PROVISIONAL: el contrato exacto del endpoint de refresh de stg/prod
/// todavía no fue confirmado por el equipo de backend. Este interceptor asume
/// `POST /auth/refresh` con body `{ "refreshToken": "..." }` y una respuesta
/// que incluya `token` (o `accessToken`) y opcionalmente `refreshToken`.
/// AJUSTAR ESTE CONTRATO en cuanto exista la definición real de la API.
class RefreshTokenInterceptor extends Interceptor {
  final ILocalAuthDataSource localDataSource;

  /// Provee el Dio "principal" (con todos sus interceptores) para reintentar
  /// la petición original una vez refrescado el token. Se inyecta como
  /// función porque el propio Dio principal es quien registra este
  /// interceptor (evita dependencia circular en el contenedor de DI).
  final Dio Function() mainDioProvider;

  bool _isRefreshing = false;

  RefreshTokenInterceptor(this.localDataSource, this.mainDioProvider);

  static const String _refreshPath = '/auth/refresh';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshCallItself = err.requestOptions.path.contains(_refreshPath);

    // Solo actuamos ante 401 de peticiones normales, nunca ante un 401 del
    // propio endpoint de refresh (evita loop infinito), y solo un refresh
    // concurrente a la vez.
    if (!isUnauthorized || isRefreshCallItself || _isRefreshing) {
      return super.onError(err, handler);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return super.onError(err, handler);
      }

      // Cliente Dio "limpio" (sin interceptores) exclusivamente para el
      // refresh: evita recursión si este mismo interceptor volviera a
      // interceptar su propia llamada.
      final refreshDio = Dio(BaseOptions(baseUrl: Environment.urlAuth));
      final refreshResponse = await refreshDio.post(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );

      final data = refreshResponse.data as Map<String, dynamic>;
      final newToken = data['token'] ?? data['accessToken'];
      final newRefreshToken = data['refreshToken'] ?? refreshToken;

      if (newToken == null) {
        return super.onError(err, handler);
      }

      await localDataSource.saveTokens(
        token: newToken as String,
        refreshToken: newRefreshToken as String,
      );

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';

      final response = await mainDioProvider().fetch(retryOptions);
      return handler.resolve(response);
    } catch (_) {
      // Si el refresh también falla, la sesión se considera perdida.
      await localDataSource.clearSession();
      return super.onError(err, handler);
    } finally {
      _isRefreshing = false;
    }
  }
}
