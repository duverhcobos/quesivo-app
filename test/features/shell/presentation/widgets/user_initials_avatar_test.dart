import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/theme/app_colors.dart';
import 'package:quesivo/core/widgets/user_initials_avatar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('UserInitialAvatar', () {
    testWidgets('muestra 2 iniciales mayúsculas de las dos primeras palabras', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const UserInitialAvatar(displayName: 'mi quesera')),
      );

      expect(find.text('MQ'), findsOneWidget);
    });

    testWidgets('una sola palabra muestra 1 letra', (tester) async {
      await tester.pumpWidget(
        _wrap(const UserInitialAvatar(displayName: 'María')),
      );

      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('nombre vacío muestra ?', (tester) async {
      await tester.pumpWidget(
        _wrap(const UserInitialAvatar(displayName: '   ')),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('círculo amarillo con texto navy w700', (tester) async {
      await tester.pumpWidget(
        _wrap(const UserInitialAvatar(displayName: 'Mi Quesera')),
      );

      final text = tester.widget<Text>(find.text('MQ'));
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.color, AppColors.quesivoNavy);

      final container = tester.widget<Container>(
        find.ancestor(of: find.text('MQ'), matching: find.byType(Container)),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.quesivoYellow);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('withRing agrega el anillo blanco 20%', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UserInitialAvatar(displayName: 'Mi Quesera', withRing: true),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(of: find.text('MQ'), matching: find.byType(Container)),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.border!.top.width, 1.5);
    });
  });
}
