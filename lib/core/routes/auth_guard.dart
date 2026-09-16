import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../logging/interfaces/i_logger_service.dart';

/// Guardia de Rutas de Autenticación.
///
/// SOLID (SRP): Delega al 100% la responsabilidad de decidir qué usuario
/// puede ver qué rutas basada en el contexto de negocio (Autenticación).
///
/// SOLID (OCP): Utiliza listas configurables de rutas públicas.
/// Si hay nuevas rutas públicas (Ej: Políticas), solo agregas a la lista,
/// sin modificar jamás los "if" estructurales.
///
/// SOLID (DIP): Recibe `ILoggerService` por constructor (inyectado desde
/// `setup_di.dart`), en vez de resolverlo desde el Service Locator.
///
/// Independencia de framework: `evaluate()` solo conoce un `String` (la ruta
/// actual) y el `AuthState` del dominio de la app — nada de `go_router`. Si
/// algún día se cambia de estrategia de routing (Navigator 2.0 a mano,
/// `auto_route`, `beamer`, etc.), esta clase no necesita tocarse: solo el
/// adaptador que la invoca (hoy, `AppRouter`).
class AuthGuard {
  final ILoggerService logger;
  final IOnboardingStatusStore onboardingStatus;

  AuthGuard(this.logger, this.onboardingStatus);

  // Lista declarativa de rutas abiertas a todo público sin sesión
  static const String splashRoute = '/splash';
  static const String homeRoute = '/home';
  static const String welcomeRoute = '/welcome';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';
  static const String onboardingRoute = '/onboarding';

  // Rutas de los 17 módulos del drawer (propuesta §26-modulos-placeholder,
  // corregida por §27-modulos-dentro-del-shell y reagrupada por
  // §35-tabs-modulos-diarios). Desde §35 son GoRoute TOP-LEVEL dentro del
  // branch de su dominio en el StatefulShellRoute — la raíz de cada branch
  // es el módulo del tab (Recepción/Producción/Ventas), ya no hay menús
  // intermedios — y NO van en `publicRoutes`: protegidas por defecto.
  // Branch Recepción (tab 1): entrada de leche + abastecimiento + directorio
  static const String receptionsRoute = '/operaciones/recepcion';
  static const String suppliesRoute = '/operaciones/inventario';
  static const String purchasesRoute = '/operaciones/compras';
  static const String ordersRoute = '/operaciones/pedidos';
  static const String producersRoute = '/catalogos/productores';
  static const String collectorsRoute = '/catalogos/recolectores';
  static const String suppliersRoute = '/catalogos/proveedores';
  static const String clientsRoute = '/catalogos/clientes';
  static const String toolsRoute = '/catalogos/utensilios';
  // Branch Producción (tab 2)
  static const String productionRoute = '/operaciones/produccion';
  // Branch Ventas (tab 3): venta directa + finanzas
  static const String salesRoute = '/operaciones/ventas';
  static const String settlementsRoute = '/dinero/liquidaciones';
  static const String advancesRoute = '/dinero/adelantos';
  static const String producerPaymentsRoute = '/dinero/pagos-productores';
  static const String expensesRoute = '/dinero/gastos';
  // Configuración (hijas del branch /home — no tiene tab propio)
  static const String orgDataRoute = '/home/organizacion';
  static const String orgUsersRoute = '/home/usuarios';

  // Lista declarativa de rutas abiertas a todo público sin sesión
  static const List<String> publicRoutes = [
    welcomeRoute,
    loginRoute,
    registerRoute,
    forgotPasswordRoute,
    resetPasswordRoute,
    onboardingRoute,
  ];

  /// Evalúa la navegación en base a la ruta actual y el estado de
  /// autenticación. Retorna la ruta destino a la que se debe redirigir, o
  /// `null` si se permite continuar hacia `location` sin cambios.
  String? evaluate(String location, AuthState authState) {
    logger.debug(
      'AuthGuard Evaluando navegación a $location (Estado: $authState)',
    );

    final isGoingToPublicRoute = publicRoutes.contains(location);
    final isGoingToSplash = location == splashRoute;

    // Si apenas abrimos la app y el Cubit está intentando despertar (Loading)
    // Nos mantenemos donde estamos (usualmente Splash)
    if (authState is AuthLoading) {
      logger.debug(
        'AuthGuard -> Acción: null (Quedarse cargando en $location)',
      );
      return null;
    }

    if (authState is AuthInitial || authState is AuthError) {
      if (!isGoingToPublicRoute) {
        // Sin sesión: si nunca vio el onboarding, esa es su primera parada.
        final target = onboardingStatus.isSeen ? welcomeRoute : onboardingRoute;
        logger.warning(
          'AuthGuard -> Acción: $target (Acceso restringido a ruta protegida)',
        );
        return target;
      }
    }

    // Si la sesión es válida (AuthSuccess)
    if (authState is AuthSuccess) {
      // Si está logueado, no tiene por qué estar merodeando en Login o Recuprar Contraseña
      if (isGoingToPublicRoute || isGoingToSplash) {
        logger.info(
          'AuthGuard -> Acción: $homeRoute (Redirigiendo usuario logueado)',
        );
        return homeRoute;
      }
    }

    logger.debug('AuthGuard -> Acción: null (Paso permitido hacia $location)');
    return null;
  }
}
