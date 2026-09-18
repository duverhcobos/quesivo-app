import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/register_cubit.dart';
import '../../features/auth/presentation/cubit/reset_password_cubit.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';
import '../di/setup_di.dart';
import '../../features/home/presentation/screens/home_tab.dart';
import '../../features/shell/presentation/screens/module_placeholder_screen.dart';
import '../../features/shell/presentation/widgets/main_layout.dart';
import '../../features/users/presentation/screens/users_screen.dart';
import 'go_router_refresh_stream.dart';
import 'custom_transitions.dart';
import 'auth_guard.dart';

/// Configuración central del enrutador de la aplicación.
///
/// SOLID (SRP): Esta clase es tonta ("Dumb Config").
/// Solo define "qué URL pinta qué pantalla" y las transiciones animadas.
/// La compleja lógica de seguridad ha sido cedida permanentemente a `AuthGuard`.
class AppRouter {
  final AuthCubit authCubit;
  final AuthGuard authGuard;

  AppRouter(this.authCubit, this.authGuard);

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    // Le explicamos a GoRouter que re-evalúe el redirect CADA VEZ que el cubit emita
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    // Delegación limpia de responsabilidad (SRP): AuthGuard no conoce nada
    // de go_router, así que solo le pasamos la ruta actual como String.
    redirect: (context, state) =>
        authGuard.evaluate(state.matchedLocation, authCubit.state),
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => CustomTransitions.fade(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => CustomTransitions.fade(
          context: context,
          state: state,
          // El store se resuelve acá (DIP) — la pantalla no conoce el locator.
          child: OnboardingScreen(
            statusStore: locator<IOnboardingStatusStore>(),
          ),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => CustomTransitions.fade(
          context: context,
          state: state,
          child: const WelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          context: context,
          state: state,
          child: LoginScreen(cubit: locator<LoginCubit>()),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          context: context,
          state: state,
          // El cubit de formulario se resuelve acá (DIP) — la pantalla no
          // conoce el locator. Factory ⇒ instancia fresca por ingreso.
          child: RegisterScreen(cubit: locator<RegisterCubit>()),
        ),
      ),
      GoRoute(
        path: AuthGuard.forgotPasswordRoute,
        pageBuilder: (context, state) => CustomTransitions.fade(
          context: context,
          state: state,
          // El cubit de formulario se resuelve acá (DIP) — la pantalla no
          // conoce el locator. Factory ⇒ instancia fresca por ingreso.
          child: ForgotPasswordScreen(cubit: locator<ForgotPasswordCubit>()),
        ),
      ),
      GoRoute(
        path: AuthGuard.resetPasswordRoute,
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          context: context,
          state: state,
          // El cubit y el token del deep link se resuelven acá (DIP).
          child: ResetPasswordScreen(
            cubit: locator<ResetPasswordCubit>(
              param1: state.uri.queryParameters['token'] ?? '',
            ),
          ),
        ),
      ),
      // ------------------------------------------------------------------
      // Shell persistente post-auth: 4 tabs con stack y scroll propios
      // (StatefulShellRoute.indexedStack).
      //
      // Tabs = loop operativo diario (propuesta §35-tabs-modulos-diarios):
      // Inicio · Recepción · Producción · Ventas. Cada branch tiene como
      // RAÍZ el módulo del tab (ya no un menú intermedio) y el resto de
      // las 17 rutas de módulo se reparten como GoRoute TOP-LEVEL dentro
      // de la branch más cercana por dominio — las URLs no cambian, solo
      // la agrupación: /catalogos/* iluminan Recepción y /dinero/*
      // iluminan Ventas. Configuración sigue sin tab propio: sus módulos
      // cuelgan de /home (hijos anidados, igual que antes).
      //
      // Hoy todas pintan `ModulePlaceholderScreen`; cuando cada feature
      // real aterrice, su GoRoute reemplaza al placeholder conservando la
      // misma ruta. El label se resuelve acá con AppLocalizations (el
      // contexto del pageBuilder ya vive bajo Localizations).
      // ------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainLayout(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.homeRoute,
                builder: (_, _) => const HomeTab(),
                routes: [
                  // Configuración no tiene tab propio en el nav — sus
                  // módulos viven bajo el branch de Inicio (Inicio queda
                  // como el tab activo al visitarlos).
                  //
                  // OJO: el `path` de una GoRoute hija debe ser el
                  // segmento RELATIVO (sin el prefijo del padre) — go_router
                  // concatena por segmentos (`concatenatePaths`), así que
                  // usar el path completo de `AuthGuard.*Route` acá
                  // duplicaría el segmento del padre (bug §27→28: producía
                  // `/home/home/organizacion` en vez de `/home/organizacion`,
                  // por eso el push fallaba con "no routes for location").
                  GoRoute(
                    path: 'organizacion',
                    pageBuilder: (context, state) => CustomTransitions.fade(
                      context: context,
                      state: state,
                      child: ModulePlaceholderScreen(
                        icon: Icons.business_outlined,
                        label: AppLocalizations.of(context)!.orgDataItem,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'usuarios',
                    pageBuilder: (context, state) => CustomTransitions.fade(
                      context: context,
                      state: state,
                      child: const UsersScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Recepción: la raíz ES el módulo (re-tap del tab
          // vuelve acá). Las rutas de abastecimiento y del directorio
          // viven como GoRoute top-level de esta branch (mismo dominio:
          // todo lo que entra a la quesera), así iluminan este tab.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.receptionsRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.water_drop_outlined,
                    label: AppLocalizations.of(context)!.moduleReception,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.suppliesRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.inventory_2_outlined,
                    label: AppLocalizations.of(context)!.moduleSupplies,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.purchasesRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.shopping_bag_outlined,
                    label: AppLocalizations.of(context)!.modulePurchases,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.ordersRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.assignment_outlined,
                    label: AppLocalizations.of(context)!.moduleOrders,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.producersRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.groups_outlined,
                    label: AppLocalizations.of(context)!.moduleProducers,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.collectorsRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.local_shipping_outlined,
                    label: AppLocalizations.of(context)!.moduleCollectors,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.suppliersRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.storefront_outlined,
                    label: AppLocalizations.of(context)!.moduleSuppliers,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.clientsRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.people_outline,
                    label: AppLocalizations.of(context)!.moduleClients,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.toolsRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.kitchen_outlined,
                    label: AppLocalizations.of(context)!.moduleTools,
                  ),
                ),
              ),
            ],
          ),
          // Branch 2 — Producción: la raíz ES el módulo (hoy es la única
          // ruta del branch).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.productionRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.precision_manufacturing_outlined,
                    label: AppLocalizations.of(context)!.moduleProduction,
                  ),
                ),
              ),
            ],
          ),
          // Branch 3 — Ventas: la raíz ES el módulo. Las rutas de dinero
          // viven como GoRoute top-level de esta branch (mismo dominio:
          // todo lo que sale/se cobra), así iluminan este tab.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.salesRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.point_of_sale_outlined,
                    label: AppLocalizations.of(context)!.moduleSales,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.settlementsRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.receipt_long_outlined,
                    label: AppLocalizations.of(context)!.moduleSettlements,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.advancesRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.request_quote_outlined,
                    label: AppLocalizations.of(context)!.moduleAdvances,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.producerPaymentsRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.payments_outlined,
                    label: AppLocalizations.of(context)!.moduleProducerPayments,
                  ),
                ),
              ),
              GoRoute(
                path: AuthGuard.expensesRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  context: context,
                  state: state,
                  child: ModulePlaceholderScreen(
                    icon: Icons.money_off_outlined,
                    label: AppLocalizations.of(context)!.moduleExpenses,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
