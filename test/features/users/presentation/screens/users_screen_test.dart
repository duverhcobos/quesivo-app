import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:quesivo/features/users/presentation/screens/users_screen.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  testWidgets('muestra título, botón Nuevo usuario y filas de muestra', (
    tester,
  ) async {
    // UsersScreen consulta context.canPop() para el back arrow — necesita
    // un GoRouter vivo (mismo criterio del harness de QuesivoNavBar).
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, __) => const UsersScreen())],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    expect(find.text('Usuarios'), findsOneWidget);
    expect(find.text('Nuevo usuario'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Juan Gómez'), findsOneWidget);
    expect(find.text('Pedro Ruiz'), findsOneWidget);
  });
}
