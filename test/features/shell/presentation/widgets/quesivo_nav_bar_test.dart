import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import 'package:quesivo/core/theme/app_colors.dart';
import 'package:quesivo/features/shell/presentation/widgets/quesivo_nav_bar.dart';

/// Harness con un StatefulShellRoute real — la barra necesita un
/// `StatefulNavigationShell` vivo, no se puede falsificar.
///
/// Capturamos el shell desde el builder para verificar `currentIndex`
/// tras los taps. Las 4 branches son placeholders `Text` simples.
class _Harness {
  _Harness() {
    router = GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) {
            capturedShell = shell;
            return Scaffold(
              body: shell,
              bottomNavigationBar: QuesivoNavBar(navigationShell: shell),
            );
          },
          branches: [
            for (final path in ['/a', '/b', '/c', '/d'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (context, state) => Center(child: Text(path)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  late final GoRouter router;
  StatefulNavigationShell? capturedShell;

  Widget build() => MaterialApp.router(
    routerConfig: router,
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  group('QuesivoNavBar', () {
    testWidgets('renderiza los 4 tabs del loop diario', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Recepción de leche'), findsOneWidget);
      expect(find.text('Producción'), findsOneWidget);
      expect(find.text('Ventas'), findsOneWidget);
    });

    testWidgets('el tab inicial marca amarillo + gota', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      // Inicio activo: ícono filled amarillo.
      final homeIcon = tester.widget<Icon>(find.byIcon(Icons.home));
      expect(homeIcon.color, AppColors.quesivoYellow);

      // La gota existe en los 4 items (invisible en inactivos) — el
      // marcador real es el AnimatedOpacity con opacity 1 del item activo.
      final visibleDrop = find.byWidgetPredicate(
        (w) => w is AnimatedOpacity && w.opacity == 1,
      );
      expect(visibleDrop, findsOneWidget);
      expect(
        find.descendant(
          of: visibleDrop,
          matching: find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.water_drop && w.size == 10,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tap en Recepción cambia el branch y marca el tab', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Recepción de leche'));
      await tester.pumpAndSettle();

      expect(harness.capturedShell!.currentIndex, 1);
      expect(find.text('/b'), findsOneWidget);

      // El ícono activo de recepción ahora es amarillo — el del tab es el
      // water_drop de 22px (la gota indicadora usa 10px).
      final icon = tester.widget<Icon>(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.water_drop && w.size == 22,
        ),
      );
      expect(icon.color, AppColors.quesivoYellow);
    });

    testWidgets('los inactivos quedan outlined blanco 60%', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      // Tab inactivo (Producción): ícono outlined y color blanco 60%.
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.precision_manufacturing_outlined),
      );
      expect(icon.color, AppColors.quesivoWhite.withValues(alpha: 0.6));
    });
  });
}
