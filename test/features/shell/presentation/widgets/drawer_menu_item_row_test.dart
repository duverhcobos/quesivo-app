import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/theme/app_colors.dart';
import 'package:quesivo/features/shell/presentation/widgets/drawer/drawer_menu_item_row.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('DrawerMenuItemRow', () {
    testWidgets('renderiza ícono + label + chevron cuando está habilitada', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DrawerMenuItemRow(
            icon: Icons.water_drop_outlined,
            label: 'Recepción',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
      expect(find.text('Recepción'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('onTap dispara el callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DrawerMenuItemRow(
            icon: Icons.home_outlined,
            label: 'Inicio',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Inicio'));
      expect(tapped, isTrue);
    });

    testWidgets('seleccionada: fondo surface + ícono amarillo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerMenuItemRow(
            icon: Icons.water_drop_outlined,
            label: 'Recepción',
            selected: true,
            onTap: () {},
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.water_drop_outlined));
      expect(icon.color, AppColors.quesivoYellow);

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.quesivoSurface);
    });

    testWidgets('sin onTap ni route queda deshabilitada (Opacity 0.45)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DrawerMenuItemRow(
            icon: Icons.assignment_outlined,
            label: 'Pedidos',
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.45);
      // Sin chevron — no es accionable.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('expone Semantics selected para TalkBack', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerMenuItemRow(
            icon: Icons.water_drop_outlined,
            label: 'Recepción',
            selected: true,
            onTap: () {},
          ),
        ),
      );

      // Assert directo sobre el widget Semantics que la fila envuelve —
      // más confiable que consultar el árbol de semantics materializado.
      final sem = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Recepción' &&
            w.properties.selected == true &&
            w.properties.button == true,
      );
      expect(sem, findsOneWidget);
    });

    testWidgets('deshabilitada no se anuncia como botón', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DrawerMenuItemRow(
            icon: Icons.assignment_outlined,
            label: 'Pedidos',
          ),
        ),
      );

      final sem = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Pedidos',
      );
      expect(tester.widget<Semantics>(sem).properties.button, isFalse);
    });
  });
}
