import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/widgets/quesivo_primary_button.dart';
import 'package:quesivo/core/widgets/quesivo_text_field.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/presentation/cubit/create_user_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/create_user_state.dart';
import 'package:quesivo/features/users/presentation/widgets/new_user_sheet.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockCreateUserCubit extends MockCubit<CreateUserState>
    implements CreateUserCubit {}

void main() {
  // El sheet corre dentro de un Navigator — el harness es un botón que
  // dispara `NewUserSheet.show(context, cubit: mock)` (seam de tests)
  // y captura el Future<OrgMember?> que el sheet resuelve al hacer pop
  // (OrgMember del backend o null).
  late MockCreateUserCubit mockCubit;
  late StreamController<CreateUserState> stateController;
  late Future<OrgMember?> result;

  const tMember = OrgMember(
    id: 'uuid-backend-1',
    email: 'nuevo@mail.com',
    name: 'Usuario Nuevo',
    role: UserRole.operator,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );

  setUpAll(() {
    registerFallbackValue(UserRole.operator);
  });

  setUp(() {
    mockCubit = MockCreateUserCubit();
    // Broadcast: el BlocConsumer se suscribe dos veces a bloc.stream
    // (listener + builder) — un controller normal crashea con
    // "Stream has already been listened to".
    stateController = StreamController<CreateUserState>.broadcast();
    // Stubs directos del stream/estado (un solo hop async — whenListen
    // agrega un broadcast intermedio que obligaría a más pumps).
    when(() => mockCubit.stream).thenAnswer((_) => stateController.stream);
    when(() => mockCubit.state).thenReturn(const CreateUserState());
    when(() => mockCubit.close()).thenAnswer((_) async {});
    when(
      () => mockCubit.submit(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    stateController.close();
  });

  Widget buildApp() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                result = NewUserSheet.show(context, cubit: mockCubit),
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

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(field('Nombre completo'), 'Usuario Nuevo');
    await tester.enterText(field('Correo electrónico'), 'nuevo@mail.com');
    await tester.enterText(field('Contraseña temporal'), 'Temporal1');
    await tester.tap(find.text('Operario'));
    await tester.pump();
  }

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

  testWidgets(
    'submit vacío muestra los errores y el sheet sigue abierto (sin llamar al cubit)',
    (tester) async {
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
      verifyNever(
        () => mockCubit.submit(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          role: any(named: 'role'),
        ),
      );
    },
  );

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
    verifyNever(
      () => mockCubit.submit(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        role: any(named: 'role'),
      ),
    );
  });

  testWidgets('submit válido llama al cubit con los valores normalizados', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Nombre completo'), '  Usuario Nuevo ');
    await tester.enterText(field('Correo electrónico'), 'Nuevo@Mail.com ');
    await tester.enterText(field('Contraseña temporal'), 'Temporal1');
    await tester.tap(find.text('Operario'));
    await tester.pump();
    await tester.tap(find.text('Crear usuario'));
    await tester.pump();

    verify(
      () => mockCubit.submit(
        name: 'Usuario Nuevo',
        email: 'nuevo@mail.com',
        password: 'Temporal1',
        role: UserRole.operator,
      ),
    ).called(1);
  });

  testWidgets(
    'estado inProgress muestra spinner y deshabilita campos y acciones',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);

      stateController.add(
        const CreateUserState(status: FormzSubmissionStatus.inProgress),
      );
      // El evento viaja por microtask: un pump lo entrega al consumer
      // (marca dirty) y el segundo pinta el rebuild. No pumpAndSettle —
      // el spinner es una animación infinita y nunca settlea.
      await tester.pump();
      await tester.pump();

      // El primario muestra spinner navy en vez del label.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<QuesivoPrimaryButton>(find.byType(QuesivoPrimaryButton))
            .isLoading,
        isTrue,
      );
      // Los 3 campos quedan bloqueados mientras el submit está en vuelo.
      for (final f in tester.widgetList<QuesivoTextField>(
        find.byType(QuesivoTextField),
      )) {
        expect(f.enabled, isFalse);
      }
      // El ghost Cancelar se deshabilita — el submit en vuelo manda.
      final cancelButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Cancelar'),
      );
      expect(cancelButton.onPressed, isNull);
    },
  );

  testWidgets(
    'estado success muestra check ~500ms y luego popea el miembro real',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);
      await fillValidForm(tester);

      await tester.tap(find.text('Crear usuario'));
      await tester.pump();

      // El backend respondió 201 — el cubit emite success con el
      // OrgMember real (uuid, linked). El sheet NO popea de inmediato:
      // hay una pausa de confirmación visible (~500ms) antes del pop.
      stateController.add(
        const CreateUserState(
          status: FormzSubmissionStatus.success,
          createdMember: tMember,
        ),
      );
      // Doble pump: entrega del evento (microtask) + rebuild pintado.
      await tester.pump();
      await tester.pump();

      // Durante la pausa: sheet abierto (el título sigue — el label del
      // botón ya fue reemplazado por el check). El mensaje de éxito NO
      // va en el sheet — solo el check del botón confirma dentro del
      // modal; el texto llega por QuesivoToast tras el pop.
      expect(find.text('Nuevo usuario'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Usuario creado con éxito'), findsNothing);
      expect(
        tester
            .widget<QuesivoPrimaryButton>(find.byType(QuesivoPrimaryButton))
            .isSuccess,
        isTrue,
      );

      // Vencida la pausa, el sheet devuelve el miembro y cierra.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(await result, tMember);
      expect(find.text('Crear usuario'), findsNothing);
    },
  );

  testWidgets(
    'estado failure muestra el error en un toast y el sheet sigue abierto',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);
      await fillValidForm(tester);

      await tester.tap(find.text('Crear usuario'));
      await tester.pump();

      // 409 MEMBERSHIP_ALREADY_EXISTS → toast rojo sobre el overlay
      // raíz (ya no es texto inline sobre los botones): el form queda
      // abierto para corregir el email.
      stateController.add(
        const CreateUserState(
          status: FormzSubmissionStatus.failure,
          failure: MembershipAlreadyExistsFailure(),
        ),
      );
      // Doble pump: entrega del evento (microtask) + rebuild pintado.
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Ese correo ya pertenece a esta organización'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Crear usuario'), findsOneWidget);

      // Drena el auto-dismiss del toast (~2.6s) — sin el pump el Timer
      // queda pendiente al teardown ("A Timer is still pending").
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

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
