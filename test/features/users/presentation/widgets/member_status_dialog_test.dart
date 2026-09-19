import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/widgets/member_status_dialog.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  // El diálogo corre dentro de un Navigator — el harness es un botón que
  // dispara `MemberStatusDialog.show(context, member)` y captura el
  // Future<bool> que resuelve el pop (true = confirmó, false = canceló).
  late Future<bool> result;

  const activeMember = OrgMember(
    id: '1',
    email: 'ana@mail.com',
    name: 'Ana Pérez',
    role: UserRole.admin,
    status: MemberStatus.active,
    organizationId: 'org',
  );

  const suspendedMember = OrgMember(
    id: '2',
    email: 'p@mail.com',
    name: 'Pedro Ruiz',
    role: UserRole.operator,
    status: MemberStatus.suspended,
    organizationId: 'org',
  );

  Widget buildApp(OrgMember member) => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => result = MemberStatusDialog.show(context, member),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('miembro activo: variante suspender (título, mensaje, CTA)', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(activeMember));
    await openDialog(tester);

    expect(find.text('¿Suspender a Ana Pérez?'), findsOneWidget);
    expect(
      find.text(
        'Perderá el acceso a esta organización hasta que lo reactives.',
      ),
      findsOneWidget,
    );
    expect(find.text('Suspender usuario'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('miembro suspendido: variante reactivar', (tester) async {
    await tester.pumpWidget(buildApp(suspendedMember));
    await openDialog(tester);

    expect(find.text('¿Reactivar a Pedro Ruiz?'), findsOneWidget);
    expect(
      find.text('Recuperará el acceso a esta organización.'),
      findsOneWidget,
    );
    expect(find.text('Reactivar usuario'), findsOneWidget);
  });

  testWidgets('el CTA confirma y el future resuelve true', (tester) async {
    await tester.pumpWidget(buildApp(activeMember));
    await openDialog(tester);

    await tester.tap(find.text('Suspender usuario'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect(find.text('¿Suspender a Ana Pérez?'), findsNothing);
  });

  testWidgets('Cancelar cierra y el future resuelve false', (tester) async {
    await tester.pumpWidget(buildApp(activeMember));
    await openDialog(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
  });
}
