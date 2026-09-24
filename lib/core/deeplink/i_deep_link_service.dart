import 'package:go_router/go_router.dart';

/// Contrato del servicio de deep links entrantes (forgot/reset password
/// hoy; cualquier flujo futuro que necesite abrir la app desde un link
/// externo se agrega acá).
///
/// SOLID (DIP): la capa de presentación/bootstrap no conoce el paquete
/// concreto (`app_links`) — solo este contrato.
abstract class IDeepLinkService {
  /// Arranca la escucha de deep links (cold start + con la app ya
  /// corriendo) y navega con [router] cuando la URI corresponde a una
  /// ruta pública conocida.
  void initialize(GoRouter router);

  /// Libera la suscripción — se llama si la app tuviera un ciclo de vida
  /// que lo requiera (hoy no aplica, pero completa el contrato).
  Future<void> dispose();
}
