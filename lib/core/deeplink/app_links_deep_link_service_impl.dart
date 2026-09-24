import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../logging/interfaces/i_logger_service.dart';
import '../routes/auth_guard.dart';
import 'i_deep_link_service.dart';

/// Implementación con el paquete `app_links` — soporta esquema custom
/// (`quesivo://...`) en Android/iOS sin necesitar dominio verificado.
class AppLinksDeepLinkServiceImpl implements IDeepLinkService {
  final AppLinks _appLinks;
  final ILoggerService _logger;
  StreamSubscription<Uri>? _subscription;

  AppLinksDeepLinkServiceImpl(this._logger, {AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  static const _scheme = 'quesivo';

  @override
  void initialize(GoRouter router) {
    // Cold start: la app se abrió DESDE el link (estaba cerrada). Se difiere
    // al primer frame: si navegamos antes de que MaterialApp.router procese
    // su ruta inicial (`/splash`), el parser sobreescribe el matchList con
    // splash y el link se pierde sin rastro (race no determinística).
    _appLinks
        .getInitialLink()
        .then((uri) async {
          if (uri == null) return;
          await WidgetsBinding.instance.endOfFrame;
          _handle(router, uri);
        })
        .catchError((Object e, StackTrace st) {
          _logger.warning(
            'No se pudo leer el deep link inicial',
            error: e,
            stackTrace: st,
          );
        });

    // La app ya estaba corriendo (foreground/background).
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handle(router, uri),
      onError: (Object e, StackTrace st) => _logger.error(
        'Error escuchando deep links entrantes',
        error: e,
        stackTrace: st,
      ),
    );
  }

  void _handle(GoRouter router, Uri uri) {
    if (uri.scheme != _scheme) return;

    final path = _normalizedPath(uri);

    // Solo reaccionamos a rutas públicas conocidas — un deep link con una
    // ruta que no reconocemos se ignora (fail-safe, no navegamos a ciegas).
    // Se loguea solo el path normalizado, NUNCA el query completo: ahí
    // viaja el token y en release estos logs van a Crashlytics.
    if (path != AuthGuard.resetPasswordRoute) {
      _logger.warning('Deep link con ruta desconocida ignorado: $path');
      return;
    }

    final target = uri.query.isEmpty ? path : '$path?${uri.query}';
    router.go(target);
  }

  /// Normaliza las variantes válidas de un URI de esquema custom a la
  /// misma ruta relativa:
  ///   quesivo://reset-password?token=x  → host='reset-password', path=''
  ///   quesivo:/reset-password?token=x   → host='', path='/reset-password'
  ///   quesivo:reset-password?token=x    → host='', path='reset-password'
  ///   quesivo://reset-password/?token=x → trailing slash
  String _normalizedPath(Uri uri) {
    var path = uri.host.isNotEmpty ? '/${uri.host}${uri.path}' : uri.path;
    if (!path.startsWith('/')) path = '/$path';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
