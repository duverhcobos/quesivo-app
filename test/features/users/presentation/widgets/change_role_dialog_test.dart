import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/theme/app_colors.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/widgets/change_role_dialog.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  // El diálogo corre dentro de un Navigator — el harness es un botón que
  // dispara `ChangeRoleDialog.show(context, member)` y captura el
  // Future<UserRole?> que resuelve el pop (rol nuevo = confirmó,
  // null = canceló o no cambió).
  late Future<UserRole?> result;

  const member = OrgMember(
    id: '1',
    email: 'ana@mail.com',
    name: 'Ana Pérez',
    role: UserRole.operator,
    status: MemberStatus.active,
    organizationId: 'org',
  );

  Widget buildApp(OrgMember m) => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => result = ChangeRoleDialog.show(context, m),
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

  /// El chip seleccionado pinta fondo navy — se busca el Material
  /// ancestro del label con ese color para afirmar la preselección.
  bool isChipSelected(WidgetTester tester, String label) {
    final materials = tester.widgetList<Material>(
      find.ancestor(of: find.text(label), matching: find.byType(Material)),
    );
    return materials.any((m) => m.color == AppColors.quesivoNavy);
  }

  ElevatedButton confirmButton(WidgetTester tester) => tester
      .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Cambiar'));

  testWidgets('título, aviso de sesión y chips con el rol actual marcado', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(member));
    await openDialog(tester);

    expect(find.text('Cambiar rol de Ana Pérez'), findsOneWidget);
    // El aviso explica la semántica del backend: el cambio revoca la
    // sesión del miembro — aplica al reingresar.
    expect(
      find.text(
        'El nuevo rol aplica cuando vuelva a ingresar — su sesión en esta quesera se cerrará.',
      ),
      findsOneWidget,
    );
    expect(isChipSelected(tester, 'Operario'), isTrue);
    expect(isChipSelected(tester, 'Administrador'), isFalse);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('confirmar deshabilitado mientras el rol no cambie (no-op)', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(member));
    await openDialog(tester);

    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets(
    'elegir otro rol habilita el CTA y el future resuelve el rol nuevo',
    (tester) async {
      await tester.pumpWidget(buildApp(member));
      await openDialog(tester);

      await tester.tap(find.text('Recolector'));
      await tester.pumpAndSettle();

      expect(confirmButton(tester).onPressed, isNotNull);
      expect(isChipSelected(tester, 'Recolector'), isTrue);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cambiar'));
      await tester.pumpAndSettle();

      expect(await result, UserRole.collector);
      expect(find.text('Cambiar rol de Ana Pérez'), findsNothing);
    },
  );

  testWidgets('volver al rol actual deshabilita el CTA de nuevo', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(member));
    await openDialog(tester);

    await tester.tap(find.text('Administrador'));
    await tester.pumpAndSettle();
    expect(confirmButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Operario'));
    await tester.pumpAndSettle();
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('Cancelar cierra y el future resuelve null', (tester) async {
    await tester.pumpWidget(buildApp(member));
    await openDialog(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
  });
}
