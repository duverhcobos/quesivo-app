import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/di/setup_di.dart';
import 'core/localization/cubit/locale_cubit.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';

// main.dart 100% S.O.L.I.D.
void main() async {
  // 1. Delegamos el caótico arranque a un Bootstrap externo (SRP)
  await AppBootstrap.init();

  // 2. Extraemos las dependencias puras desde el Service Locator en la raíz
  final appRouter = locator<AppRouter>().router;
  final authCubit = locator<AuthCubit>();
  final localeCubit = locator<LocaleCubit>();

  // 3. Inyectamos explícitamente por constructor (DIP)
  runApp(
    MainApp(router: appRouter, authCubit: authCubit, localeCubit: localeCubit),
  );
}

/// Widget Raíz Puro y Testeable
///
/// SOLID (DIP): Ya no llama internamente a "locator" (DI anti-pattern para widgets).
/// Acepta sus dependencias completas a través del constructor. Esto permite mockear el
/// router o el state en testing de UI aisladamente, respetando la Inversión de Dependencias.
class MainApp extends StatelessWidget {
  final GoRouter router;
  final AuthCubit authCubit;
  final LocaleCubit localeCubit;

  const MainApp({
    super.key,
    required this.router,
    required this.authCubit,
    required this.localeCubit,
  });

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider inyecta instancias globales para las vistas (SRP)
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: localeCubit),
      ],
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (context, localeState) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Clean Architecture + SOLID App',
            routerConfig: router,

            // Inyectamos el Sistema Centralizado de Diseño Abstracto
            theme: AppTheme.lightTheme,
            // Diseño ÚNICO claro (decisión del usuario): no existe un tema
            // dark Quesivo diseñado — el darkTheme heredado del proyecto
            // origen (teal/verde/terracota) no es la marca y ThemeMode.system
            // rompía la UI en físico: texto claro sobre fills quesivoWhite
            // forzados, popups oscuros sobre cards blancas, cursores
            // invisibles. Mientras no se diseñe un dark Quesivo real, la app
            // ignora el tema del dispositivo. Cuando llegue, se define
            // darkTheme con tokens quesivo* y se revisita.
            themeMode: ThemeMode.light,
            // ---Internacionalización (i18n) ---
            // Forzamos el Locale que el usuario prefiera en el Cubit.
            // Si el estado es null, Flutter delega al sistema del celular inteligentemente.
            locale: localeState,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    );
  }
}
