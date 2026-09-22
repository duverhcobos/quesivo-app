import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/di/setup_di.dart';
import 'package:quesivo/core/widgets/quesivo_loader.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/presentation/cubit/create_user_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/create_user_state.dart';
import 'package:quesivo/features/users/presentation/cubit/link_user_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/link_user_state.dart';
import 'package:quesivo/features/users/presentation/cubit/users_list_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/users_list_state.dart';
import 'package:quesivo/features/users/presentation/screens/users_screen.dart';
import 'package:quesivo/features/users/presentation/widgets/link_user_sheet.dart';
import 'package:quesivo/features/users/presentation/widgets/new_user_sheet.dart';
import 'package:quesivo/features/users/presentation/widgets/org_member_card.dart';
import 'package:quesivo/features/users/presentation/widgets/role_filter_chips.dart';
import 'package:quesivo/features/users/presentation/widgets/users_list_error_state.dart';
import 'package:quesivo/features/users/presentation/widgets/users_list_footer_loader.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockCreateUserCubit extends MockCubit<CreateUserState>
    implements CreateUserCubit {}

class MockLinkUserCubit extends MockCubit<LinkUserState>
    implements LinkUserCubit {}

class MockUsersListCubit extends MockCubit<UsersListState>
    implements UsersListCubit {}

// §52 — `UsersListBody` lee `AuthCubit` (context.select) para ocultar el
// ⋮ en la card propia (isSelf) — sin proveerlo el árbol de test explota
// con ProviderNotFoundException.
class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  // La screen resuelve UsersListCubit por `locator` (BlocProvider del
  // shell) y los sheets los suyos — se registran mocks en setUp para
  // controlar las emisiones y evitar que los factories reales pidan
  // dependencias de red.
  late MockUsersListCubit mockListCubit;
  late StreamController<UsersListState> listStateController;
  late UsersListState currentListState;
  late MockCreateUserCubit mockCubit;
  late StreamController<CreateUserState> stateController;
  late MockLinkUserCubit mockLinkCubit;
  late StreamController<LinkUserState> linkStateController;
  // Usuario logueado ficticio para el `AuthCubit` mockeado — ningún
  // fixture de card usa este id, así que `isSelf` es false salvo que un
  // test lo pise a propósito.
  late MockAuthCubit mockAuthCubit;
  const tCurrentUser = User(
    id: 'current-admin',
    email: 'admin@mail.com',
    name: 'Admin',
  );

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

  /// Página cargada fake — `total` mayor que los items para probar que
  /// el stat de miembros sale del `meta.total`, no de lo cargado.
  List<OrgMember> tMembers(int count) => [
    for (var i = 0; i < count; i++)
      OrgMember(
        id: 'u$i',
        email: 'user$i@mail.com',
        name: 'User $i',
        role: UserRole.operator,
        status: i == 0 ? MemberStatus.suspended : MemberStatus.active,
        organizationId: 'org-1',
      ),
  ];

  UsersListState loadedState({
    List<OrgMember>? members,
    int total = 34,
    int page = 1,
    // Default false: con hasMore=true el footer loader (un
    // QuesivoLoader) anima para siempre y pumpAndSettle no
    // termina — solo lo activan los tests que lo ejercitan.
    bool hasMore = false,
    String query = '',
    UserRole? roleFilter,
  }) => UsersListState(
    status: UsersListStatus.loaded,
    members: members ?? tMembers(15),
    total: total,
    page: page,
    hasMore: hasMore,
    query: query,
    roleFilter: roleFilter,
  );

  /// Emite un estado del cubit mockeado: actualiza el getter `state` y
  /// avisa por el stream para que el BlocBuilder repinte.
  void emitListState(UsersListState next) {
    currentListState = next;
    listStateController.add(next);
  }

  setUpAll(() {
    registerFallbackValue(UserRole.operator);
    registerFallbackValue(MemberStatus.active);
    registerFallbackValue(
      const OrgMember(
        id: 'fb',
        email: 'fb@mail.com',
        name: 'FB',
        role: UserRole.operator,
        status: MemberStatus.active,
        organizationId: 'org-1',
      ),
    );
  });

  setUp(() {
    // ── UsersListCubit (§49) — el cubit del listado real ──
    mockListCubit = MockUsersListCubit();
    // Broadcast: el BlocBuilder se suscribe a bloc.stream — un
    // controller normal crashea con "Stream has already been listened
    // to" si otro builder/listener también escucha.
    listStateController = StreamController<UsersListState>.broadcast();
    currentListState = const UsersListState(status: UsersListStatus.loading);
    when(
      () => mockListCubit.stream,
    ).thenAnswer((_) => listStateController.stream);
    when(() => mockListCubit.state).thenAnswer((_) => currentListState);
    when(() => mockListCubit.close()).thenAnswer((_) async {});
    when(() => mockListCubit.load()).thenAnswer((_) async {});
    when(() => mockListCubit.loadMore()).thenAnswer((_) async {});
    when(() => mockListCubit.refresh()).thenAnswer((_) async {});
    when(() => mockListCubit.setQuery(any())).thenReturn(null);
    when(() => mockListCubit.setRole(any())).thenReturn(null);
    when(() => mockListCubit.prependMember(any())).thenReturn(null);
    when(() => mockListCubit.updateMember(any())).thenReturn(null);
    // §52 — default: éxito, mergea el status pedido sobre el member
    // recibido (mismo comportamiento del cubit real con el 200 del
    // PATCH). Los tests de la regla de negocio lo pisan con su propio
    // stub cuando necesitan un failure.
    when(() => mockListCubit.setMemberStatus(any(), any())).thenAnswer((
      invocation,
    ) async {
      final member = invocation.positionalArguments[0] as OrgMember;
      final status = invocation.positionalArguments[1] as MemberStatus;
      return Right(member.copyWith(status: status));
    });
    // §54 — mismo default que setMemberStatus: éxito con el rol pedido
    // mergeado sobre el member (comportamiento del cubit real con el 200).
    when(() => mockListCubit.setMemberRole(any(), any())).thenAnswer((
      invocation,
    ) async {
      final member = invocation.positionalArguments[0] as OrgMember;
      final role = invocation.positionalArguments[1] as UserRole;
      return Right(member.copyWith(role: role));
    });
    locator.registerFactory<UsersListCubit>(() => mockListCubit);

    // ── AuthCubit — solo lo lee `UsersListBody` para `isSelf` (§52) ──
    mockAuthCubit = MockAuthCubit();
    when(() => mockAuthCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockAuthCubit.state).thenReturn(const AuthSuccess(tCurrentUser));
    when(() => mockAuthCubit.close()).thenAnswer((_) async {});

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
    listStateController.close();
    stateController.close();
    linkStateController.close();
    locator.reset();
  });

  // `UsersListBody` (§52) lee `AuthCubit` vía context.select — se provee
  // por fuera del MaterialApp, mismo lugar que en producción (main.dart).
  Widget buildApp() => BlocProvider<AuthCubit>.value(
    value: mockAuthCubit,
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UsersScreen(),
    ),
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

  /// El ListView del listado — el módulo tiene OTRO ListView horizontal
  /// en RoleFilterChips, así que se acota por el RefreshIndicator que
  /// envuelve solo al de miembros.
  Finder memberListView() => find.descendant(
    of: find.byType(RefreshIndicator),
    matching: find.byType(ListView),
  );

  /// §48 — el FAB ahora es un speed dial: tap → las dos acciones suben
  /// sobre el scrim → "Crear usuario" abre el NewUserSheet.
  Future<void> openAndFillSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('users-speed-dial-create')));
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

  testWidgets('al entrar dispara load() y con loading muestra el spinner', (
    tester,
  ) async {
    // currentListState ya arranca en loading (setUp) — la pantalla pide
    // la página 1 vía cubit y muestra el spinner de marca centrado.
    await tester.pumpWidget(buildApp());

    verify(() => mockListCubit.load()).called(1);
    expect(find.byType(QuesivoLoader), findsOneWidget);
    expect(find.byType(OrgMemberCard), findsNothing);
  });

  testWidgets(
    'loaded renderiza las cards del state y los stats salen de meta.total',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState(hasMore: true);
      await tester.pumpWidget(buildApp());

      // 15 filas cargadas pero meta.total=34 — "N miembros" usa el
      // total filtrado del backend, no members.length (§49).
      expect(find.byType(OrgMemberCard), findsNWidgets(15));
      expect(find.text('34 miembros'), findsOneWidget);
      // hasMore=true → el footer de página siguiente está al final.
      expect(find.byType(UsersListFooterLoader), findsOneWidget);
    },
  );

  testWidgets(
    'loaded sin hasMore no muestra el footer loader (última página)',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState(total: 15, hasMore: false);
      await tester.pumpWidget(buildApp());

      expect(find.byType(OrgMemberCard), findsNWidgets(15));
      expect(find.byType(UsersListFooterLoader), findsNothing);
    },
  );

  testWidgets('error muestra el mensaje y "Reintentar" relanza load()', (
    tester,
  ) async {
    currentListState = const UsersListState(
      status: UsersListStatus.error,
      failure: UsersNetworkFailure(),
    );
    await tester.pumpWidget(buildApp());

    expect(
      find.text('No se pudo cargar el listado — revisá tu conexión'),
      findsOneWidget,
    );
    expect(find.byType(OrgMemberCard), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    // init + retry.
    verify(() => mockListCubit.load()).called(2);
  });

  testWidgets(
    'loading con miembros atenúa la lista (Opacity 0.45) y pone el loader encima',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());

      // §51 — refetch en vuelo con la página 1 ya cargada (búsqueda/
      // filtro): las cards siguen renderizadas pero atenuadas y sin
      // gestos bajo el loader de marca centrado.
      emitListState(loadedState().copyWith(status: UsersListStatus.loading));
      await tester.pump();
      await tester.pump();

      expect(find.byType(OrgMemberCard), findsNWidgets(15));

      final dimmer = find.ancestor(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Opacity),
      );
      expect(dimmer, findsOneWidget);
      expect(tester.widget<Opacity>(dimmer).opacity, 0.45);

      // La lista no recibe gestos mientras vuela el refetch — el
      // IgnorePointer es el padre directo del Opacity (hay otros
      // IgnorePointer internos del Navigator más arriba en el árbol).
      final blocker = find.ancestor(
        of: dimmer,
        matching: find.byType(IgnorePointer),
      );
      expect(tester.widget<IgnorePointer>(blocker.first).ignoring, isTrue);

      // Loader de marca encima (28px — no el 40 de la primera carga).
      final loader = find.byType(QuesivoLoader);
      expect(loader, findsOneWidget);
      expect(tester.widget<QuesivoLoader>(loader).size, 28);
    },
  );

  testWidgets(
    'error con miembros conserva la lista y dispara el toast de error',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());

      // §51 — el refetch de página 1 falló con la lista previa cargada:
      // la pantalla de error se reserva para cuando no hay NADA que
      // mostrar — las cards quedan y el feedback sale por toast.
      emitListState(
        loadedState().copyWith(
          status: UsersListStatus.error,
          failure: const UsersNetworkFailure(),
          // El listener dispara por cambio de nonce (§51 review), no por
          // transición de status — el emit debe llevar el nonce del cubit.
          errorNonce: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(OrgMemberCard), findsNWidgets(15));
      expect(find.byType(UsersListErrorState), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      // Toast de error en el overlay raíz (auto-dismiss ~2.6s).
      expect(
        find.text('No se pudo cargar el listado — revisá tu conexión'),
        findsOneWidget,
      );

      // Drena el auto-dismiss del toast (~2.6s) — sin el pump el Timer
      // queda pendiente al teardown ("A Timer is still pending").
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'error 429 con miembros dispara toast de rate-limit, no el genérico',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());

      // UsersRateLimitFailure mapea a tooManyAttemptsError — el genérico
      // "revisá tu conexión" mentiría sobre la causa (backend 060).
      emitListState(
        loadedState().copyWith(
          status: UsersListStatus.error,
          failure: const UsersRateLimitFailure(),
          errorNonce: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Demasiados intentos — esperá un momento'),
        findsOneWidget,
      );
      expect(
        find.text('No se pudo cargar el listado — revisá tu conexión'),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'error 429 sin miembros muestra el estado con el mensaje de rate-limit',
    (tester) async {
      currentListState = const UsersListState(
        status: UsersListStatus.error,
        failure: UsersRateLimitFailure(),
        errorNonce: 1,
      );
      await tester.pumpWidget(buildApp());

      expect(find.byType(UsersListErrorState), findsOneWidget);
      expect(
        find.text('Demasiados intentos — esperá un momento'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('loaded vacío sin filtros muestra el empty state de la org', (
    tester,
  ) async {
    currentListState = loadedState(members: const [], total: 0);
    await tester.pumpWidget(buildApp());

    expect(find.text('Todavía no hay usuarios'), findsOneWidget);
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
  });

  testWidgets('loaded vacío con query/rol activo muestra "Sin resultados"', (
    tester,
  ) async {
    currentListState = loadedState(
      members: const [],
      total: 0,
      query: 'zz-no-existe',
    );
    await tester.pumpWidget(buildApp());

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
  });

  testWidgets('scrollear al fondo del listado dispara loadMore()', (
    tester,
  ) async {
    // Viewport default (800x600): 15 cards no entran → la lista scrollea
    // y al acercarse al borde inferior la screen pide la página 2.
    var loadMoreCalls = 0;
    when(
      () => mockListCubit.loadMore(),
    ).thenAnswer((_) async => loadMoreCalls++);
    currentListState = loadedState(hasMore: true);
    await tester.pumpWidget(buildApp());

    await tester.fling(memberListView(), const Offset(0, -3000), 8000);
    await tester.pump();

    expect(loadMoreCalls, greaterThan(0));
  });

  testWidgets(
    'escribir en el buscador dispara setQuery solo tras el debounce de 350ms',
    (tester) async {
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());

      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pump();

      // Todavía no pasaron los 350ms — el cubit no fue llamado.
      verifyNever(() => mockListCubit.setQuery(any()));

      await tester.pump(const Duration(milliseconds: 400));
      verify(() => mockListCubit.setQuery('ana')).called(1);
    },
  );

  testWidgets('tocar un chip de rol dispara setRole con ese rol', (
    tester,
  ) async {
    useTallSurface(tester);
    currentListState = loadedState();
    await tester.pumpWidget(buildApp());

    // "Productor" también aparece en el MemberRoleChip de cada card —
    // se acota la búsqueda al chip de filtro (dentro de RoleFilterChips).
    final producerFilterChip = find.descendant(
      of: find.byType(RoleFilterChips),
      matching: find.text('Productor'),
    );
    await tester.ensureVisible(producerFilterChip);
    await tester.pumpAndSettle();
    await tester.tap(producerFilterChip);
    await tester.pump();

    verify(() => mockListCubit.setRole(UserRole.producer)).called(1);
  });

  testWidgets('la card del dueño muestra el badge "Dueño" y oculta el ⋮', (
    tester,
  ) async {
    currentListState = loadedState(
      members: [
        const OrgMember(
          id: 'owner-1',
          email: 'dueno@mail.com',
          name: 'Dueño Queso',
          role: UserRole.admin,
          status: MemberStatus.active,
          organizationId: 'org-1',
          isOwner: true,
        ),
        ...tMembers(2),
      ],
      total: 3,
      hasMore: false,
    );
    await tester.pumpWidget(buildApp());

    // Badge junto al status chip — solo en la card del owner.
    expect(find.text('Dueño'), findsOneWidget);

    final ownerCard = find.ancestor(
      of: find.text('Dueño Queso'),
      matching: find.byType(OrgMemberCard),
    );
    expect(
      find.descendant(of: ownerCard, matching: find.byIcon(Icons.more_vert)),
      findsNothing,
    );

    // La card de un miembro normal sí conserva su menú ⋮.
    final normalCard = find.ancestor(
      of: find.text('User 0'),
      matching: find.byType(OrgMemberCard),
    );
    expect(
      find.descendant(of: normalCard, matching: find.byIcon(Icons.more_vert)),
      findsOneWidget,
    );
  });

  testWidgets('pull-to-refresh sobre la lista dispara refresh()', (
    tester,
  ) async {
    var refreshCalls = 0;
    when(() => mockListCubit.refresh()).thenAnswer((_) async => refreshCalls++);
    currentListState = loadedState();
    await tester.pumpWidget(buildApp());

    await tester.drag(memberListView(), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshCalls, 1);
  });

  testWidgets(
    'el FAB expande el speed dial con las dos acciones y el scrim las cierra',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());

      // §48 — tap en el FAB: suben las dos acciones y el ícono morfa
      // person_add → close.
      await tester.tap(find.byIcon(Icons.person_add_outlined));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('users-speed-dial-create')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('users-speed-dial-link')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap afuera (scrim transparente) cierra el dial sin disparar
      // nada debajo.
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('users-speed-dial-create')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('users-speed-dial-link')), findsNothing);
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    },
  );

  testWidgets('la acción "Crear usuario" abre el sheet de creación', (
    tester,
  ) async {
    useTallSurface(tester);
    currentListState = loadedState();
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('users-speed-dial-create')));
    await tester.pumpAndSettle();

    // El sheet de creación abierto — su título es "Nuevo usuario" y el
    // submit repite el label de la acción.
    expect(find.text('Nuevo usuario'), findsOneWidget);
    expect(find.byType(NewUserSheet), findsOneWidget);
  });

  testWidgets(
    'crear desde el sheet inserta el miembro al tope vía prependMember',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());
      await openAndFillSheet(tester);

      await tester.tap(find.text('Crear usuario'));
      await tester.pump();

      // El submit salió al cubit del sheet con los valores del form.
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
      // §49 — la screen delega el insert optimista al cubit.
      verify(() => mockListCubit.prependMember(tCreated)).called(1);

      // Cuando el cubit emite la nueva lista, la primera card es la del
      // miembro nuevo (va al tope hasta el próximo refresh — el orden
      // real del backend es created_at ASC).
      emitListState(
        loadedState(members: [tCreated, ...tMembers(15)], total: 35),
      );
      // Dos pumps: el primero drena el microtask del stream (setState
      // del BlocBuilder), el segundo construye el frame con las cards.
      await tester.pump();
      await tester.pump();
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
    },
  );

  testWidgets(
    'la acción "Vincular existente" abre el LinkUserSheet y su resultado inserta el miembro + toast info',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());

      // Speed dial → acción de vinculación.
      await tester.tap(find.byIcon(Icons.person_add_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('users-speed-dial-link')));
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
      // §49 — insert optimista delegado al cubit del listado.
      verify(() => mockListCubit.prependMember(tLinked)).called(1);

      emitListState(
        loadedState(members: [tLinked, ...tMembers(15)], total: 35),
      );
      await tester.pump();
      await tester.pump();
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

  testWidgets(
    'suspender desde el menú dispara el PATCH real vía setMemberStatus (§52)',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());

      // La primera card (User 0) viene suspendida en el fixture — se usa
      // la segunda (User 1, activa), la primera cuyo ⋮ ofrece
      // "Suspender usuario".
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
      expect(find.text('¿Suspender a User 1?'), findsOneWidget);

      // CTA del diálogo → confirma; la screen dispara el PATCH real vía
      // el cubit (§52). El stub default de setUp resuelve con éxito.
      await tester.tap(find.text('Suspender usuario'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockListCubit.setMemberStatus(captureAny(), captureAny()),
      ).captured;
      expect((captured[0] as OrgMember).id, 'u1');
      expect(captured[1], MemberStatus.suspended);

      // Éxito del PATCH → warning ámbar (mismo criterio que §45).
      expect(find.text('Membresía suspendida'), findsOneWidget);

      // El cubit real mergea el ítem fresco del 200 y emite el nuevo
      // estado — se simula acá para probar que la card refleja el flip.
      final members = tMembers(15);
      emitListState(
        loadedState(
          members: [
            members[0],
            members[1].copyWith(status: MemberStatus.suspended),
            ...members.sublist(2),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(of: card, matching: find.text('Suspendido')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'suspender con failure del backend muestra el toast mapeado, sin flip',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      when(
        () => mockListCubit.setMemberStatus(any(), any()),
      ).thenAnswer((_) async => const Left(LastAdminFailure()));
      await tester.pumpWidget(buildApp());

      final card = find.byType(OrgMemberCard).at(1);
      final menuButton = find.descendant(
        of: card,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.ensureVisible(menuButton);
      await tester.pumpAndSettle();
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspender usuario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspender usuario'));
      await tester.pumpAndSettle();

      // El toast rojo traduce el error de dominio — no el genérico.
      expect(
        find.text(
          'Es el último administrador activo — nombrá otro admin antes',
        ),
        findsOneWidget,
      );
      // Sin flip: la card sigue activa (el cubit no mergeó nada).
      expect(
        find.descendant(of: card, matching: find.text('Suspendido')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '"Cambiar rol" abre el diálogo y dispara setMemberRole con el rol elegido (§54)',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      await tester.pumpWidget(buildApp());

      // Segunda card (User 1, activa) — su ⋮ ofrece "Cambiar rol".
      final card = find.byType(OrgMemberCard).at(1);
      final menuButton = find.descendant(
        of: card,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.ensureVisible(menuButton);
      await tester.pumpAndSettle();
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Ítem neutro entre Suspender y Restablecer — abre ChangeRoleDialog.
      await tester.tap(find.text('Cambiar rol'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar rol de User 1'), findsOneWidget);
      // El rol actual (Operador) viene preseleccionado → el CTA arranca
      // deshabilitado (mismo rol = no-op, ni PATCH ni toast).
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Cambiar'),
            )
            .onPressed,
        isNull,
      );

      // Se elige Recolector → CTA habilitado → confirmar dispara el PATCH.
      // (scoped al diálogo — los RoleFilterChips del header repiten el
      // mismo label).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Recolector'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cambiar'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockListCubit.setMemberRole(captureAny(), captureAny()),
      ).captured;
      expect((captured[0] as OrgMember).id, 'u1');
      expect(captured[1], UserRole.collector);

      // Éxito → toast con el feedback de reingreso (doc 012: el backend
      // revocó la sesión del miembro — el rol nuevo aplica al entrar).
      expect(
        find.text('Rol de User 1 actualizado — reingresa con el rol nuevo'),
        findsOneWidget,
      );

      // El cubit real mergea el ítem fresco — se simula la emisión y la
      // card muestra el chip del rol nuevo.
      final members = tMembers(15);
      emitListState(
        loadedState(
          members: [
            members[0],
            members[1].copyWith(role: UserRole.collector),
            ...members.sublist(2),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(of: card, matching: find.text('Recolector')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'cambio de rol con failure del backend muestra el toast mapeado',
    (tester) async {
      useTallSurface(tester);
      currentListState = loadedState();
      when(
        () => mockListCubit.setMemberRole(any(), any()),
      ).thenAnswer((_) async => const Left(OwnerRoleChangeFailure()));
      await tester.pumpWidget(buildApp());

      final card = find.byType(OrgMemberCard).at(1);
      final menuButton = find.descendant(
        of: card,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.ensureVisible(menuButton);
      await tester.pumpAndSettle();
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar rol'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Administrador'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cambiar'));
      await tester.pumpAndSettle();

      // El toast rojo traduce el error de dominio — no el genérico.
      expect(
        find.text('No se puede cambiar el rol del dueño de la organización'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );
}
