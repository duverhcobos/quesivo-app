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
import 'package:quesivo/features/users/presentation/cubit/link_user_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/link_user_state.dart';
import 'package:quesivo/features/users/presentation/widgets/link_user_sheet.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockLinkUserCubit extends MockCubit<LinkUserState>
    implements LinkUserCubit {}

void main() {
  // El sheet corre dentro de un Navigator — el harness es un botón que
  // dispara `LinkUserSheet.show(context, cubit: mock)` (seam de tests)
  // y captura el Future<OrgMember?> que el sheet resuelve al hacer pop
  // (OrgMember del backend o null).
  late MockLinkUserCubit mockCubit;
  late StreamController<LinkUserState> stateController;
  late Future<OrgMember?> result;

  const tMember = OrgMember(
    id: 'uuid-backend-1',
    email: 'vieja@mail.com',
    name: 'Ana Vieja',
    role: UserRole.operator,
    status: MemberStatus.active,
    organizationId: 'org-1',
    linked: true,
  );

  setUpAll(() {
    registerFallbackValue(UserRole.operator);
  });

  setUp(() {
    mockCubit = MockLinkUserCubit();
    // Broadcast: el BlocConsumer se suscribe dos veces a bloc.stream
    // (listener + builder) — un controller normal crashea con
    // "Stream has already been listened to".
    stateController = StreamController<LinkUserState>.broadcast();
    // Stubs directos del stream/estado (un solo hop async — whenListen
    // agrega un broadcast intermedio que obligaría a más pumps).
    when(() => mockCubit.stream).thenAnswer((_) => stateController.stream);
    when(() => mockCubit.state).thenReturn(const LinkUserState());
    when(() => mockCubit.close()).thenAnswer((_) async {});
    when(
      () => mockCubit.submit(
        email: any(named: 'email'),
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
                result = LinkUserSheet.show(context, cubit: mockCubit),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  // El sheet no entra en el viewport default de 800x600 — superficie
  // alta para que el campo, los chips y las acciones queden visibles.
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
    await tester.enterText(field('Correo electrónico'), 'vieja@mail.com');
    await tester.tap(find.text('Operario'));
    await tester.pump();
  }

  testWidgets('renderiza título, hint, campo email, chips de rol y acciones', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    expect(find.text('Vincular usuario'), findsOneWidget);
    expect(
      find.text(
        'El correo ya tiene cuenta en Quesivo — se vincula a tu quesera y conserva su contraseña actual',
      ),
      findsOneWidget,
    );
    expect(find.byType(QuesivoTextField), findsOneWidget);
    expect(field('Correo electrónico'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Operario'), findsOneWidget);
    expect(find.text('Recolector'), findsOneWidget);
    expect(find.text('Productor'), findsOneWidget);
    expect(find.text('Vincular'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets(
    'submit vacío muestra los errores y el sheet sigue abierto (sin llamar al cubit)',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);

      await tester.tap(find.text('Vincular'));
      await tester.pump();

      expect(find.text('Ingresa un correo con formato válido'), findsOneWidget);
      expect(find.text('Elegí un rol'), findsOneWidget);
      // No hubo pop — el sheet sigue abierto.
      expect(find.text('Vincular usuario'), findsOneWidget);
      verifyNever(
        () => mockCubit.submit(
          email: any(named: 'email'),
          role: any(named: 'role'),
        ),
      );
    },
  );

  testWidgets('con email válido pero sin rol solo muestra "Elegí un rol"', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Correo electrónico'), 'vieja@mail.com');
    await tester.tap(find.text('Vincular'));
    await tester.pump();

    expect(find.text('Elegí un rol'), findsOneWidget);
    expect(find.text('Ingresa un correo con formato válido'), findsNothing);
    expect(find.text('Vincular'), findsOneWidget);
    verifyNever(
      () => mockCubit.submit(
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    );
  });

  testWidgets('submit válido llama al cubit con el email normalizado', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Correo electrónico'), 'Vieja@Mail.com ');
    await tester.tap(find.text('Operario'));
    await tester.pump();
    await tester.tap(find.text('Vincular'));
    await tester.pump();

    verify(
      () => mockCubit.submit(
        email: 'vieja@mail.com',
        role: UserRole.operator,
      ),
    ).called(1);
  });

  testWidgets(
    'estado inProgress muestra spinner y deshabilita campo y acciones',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);

      stateController.add(
        const LinkUserState(status: FormzSubmissionStatus.inProgress),
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
      // El campo queda bloqueado mientras el submit está en vuelo.
      expect(
        tester.widget<QuesivoTextField>(find.byType(QuesivoTextField)).enabled,
        isFalse,
      );
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

      await tester.tap(find.text('Vincular'));
      await tester.pump();

      // El backend respondió 201 — el cubit emite success con el
      // OrgMember real (uuid, linked:true). El sheet NO popea de
      // inmediato: hay una pausa de confirmación visible (~500ms).
      stateController.add(
        const LinkUserState(
          status: FormzSubmissionStatus.success,
          linkedMember: tMember,
        ),
      );
      // Doble pump: entrega del evento (microtask) + rebuild pintado.
      await tester.pump();
      await tester.pump();

      // Durante la pausa: sheet abierto (el título sigue — el label del
      // botón ya fue reemplazado por el check). El mensaje de éxito NO
      // va en el sheet — llega por QuesivoToast tras el pop.
      expect(find.text('Vincular usuario'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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
      expect(find.text('Vincular'), findsNothing);
    },
  );

  testWidgets(
    'estado failure muestra el error en un toast y el sheet sigue abierto',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);
      await fillValidForm(tester);

      await tester.tap(find.text('Vincular'));
      await tester.pump();

      // 404 USER_NOT_FOUND → toast rojo sobre el overlay raíz: el form
      // queda abierto para corregir el email o crear el usuario.
      stateController.add(
        const LinkUserState(
          status: FormzSubmissionStatus.failure,
          failure: UserNotFoundFailure(),
        ),
      );
      // Doble pump: entrega del evento (microtask) + rebuild pintado.
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Ese correo no tiene cuenta — crealo desde "Crear usuario"',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Vincular'), findsOneWidget);

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
    expect(find.text('Vincular usuario'), findsNothing);
  });

  testWidgets('el formatter del email bloquea espacios al tipear', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Correo electrónico'), 'a b@c');
    await tester.pump();

    expect(find.text('ab@c'), findsOneWidget);
  });

  testWidgets('email sin formato muestra el error en vivo, sin submit', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Correo electrónico'), 'juanmail.com');
    await tester.pump();

    // Sin tap en "Vincular" — el onChanged ya marca el error.
    expect(find.text('Ingresa un correo con formato válido'), findsOneWidget);
    verifyNever(
      () => mockCubit.submit(
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    );
  });

  testWidgets(
    'el PopScope bloquea el cierre por scrim-tap mientras el submit está en vuelo',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);
      await fillValidForm(tester);
      await tester.tap(find.text('Vincular'));
      await tester.pump();

      stateController.add(
        const LinkUserState(status: FormzSubmissionStatus.inProgress),
      );
      await tester.pump();
      await tester.pump();

      // Tap en la barrera (zona sobre el sheet) — con canPop:false el
      // modal no puede cerrarse: el miembro pudo vincularse sin que la
      // UI lo sepa si se cerrara antes del resultado.
      await tester.tapAt(const Offset(400, 100));
      await tester.pump();
      await tester.pump();

      expect(find.text('Vincular usuario'), findsOneWidget);
    },
  );
}
