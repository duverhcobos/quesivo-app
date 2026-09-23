import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/widgets/quesivo_loader.dart';
import 'package:quesivo/features/auth/domain/entities/organization_summary.dart';
import 'package:quesivo/features/queseras/presentation/widgets/quesera_card.dart';

void main() {
  const tOrg = OrganizationSummary(
    id: 'org-1',
    name: 'Quesera Norte',
    role: 'ADMIN',
  );

  Widget buildCard({
    bool loading = false,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: QueseraCard(
          organization: tOrg,
          loading: loading,
          enabled: enabled,
          enterLabel: 'Entrar',
          roleLabel: 'Administrador',
          tagline: 'Gestioná tu producción, inventario y más.',
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('muestra nombre, chip de rol, tagline y CTA circular con '
      'flecha', (tester) async {
    await tester.pumpWidget(buildCard());

    expect(find.text('Quesera Norte'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(
      find.text('Gestioná tu producción, inventario y más.'),
      findsOneWidget,
    );
    // El CTA es solo el círculo-flecha — el label "Entrar" va en
    // Semantics, no pinta texto (§61).
    expect(find.text('Entrar'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    // El chip de rol va limpio, sin ícono (§62).
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
  });

  testWidgets('tap habilitado dispara onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildCard(onTap: () => tapped = true));

    await tester.tap(find.byType(QueseraCard));

    expect(tapped, isTrue);
  });

  testWidgets('enabled=false bloquea el tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildCard(enabled: false, onTap: () => tapped = true),
    );

    await tester.tap(find.byType(QueseraCard));

    expect(tapped, isFalse);
  });

  testWidgets('loading muestra spinner en lugar del CTA circular', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      buildCard(loading: true, enabled: false, onTap: () => tapped = true),
    );

    expect(find.byType(QuesivoLoader), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);

    await tester.tap(find.byType(QueseraCard));
    expect(tapped, isFalse);
  });
}
