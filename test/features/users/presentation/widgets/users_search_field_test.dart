import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/presentation/widgets/users_search_field.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  Widget buildApp({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: UsersSearchField(controller: controller, onChanged: onChanged),
    ),
  );

  testWidgets('invoca onChanged al escribir', (tester) async {
    final controller = TextEditingController();
    var lastValue = '';
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildApp(controller: controller, onChanged: (value) => lastValue = value),
    );

    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pump();

    expect(lastValue, 'ana');
  });

  testWidgets(
    'el ícono de limpiar aparece solo con texto y al tocarlo limpia el '
    'controller e invoca onChanged con string vacío',
    (tester) async {
      final controller = TextEditingController();
      var lastValue = 'sin-invocar';
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          controller: controller,
          onChanged: (value) => lastValue = value,
        ),
      );

      expect(find.byIcon(Icons.close), findsNothing);

      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(lastValue, isEmpty);
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );

  testWidgets('el formatter bloquea símbolos y emojis al tipear', (
    tester,
  ) async {
    final controller = TextEditingController();
    var lastValue = '';
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildApp(controller: controller, onChanged: (value) => lastValue = value),
    );

    // Charset local del widget: unión de lo buscable (letras con
    // tildes/ñ/ü, dígitos, @ . _ % + - ' y espacio) — '!', '#', '$' y
    // los emojis quedan filtrados a nivel tecla.
    await tester.enterText(find.byType(TextField), 'a!n#a\$😀');
    await tester.pump();

    expect(controller.text, 'ana');
    expect(lastValue, 'ana');
  });
}
