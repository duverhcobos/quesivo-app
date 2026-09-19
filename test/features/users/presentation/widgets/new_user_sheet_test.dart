import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/widgets/quesivo_text_field.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/widgets/new_user_sheet.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  // El sheet corre dentro de un Navigator — el harness es un botón que
  // dispara `NewUserSheet.show(context)` y captura el Future<OrgMember?>
  // que el sheet resuelve al hacer pop (OrgMember creado o null).
  late Future<OrgMember?> result;

  Widget buildApp() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => result = NewUserSheet.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  // El sheet entero (~660px) no entra en el viewport default de 800x600
  // — superficie alta para que campos, chips y acciones queden visibles.
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

  testWidgets('renderiza campos, chips de rol y acciones', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    expect(find.text('Nuevo usuario'), findsOneWidget);
    expect(find.byType(QuesivoTextField), findsNWidgets(3));
    expect(field('Nombre completo'), findsOneWidget);
    expect(field('Correo electrónico'), findsOneWidget);
    expect(field('Contraseña temporal'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Operario'), findsOneWidget);
    expect(find.text('Recolector'), findsOneWidget);
    expect(find.text('Productor'), findsOneWidget);
    expect(find.text('Crear usuario'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('submit vacío muestra los errores y el sheet sigue abierto', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.tap(find.text('Crear usuario'));
    await tester.pump();

    expect(find.text('Ingresá el nombre completo'), findsOneWidget);
    expect(find.text('Ingresa un correo con formato válido'), findsOneWidget);
    expect(
      find.text(
        'Mínimo 8 caracteres, una mayúscula, una minúscula y un número',
      ),
      findsOneWidget,
    );
    expect(find.text('Elegí un rol'), findsOneWidget);
    // No hubo pop — el sheet sigue abierto.
    expect(find.text('Crear usuario'), findsOneWidget);
  });

  testWidgets('con campos válidos pero sin rol solo muestra "Elegí un rol"', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Nombre completo'), 'Juan Prueba');
    await tester.enterText(field('Correo electrónico'), 'juan@mail.com');
    await tester.enterText(field('Contraseña temporal'), 'Temporal1');
    await tester.tap(find.text('Crear usuario'));
    await tester.pump();

    expect(find.text('Elegí un rol'), findsOneWidget);
    expect(find.text('Ingresá el nombre completo'), findsNothing);
    expect(find.text('Ingresa un correo con formato válido'), findsNothing);
    expect(
      find.text(
        'Mínimo 8 caracteres, una mayúscula, una minúscula y un número',
      ),
      findsNothing,
    );
    expect(find.text('Crear usuario'), findsOneWidget);
  });

  testWidgets('submit válido hace pop con el OrgMember (email normalizado)', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Nombre completo'), 'Usuario Nuevo');
    await tester.enterText(field('Correo electrónico'), 'Nuevo@Mail.com ');
    await tester.enterText(field('Contraseña temporal'), 'Temporal1');
    await tester.tap(find.text('Operario'));
    await tester.pump();
    await tester.tap(find.text('Crear usuario'));
    await tester.pumpAndSettle();

    final member = await result;
    expect(member, isNotNull);
    expect(member!.name, 'Usuario Nuevo');
    expect(member.email, 'nuevo@mail.com');
    expect(member.role, UserRole.operator);
    expect(member.status, MemberStatus.active);
    // El sheet cerró.
    expect(find.text('Crear usuario'), findsNothing);
  });

  testWidgets('Cancelar cierra el sheet sin resultado', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(find.text('Nuevo usuario'), findsNothing);
  });
}
