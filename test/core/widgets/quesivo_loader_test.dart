import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/widgets/quesivo_loader.dart';

void main() {
  Widget buildApp({
    QuesivoLoaderVariant variant = QuesivoLoaderVariant.accent,
    String? semanticLabel,
    bool disableAnimations = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: QuesivoLoader(
            size: 40,
            variant: variant,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    ),
  );

  // El CustomPaint propio del loader (no los internos de Material).
  Finder loaderPaint() => find.descendant(
    of: find.byType(QuesivoLoader),
    matching: find.byType(CustomPaint),
  );

  testWidgets('renderiza las 3 variantes — CustomPaint presente en cada una', (
    tester,
  ) async {
    for (final variant in QuesivoLoaderVariant.values) {
      await tester.pumpWidget(buildApp(variant: variant));
      // Un pump simple — la rotación es infinita y nunca settlea.
      await tester.pump();
      expect(loaderPaint(), findsOneWidget);
    }
  });

  testWidgets('semanticLabel envuelve en Semantics — accesible para TalkBack', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(semanticLabel: 'Cargando'));
    await tester.pump();

    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
  });

  testWidgets('sin semanticLabel no hay nodo Semantics extra', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.bySemanticsLabel('Cargando'), findsNothing);
  });

  testWidgets(
    'con disableAnimations del SO el controller no repite — pumpAndSettle no cuelga',
    (tester) async {
      await tester.pumpWidget(buildApp(disableAnimations: true));
      // Si el controller hubiera arrancado el repeat, settle nunca
      // terminaría — que este test pase prueba el arco estático.
      await tester.pumpAndSettle();
      expect(loaderPaint(), findsOneWidget);
    },
  );
}
