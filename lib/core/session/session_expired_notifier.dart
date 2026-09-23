// lib/core/session/session_expired_notifier.dart
import 'dart:async';

/// Bus de evento "la sesión ya no es recuperable".
///
/// Lo emite la capa de red (`RefreshTokenInterceptor`) cuando el refresh
/// token resulta inválido, expirado o revocado — el storage seguro ya
/// quedó limpio antes de notificar. Lo consume `AuthCubit` para emitir
/// `AuthInitial`, y `AuthGuard` redirige a welcome automáticamente
/// (`GoRouterRefreshStream` ya re-evalúa redirects en cada emisión).
///
/// Broadcast porque puede haber más de un listener a futuro (analytics,
/// logging). No expone datos: el evento es solo "sesión muerta".
class SessionExpiredNotifier {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notifySessionExpired() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
