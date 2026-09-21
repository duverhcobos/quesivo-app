import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/di/setup_di.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/cubit/create_user_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/create_user_state.dart';
import 'package:quesivo/features/users/presentation/cubit/link_user_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/link_user_state.dart';
import 'package:quesivo/features/users/presentation/screens/users_screen.dart';
import 'package:quesivo/features/users/presentation/widgets/link_user_sheet.dart';
import 'package:quesivo/features/users/presentation/widgets/new_user_sheet.dart';
import 'package:quesivo/features/users/presentation/widgets/org_member_card.dart';
import 'package:quesivo/features/users/presentation/widgets/role_filter_chips.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockCreateUserCubit extends MockCubit<CreateUserState>
    implements CreateUserCubit {}

class MockLinkUserCubit extends MockCubit<LinkUserState>
    implements LinkUserCubit {}

void main() {
  // Los sheets resuelven su cubit por `locator` (la screen no pasa el
  // seam `cubit:`) — se registran mocks en setUp para controlar las
  // emisiones y evitar que los factories reales pidan dependencias de
  // red.
  late MockCreateUserCubit mockCubit;
  late StreamController<CreateUserState> stateController;
  late MockLinkUserCubit mockLinkCubit;
  late StreamController<LinkUserState> linkStateController;

  const tCreated = OrgMember(
    id: 'uuid-backend-1',
    email: 'nuevo@mail.com',
    name: 'Usuario Nuevo',
    role: UserRole.operator,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );

  const tLinked = OrgMember(
    id: 'uuid-backend-2',
    email: 'ana.vieja@mail.com',
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
    locator.registerFactory<CreateUserCubit>(() => mockCubit);

    mockLinkCubit = MockLinkUserCubit();
    linkStateController = StreamController<LinkUserState>.broadcast();
    when(
      () => mockLinkCubit.stream,
    ).thenAnswer((_) => linkStateController.stream);
    when(() => mockLinkCubit.state).thenReturn(const LinkUserState());
    when(() => mockLinkCubit.close()).thenAnswer((_) async {});
    when(
      () => mockLinkCubit.submit(
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async {});
    locator.registerFactory<LinkUserCubit>(() => mockLinkCubit);
  });

  tearDown(() {
    // Sin awaits: testWidgets corre en FakeAsync — el `done` del close
    // queda encolado sin flush y un await acá colgaría el test. El
    // isolate del test se descarta con el Future pendiente.
    stateController.close();
    linkStateController.close();
    locator.reset();
  });

  Widget buildApp() => const MaterialApp(
    locale: Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: UsersScreen(),
  );

  // El viewport por defecto de flutter_test (800x600) solo alcanza para
  // renderizar ~3 cards del ListView.separated (lazy build). Se agranda
  // el alto del surface para que las 15 cards de la página inicial
  // entren en pantalla y `findsNWidgets` las cuente todas.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// §48 — el FAB ahora es un speed dial: tap → las dos acciones suben
  /// sobre el scrim → "Crear usuario" abre el NewUserSheet.
  Future<void> openAndFillSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear usuario'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Usuario Nuevo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'nuevo@mail.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña temporal'),
      'Temporal1',
    );
    // "Operario" también aparece en RoleFilterChips y en los
    // MemberRoleChip de las cards — se acota al árbol del sheet.
    await tester.tap(
      find.descendant(
        of: find.byType(NewUserSheet),
        matching: find.text('Operario'),
      ),
    );
    await tester.pump();
  }

  testWidgets('muestra título, tooltip de acción y stats sobre el total (54)', (
    tester,
  ) async {
    // §41: sin back arrow ni context.pop() — la pantalla ya no necesita
    // un GoRouter vivo; MaterialApp plano alcanza.
    await tester.pumpWidget(buildApp());

    expect(find.text('Usuarios'), findsOneWidget);
    // Acción icon-only: círculo amarillo con person_add (§41) — el label
    // vive en el tooltip, no como texto visible.
    expect(find.byTooltip('Nuevo usuario'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    // §43: dataset sintético de 54 miembros — stats siempre sobre el
    // total, no sobre lo visible/filtrado.
    expect(find.text('54 miembros'), findsOneWidget);
    expect(find.text('46 activos'), findsOneWidget);
  });

  testWidgets('la carga inicial muestra 15 cards, no las 54 del dataset', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    expect(find.byType(OrgMemberCard), findsNWidgets(15));
  });

  testWidgets('escribir en el buscador filtra por nombre/correo', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField), 'ana.perez');
    await tester.pump();

    expect(find.byType(OrgMemberCard), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
  });

  testWidgets('búsqueda sin coincidencias muestra el estado "Sin resultados"', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField), 'zzzzz-no-existe');
    await tester.pump();

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.byType(OrgMemberCard), findsNothing);
  });

  testWidgets('tocar un chip de rol filtra el listado por ese rol', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    expect(find.byType(OrgMemberCard), findsNWidgets(15));

    // "Productor" también aparece en el MemberRoleChip de cada card —
    // se acota la búsqueda al chip de filtro (dentro de RoleFilterChips).
    // El chip está al final de la fila horizontal scrolleable: hay que
    // asegurarlo visible antes de tocarlo.
    final producerFilterChip = find.descendant(
      of: find.byType(RoleFilterChips),
      matching: find.text('Productor'),
    );
    await tester.ensureVisible(producerFilterChip);
    await tester.pumpAndSettle();
    await tester.tap(producerFilterChip);
    await tester.pump();

    // 54 miembros / 4 roles asignados round-robin (índice % 4 == 3):
    // 13 miembros son Productor, menos que la página inicial de 15 —
    // la cuenta visible baja.
    expect(find.byType(OrgMemberCard), findsNWidgets(13));
  });

  testWidgets(
    'el FAB expande el speed dial con las dos acciones y el scrim las cierra',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());

      // §48 — tap en el FAB: suben las dos acciones y el ícono morfa
      // person_add → close.
      await tester.tap(find.byIcon(Icons.person_add_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Crear usuario'), findsOneWidget);
      expect(find.text('Vincular existente'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap afuera (scrim transparente) cierra el dial sin disparar
      // nada debajo.
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      expect(find.text('Crear usuario'), findsNothing);
      expect(find.text('Vincular existente'), findsNothing);
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    },
  );

  testWidgets('la acción "Crear usuario" abre el sheet de creación', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear usuario'));
    await tester.pumpAndSettle();

    // El sheet de creación abierto — su título es "Nuevo usuario" y el
    // submit repite el label de la acción.
    expect(find.text('Nuevo usuario'), findsOneWidget);
    expect(find.byType(NewUserSheet), findsOneWidget);
  });

  testWidgets('crear desde el sheet agrega el miembro al tope del listado', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openAndFillSheet(tester);

    await tester.tap(find.text('Crear usuario'));
    await tester.pump();

    // El submit salió al cubit con los valores del form.
    verify(
      () => mockCubit.submit(
        name: 'Usuario Nuevo',
        email: 'nuevo@mail.com',
        password: 'Temporal1',
        role: UserRole.operator,
      ),
    ).called(1);

    // El backend respondió 201 — el sheet muestra la confirmación
    // ~500ms y luego popea el OrgMember real.
    stateController.add(
      const CreateUserState(
        status: FormzSubmissionStatus.success,
        createdMember: tCreated,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Sheet cerrado + toast verde de confirmación arriba (§46 —
    // reemplaza al SnackBar: pill flotante, auto-dismiss ~2.6s).
    expect(find.text('Crear usuario'), findsNothing);
    expect(find.text('Usuario creado con éxito'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // El insert al tope sube el total y la primera card es la del nuevo.
    expect(find.text('55 miembros'), findsOneWidget);
    expect(
      tester
          .widget<OrgMemberCard>(find.byType(OrgMemberCard).first)
          .member
          .name,
      'Usuario Nuevo',
    );

    // Drena el auto-dismiss del toast (~2.6s) — sin el pump el Timer
    // queda pendiente al teardown ("A Timer is still pending").
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'la acción "Vincular existente" abre el LinkUserSheet y su resultado inserta el miembro + toast info',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());

      // Speed dial → acción de vinculación.
      await tester.tap(find.byIcon(Icons.person_add_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vincular existente'));
      await tester.pumpAndSettle();

      // El sheet de vinculación abierto — solo email + rol (§48).
      expect(find.text('Vincular usuario'), findsOneWidget);
      expect(find.byType(LinkUserSheet), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'ana.vieja@mail.com',
      );
      // "Operario" también aparece en RoleFilterChips y en los
      // MemberRoleChip de las cards — se acota al árbol del sheet.
      await tester.tap(
        find.descendant(
          of: find.byType(LinkUserSheet),
          matching: find.text('Operario'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Vincular'));
      await tester.pump();

      // El submit salió al cubit con los valores del form.
      verify(
        () => mockLinkCubit.submit(
          email: 'ana.vieja@mail.com',
          role: UserRole.operator,
        ),
      ).called(1);

      // 201 con linked:true — solo se creó la membresía, el usuario
      // conserva su contraseña actual (no hay temporal que compartir).
      linkStateController.add(
        const LinkUserState(
          status: FormzSubmissionStatus.success,
          linkedMember: tLinked,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Sheet cerrado + toast info azul de vinculación arriba — la
      // semántica es informativa: no se creó cuenta, solo membresía.
      expect(find.text('Vincular usuario'), findsNothing);
      expect(
        find.text(
          'Ana Vieja ya tenía cuenta — quedó vinculado y entra con su contraseña actual',
        ),
        findsOneWidget,
      );
      expect(find.text('Usuario creado con éxito'), findsNothing);
      // El insert al tope sube el total y la primera card es la del
      // vinculado.
      expect(find.text('55 miembros'), findsOneWidget);
      expect(
        tester
            .widget<OrgMemberCard>(find.byType(OrgMemberCard).first)
            .member
            .linked,
        isTrue,
      );

      // Drena el auto-dismiss del toast (~2.6s).
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('suspender desde el menú cambia el chip de la card', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    // La primera card del dataset (Ana Pérez, índice 0) ya viene
    // suspendida — se usa la segunda (Ana Gómez, activa), la primera
    // cuyo ⋮ ofrece "Suspender usuario".
    final card = find.byType(OrgMemberCard).at(1);
    final menuButton = find.descendant(
      of: card,
      matching: find.byIcon(Icons.more_vert),
    );
    await tester.ensureVisible(menuButton);
    await tester.pumpAndSettle();
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Ítem del menú → abre la confirmación (AlertDialog §45).
    await tester.tap(find.text('Suspender usuario'));
    await tester.pumpAndSettle();
    expect(find.text('¿Suspender a Ana Gómez?'), findsOneWidget);

    // CTA del diálogo → confirma, flippea el status en el dataset local.
    await tester.tap(find.text('Suspender usuario'));
    await tester.pumpAndSettle();

    expect(find.text('Membresía suspendida'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Suspendido')),
      findsOneWidget,
    );
    expect(
      tester.widget<OrgMemberCard>(card).member.status,
      MemberStatus.suspended,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
