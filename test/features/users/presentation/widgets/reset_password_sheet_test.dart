import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/widgets/reset_password_sheet.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  // Mismo harness que new_user_sheet_test: un botón que dispara
  // `ResetPasswordSheet.show(context, member)` y captura el
  // Future<String?> que el sheet resuelve al hacer pop (password o
  // null al cancelar).
  late Future<String?> result;

  const member = OrgMember(
    id: '1',
    email: 'ana@mail.com',
    name: 'Ana Pérez',
    role: UserRole.admin,
    status: MemberStatus.active,
    organizationId: 'org',
  );

  Widget buildApp() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => result = ResetPasswordSheet.show(context, member),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  // Superficie alta para que el sheet completo quede visible (mismo
  // criterio que new_user_sheet_test).
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  testWidgets('renderiza título, hint con el nombre y el campo', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    expect(find.text('Restablecer contraseña'), findsOneWidget);
    expect(
      find.text(
        'Nueva contraseña temporal para Ana Pérez — ingresará con ella.',
      ),
      findsOneWidget,
    );
    expect(field('Nueva contraseña'), findsOneWidget);
    expect(find.text('Actualizar contraseña'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('submit con password débil muestra el error y no hace pop', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Nueva contraseña'), 'debil');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pump();

    expect(
      find.text(
        'Mínimo 8 caracteres, una mayúscula, una minúscula y un número',
      ),
      findsOneWidget,
    );
    // No hubo pop — el sheet sigue abierto.
    expect(find.text('Actualizar contraseña'), findsOneWidget);
  });

  testWidgets('submit válido hace pop con el password exacto', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Nueva contraseña'), 'Temporal1');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pumpAndSettle();

    expect(await result, 'Temporal1');
    // El sheet cerró.
    expect(find.text('Actualizar contraseña'), findsNothing);
  });

  testWidgets('Cancelar cierra el sheet sin resultado', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
  });
}
