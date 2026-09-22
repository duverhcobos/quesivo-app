import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/entities/users_page.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/use_cases/list_users_use_case.dart';
import 'package:quesivo/features/users/domain/use_cases/update_user_role_use_case.dart';
import 'package:quesivo/features/users/domain/use_cases/update_user_status_use_case.dart';
import 'package:quesivo/features/users/presentation/cubit/users_list_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/users_list_state.dart';

// Disfrazamos al UseCase completo (Inversión de Control local)
class MockListUsersUseCase extends Mock implements ListUsersUseCase {}

class MockUpdateUserStatusUseCase extends Mock
    implements UpdateUserStatusUseCase {}

class MockUpdateUserRoleUseCase extends Mock implements UpdateUserRoleUseCase {}

void main() {
  late UsersListCubit cubit;
  late MockListUsersUseCase mockListUsers;
  late MockUpdateUserStatusUseCase mockUpdateStatus;
  late MockUpdateUserRoleUseCase mockUpdateRole;

  /// Gate manual para demorar una respuesta del use case — permite
  /// probar el token de generación (respuesta vieja que vuelve tarde).
  late Completer<Either<UsersFailure, UsersPage>> loadMoreGate;

  const tM1 = OrgMember(
    id: 'u1',
    email: 'ana@mail.com',
    name: 'Ana Pérez',
    role: UserRole.operator,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );
  const tM2 = OrgMember(
    id: 'u2',
    email: 'juan@mail.com',
    name: 'Juan Gómez',
    role: UserRole.admin,
    status: MemberStatus.active,
    organizationId: 'org-1',
    isOwner: true,
  );
  const tM3 = OrgMember(
    id: 'u3',
    email: 'pedro@mail.com',
    name: 'Pedro Ruiz',
    role: UserRole.collector,
    status: MemberStatus.suspended,
    organizationId: 'org-1',
  );
  const tM4 = OrgMember(
    id: 'u4',
    email: 'lucia@mail.com',
    name: 'Lucía Torres',
    role: UserRole.producer,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );

  const tPage1 = UsersPage(
    items: [tM1, tM2],
    page: 1,
    limit: 15,
    total: 4,
    totalPages: 2,
  );
  // La página 2 repite u2 (solape defensivo) — el dedup por id debe
  // evitar la card duplicada.
  const tPage2 = UsersPage(
    items: [tM2, tM3, tM4],
    page: 2,
    limit: 15,
    total: 4,
    totalPages: 2,
  );

  const tLoadedPage1 = UsersListState(
    status: UsersListStatus.loaded,
    members: [tM1, tM2],
    total: 4,
    page: 1,
    hasMore: true,
  );

  /// Stub genérico — matchea cualquier combinación de params.
  void stubGetUsers(Either<UsersFailure, UsersPage> result) {
    when(
      () => mockListUsers(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        search: any(named: 'search'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Stub con secuencia custom — para probar el token de generación.
  void stubGetUsersWith(
    Future<Either<UsersFailure, UsersPage>> Function(int call) answer,
  ) {
    var call = 0;
    when(
      () => mockListUsers(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        search: any(named: 'search'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) => answer(++call));
  }

  setUpAll(() {
    registerFallbackValue(MemberStatus.suspended);
    registerFallbackValue(UserRole.operator);
  });

  setUp(() {
    mockListUsers = MockListUsersUseCase();
    mockUpdateStatus = MockUpdateUserStatusUseCase();
    mockUpdateRole = MockUpdateUserRoleUseCase();
    cubit = UsersListCubit(mockListUsers, mockUpdateStatus, mockUpdateRole);
    loadMoreGate = Completer<Either<UsersFailure, UsersPage>>();
  });

  tearDown(() {
    cubit.close();
  });

  test('el estado inicial es UsersListState limpio (status initial)', () {
    expect(cubit.state, const UsersListState());
    expect(cubit.state.status, UsersListStatus.initial);
    expect(cubit.state.members, isEmpty);
    expect(cubit.state.hasMore, isFalse);
  });

  blocTest<UsersListCubit, UsersListState>(
    'load() exitoso emite [loading, loaded] con items y meta del response',
    build: () {
      stubGetUsers(const Right(tPage1));
      return cubit;
    },
    act: (c) => c.load(),
    expect: () => [
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>()
          .having((s) => s.status, 'status', UsersListStatus.loaded)
          .having((s) => s.members, 'members', tPage1.items)
          .having((s) => s.total, 'total', 4)
          .having((s) => s.page, 'page', 1)
          .having((s) => s.hasMore, 'hasMore', true),
    ],
    verify: (_) {
      // Página 1 con el pageSize del cubit y sin filtros activos.
      verify(
        () => mockListUsers(page: 1, limit: 15, search: null, role: null),
      ).called(1);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'load() que falla emite [loading, error+failure]',
    build: () {
      stubGetUsers(const Left(UsersNetworkFailure()));
      return cubit;
    },
    act: (c) => c.load(),
    expect: () => [
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>()
          .having((s) => s.status, 'status', UsersListStatus.error)
          .having((s) => s.failure, 'failure', const UsersNetworkFailure()),
    ],
  );

  blocTest<UsersListCubit, UsersListState>(
    'retry tras error vuelve a emitir [loading, loaded]',
    build: () {
      stubGetUsersWith(
        (call) async =>
            call == 1 ? const Left(UsersNetworkFailure()) : const Right(tPage1),
      );
      return cubit;
    },
    act: (c) async {
      await c.load();
      await c.load();
    },
    expect: () => [
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.error,
      ),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>()
          .having((s) => s.status, 'status', UsersListStatus.loaded)
          .having((s) => s.failure, 'failure', isNull),
    ],
    verify: (_) {
      verify(
        () => mockListUsers(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          role: any(named: 'role'),
        ),
      ).called(2);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'loadMore() apila la página 2 con dedup por id y actualiza hasMore',
    build: () {
      stubGetUsers(const Right(tPage2));
      return cubit;
    },
    seed: () => tLoadedPage1,
    act: (c) => c.loadMore(),
    expect: () => [
      isA<UsersListState>().having(
        (s) => s.isLoadingMore,
        'isLoadingMore',
        true,
      ),
      isA<UsersListState>()
          .having((s) => s.isLoadingMore, 'isLoadingMore', false)
          // u2 venía repetido en la página 2 — quedan 4 filas, no 5.
          .having((s) => s.members, 'members', [tM1, tM2, tM3, tM4])
          .having((s) => s.page, 'page', 2)
          .having((s) => s.hasMore, 'hasMore', false),
    ],
    verify: (_) {
      verify(
        () => mockListUsers(page: 2, limit: 15, search: null, role: null),
      ).called(1);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'loadMore() sin hasMore no pega al use case ni emite',
    build: () {
      stubGetUsers(const Right(tPage2));
      return cubit;
    },
    seed: () => tLoadedPage1.copyWith(hasMore: false),
    act: (c) => c.loadMore(),
    expect: () => <UsersListState>[],
    verify: (_) {
      verifyNever(
        () => mockListUsers(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          role: any(named: 'role'),
        ),
      );
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'un segundo loadMore() en vuelo se ignora (anti doble-call)',
    build: () {
      stubGetUsers(const Right(tPage2));
      return cubit;
    },
    seed: () => tLoadedPage1,
    act: (c) async {
      // El primer loadMore emite isLoadingMore:true de forma síncrona
      // (antes del await del use case); el segundo ve el flag y retorna.
      await Future.wait([c.loadMore(), c.loadMore()]);
    },
    verify: (_) {
      verify(
        () => mockListUsers(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          role: any(named: 'role'),
        ),
      ).called(1);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'loadMore() en error apaga el spinner sin romper el listado',
    build: () {
      stubGetUsers(const Left(UsersRateLimitFailure()));
      return cubit;
    },
    seed: () => tLoadedPage1,
    act: (c) => c.loadMore(),
    expect: () => [
      isA<UsersListState>().having(
        (s) => s.isLoadingMore,
        'isLoadingMore',
        true,
      ),
      isA<UsersListState>()
          .having((s) => s.isLoadingMore, 'isLoadingMore', false)
          .having((s) => s.status, 'status', UsersListStatus.loaded)
          .having((s) => s.members, 'members', tLoadedPage1.members),
    ],
  );

  blocTest<UsersListCubit, UsersListState>(
    'setQuery guarda el query (trim) y relanza load a página 1 con search',
    build: () {
      stubGetUsers(const Right(tPage1));
      return cubit;
    },
    seed: () => tLoadedPage1,
    act: (c) => c.setQuery('  ana '),
    expect: () => [
      isA<UsersListState>().having((s) => s.query, 'query', 'ana'),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>()
          .having((s) => s.status, 'status', UsersListStatus.loaded)
          .having((s) => s.page, 'page', 1),
    ],
    verify: (_) {
      verify(
        () => mockListUsers(page: 1, limit: 15, search: 'ana', role: null),
      ).called(1);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'setRole guarda el filtro y relanza load a página 1 con role',
    build: () {
      stubGetUsers(const Right(tPage1));
      return cubit;
    },
    seed: () => tLoadedPage1,
    act: (c) => c.setRole(UserRole.producer),
    expect: () => [
      isA<UsersListState>().having(
        (s) => s.roleFilter,
        'roleFilter',
        UserRole.producer,
      ),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loaded,
      ),
    ],
    verify: (_) {
      verify(
        () => mockListUsers(
          page: 1,
          limit: 15,
          search: null,
          role: UserRole.producer,
        ),
      ).called(1);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'setRole(null) limpia el filtro a "Todos" y relanza load',
    build: () {
      stubGetUsers(const Right(tPage1));
      return cubit;
    },
    seed: () => tLoadedPage1.copyWith(roleFilter: UserRole.admin),
    act: (c) => c.setRole(null),
    expect: () => [
      isA<UsersListState>().having((s) => s.roleFilter, 'roleFilter', isNull),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loaded,
      ),
    ],
    verify: (_) {
      verify(
        () => mockListUsers(page: 1, limit: 15, search: null, role: null),
      ).called(1);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'setQuery con el mismo query efectivo es no-op (sin refetch)',
    build: () {
      stubGetUsers(const Right(tPage1));
      return cubit;
    },
    seed: () => tLoadedPage1.copyWith(query: 'ana'),
    act: (c) => c.setQuery('ana   '),
    expect: () => <UsersListState>[],
    verify: (_) {
      verifyNever(
        () => mockListUsers(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          role: any(named: 'role'),
        ),
      );
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'refresh() vuelve a pedir la página 1 con los filtros activos',
    build: () {
      stubGetUsers(const Right(tPage1));
      return cubit;
    },
    seed: () => tLoadedPage1.copyWith(
      members: [tM1, tM2, tM3, tM4],
      page: 2,
      hasMore: false,
      query: 'ana',
      roleFilter: UserRole.operator,
    ),
    act: (c) => c.refresh(),
    // §51 — refresh() ya no emite `loading` (el indicador visual del pull
    // es el RefreshIndicator, no el estado del cubit): el copyWith inicial
    // queda idéntico al seed y solo llega el loaded con la página 1.
    expect: () => [
      isA<UsersListState>()
          .having((s) => s.status, 'status', UsersListStatus.loaded)
          .having((s) => s.page, 'page', 1),
    ],
    verify: (_) {
      verify(
        () => mockListUsers(
          page: 1,
          limit: 15,
          search: 'ana',
          role: UserRole.operator,
        ),
      ).called(1);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'refresh() que falla con miembros emite error SIN loading, conserva la lista y apaga hasMore',
    build: () {
      stubGetUsers(const Left(UsersNetworkFailure()));
      return cubit;
    },
    // Lista previa con hasMore:true — el error la conserva pero apaga
    // el footer (§51 review: el hasMore era del query viejo y loadMore
    // es no-op bajo error — el spinner eterno era el bug).
    seed: () => tLoadedPage1.copyWith(
      members: [tM1, tM2, tM3, tM4],
      page: 2,
      hasMore: true,
      query: 'ana',
    ),
    act: (c) => c.refresh(),
    expect: () => [
      isA<UsersListState>()
          .having((s) => s.status, 'status', UsersListStatus.error)
          .having((s) => s.members, 'members', [tM1, tM2, tM3, tM4])
          .having((s) => s.hasMore, 'hasMore', false)
          .having((s) => s.errorNonce, 'errorNonce', 1),
    ],
  );

  blocTest<UsersListCubit, UsersListState>(
    'dos fallos consecutivos emiten estados distintos (errorNonce sube — el retry no queda mudo)',
    build: () {
      stubGetUsers(const Left(UsersNetworkFailure()));
      return cubit;
    },
    seed: () => tLoadedPage1,
    act: (c) async {
      await c.refresh();
      await c.refresh();
    },
    // §51 review: sin el nonce, el segundo error Equatable-idéntico sería
    // deduplicado por el cubit y el toast del listener no volvería a
    // disparar — cada intento fallido debe ser observable. El emit
    // intermedio (failure:null, mismo nonce) es el copyWith inicial del
    // segundo refresh limpiando el failure previo antes del fetch.
    expect: () => [
      isA<UsersListState>().having((s) => s.errorNonce, 'errorNonce', 1),
      isA<UsersListState>()
          .having((s) => s.errorNonce, 'errorNonce', 1)
          .having((s) => s.failure, 'failure', isNull),
      isA<UsersListState>().having((s) => s.errorNonce, 'errorNonce', 2),
    ],
  );

  blocTest<UsersListCubit, UsersListState>(
    'setQuery con texto que trimmea a vacío relanza load() con search null',
    build: () {
      stubGetUsers(const Right(tPage1));
      return cubit;
    },
    seed: () => tLoadedPage1.copyWith(query: 'ana'),
    act: (c) => c.setQuery('   '),
    expect: () => [
      // El emit del query normalizado ('') …
      isA<UsersListState>().having((s) => s.query, 'query', ''),
      // … luego el loading del refetch y el loaded de la respuesta.
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loaded,
      ),
    ],
    verify: (_) {
      verify(
        () => mockListUsers(page: 1, limit: 15, search: null, role: null),
      ).called(1);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'prependMember inserta al tope y sube el total (dedup por id)',
    build: () => cubit,
    seed: () => tLoadedPage1,
    act: (c) {
      c.prependMember(tM4);
      // Id ya presente: se mueve al tope sin duplicar ni inflar el
      // total (un reorder no suma miembro a la org).
      c.prependMember(tM1);
    },
    expect: () => [
      isA<UsersListState>()
          .having((s) => s.members, 'members', [tM4, tM1, tM2])
          .having((s) => s.total, 'total', 5),
      isA<UsersListState>()
          .having((s) => s.members, 'members', [tM1, tM4, tM2])
          .having((s) => s.total, 'total', 5),
    ],
  );

  blocTest<UsersListCubit, UsersListState>(
    'updateMember reemplaza por id (flip de status local hasta el PATCH real)',
    build: () => cubit,
    seed: () => tLoadedPage1,
    act: (c) => c.updateMember(tM2.copyWith(status: MemberStatus.suspended)),
    expect: () => [
      isA<UsersListState>().having((s) => s.members, 'members', [
        tM1,
        tM2.copyWith(status: MemberStatus.suspended),
      ]),
    ],
  );

  blocTest<UsersListCubit, UsersListState>(
    'updateMember con id ausente no emite',
    build: () => cubit,
    seed: () => tLoadedPage1,
    act: (c) => c.updateMember(tM4),
    expect: () => <UsersListState>[],
  );

  test(
    'una load vieja en vuelo no pisa el resultado de la nueva (token)',
    () async {
      final gate = Completer<Either<UsersFailure, UsersPage>>();
      stubGetUsersWith(
        (call) => call == 1 ? gate.future : Future.value(const Right(tPage1)),
      );

      final stale = cubit.load();
      await cubit.load(); // token nuevo — completa con tPage1 y emite

      // La primera respuesta vuelve tarde con otra data: se descarta.
      gate.complete(
        const Right(
          UsersPage(
            items: [tM3, tM4],
            page: 1,
            limit: 15,
            total: 2,
            totalPages: 1,
          ),
        ),
      );
      await stale;

      expect(cubit.state.status, UsersListStatus.loaded);
      expect(cubit.state.members, tPage1.items);
      expect(cubit.state.total, 4);
    },
  );

  blocTest<UsersListCubit, UsersListState>(
    'loadMore en vuelo se descarta si un load() nuevo lo invalidó',
    build: () {
      stubGetUsersWith(
        (call) =>
            call == 1 ? loadMoreGate.future : Future.value(const Right(tPage1)),
      );
      return cubit;
    },
    seed: () => tLoadedPage1,
    act: (c) async {
      final staleMore = c.loadMore(); // queda esperando el gate
      await c.load(); // invalida el token del loadMore
      loadMoreGate.complete(const Right(tPage2));
      await staleMore;
    },
    // El append de la página 2 vieja no se aplicó: quedan los items de
    // la load() nueva (tPage1) y sin duplicados.
    expect: () => [
      isA<UsersListState>().having(
        (s) => s.isLoadingMore,
        'isLoadingMore',
        true,
      ),
      isA<UsersListState>().having(
        (s) => s.status,
        'status',
        UsersListStatus.loading,
      ),
      isA<UsersListState>()
          .having((s) => s.status, 'status', UsersListStatus.loaded)
          .having((s) => s.members, 'members', tPage1.items)
          .having((s) => s.page, 'page', 1),
    ],
  );

  test('load completado tras cerrar la pantalla no emite ni lanza', () async {
    stubGetUsers(const Right(tPage1));
    final pending = cubit.load();
    await cubit.close();

    await expectLater(pending, completes);
  });

  group('setMemberStatus (§52 — PATCH real)', () {
    const tSuspendedM1 = OrgMember(
      id: 'u1',
      email: 'ana@mail.com',
      name: 'Ana Pérez',
      role: UserRole.operator,
      status: MemberStatus.suspended,
      organizationId: 'org-1',
    );

    void stubUpdateStatus(Future<Either<UsersFailure, OrgMember>> answer) {
      when(
        () => mockUpdateStatus(
          userId: any(named: 'userId'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) => answer);
    }

    blocTest<UsersListCubit, UsersListState>(
      'éxito: marca busy, llama al use case, mergea el ítem del 200 y libera busy',
      build: () {
        stubUpdateStatus(Future.value(const Right(tSuspendedM1)));
        return cubit;
      },
      seed: () => tLoadedPage1,
      act: (c) => c.setMemberStatus(tM1, MemberStatus.suspended),
      expect: () => [
        // busy ON — la card muestra loader en vez del ⋮
        isA<UsersListState>().having(
          (s) => s.busyMemberIds,
          'busyMemberIds',
          contains('u1'),
        ),
        // busy OFF
        isA<UsersListState>().having(
          (s) => s.busyMemberIds,
          'busyMemberIds',
          isNot(contains('u1')),
        ),
        // merge del ítem fresco — status suspended en la lista
        isA<UsersListState>().having(
          (s) => s.members.firstWhere((m) => m.id == 'u1').status,
          'members[u1].status',
          MemberStatus.suspended,
        ),
      ],
      verify: (_) {
        verify(
          () => mockUpdateStatus(userId: 'u1', status: MemberStatus.suspended),
        ).called(1);
      },
    );

    blocTest<UsersListCubit, UsersListState>(
      'failure: libera busy y NO toca el miembro (la screen tosta el error)',
      build: () {
        stubUpdateStatus(Future.value(const Left(LastAdminFailure())));
        return cubit;
      },
      seed: () => tLoadedPage1,
      act: (c) async {
        final result = await c.setMemberStatus(tM1, MemberStatus.suspended);
        // El Either crudo vuelve a la screen para el toast mapeado.
        expect(result, const Left(LastAdminFailure()));
      },
      expect: () => [
        isA<UsersListState>().having(
          (s) => s.busyMemberIds,
          'busyMemberIds',
          contains('u1'),
        ),
        isA<UsersListState>().having(
          (s) => s.busyMemberIds,
          'busyMemberIds',
          isNot(contains('u1')),
        ),
      ],
      verify: (c) {
        // El miembro quedó intacto — nada de flip optimista.
        expect(
          c.state.members.firstWhere((m) => m.id == 'u1').status,
          MemberStatus.active,
        );
      },
    );

    test(
      'segunda acción sobre la misma card con PATCH en vuelo es no-op defensivo',
      () async {
        final gate = Completer<Either<UsersFailure, OrgMember>>();
        stubUpdateStatus(gate.future);

        final first = cubit.setMemberStatus(tM1, MemberStatus.suspended);
        await pumpEventQueue(); // deja emitir el busy
        expect(cubit.state.busyMemberIds, contains('u1'));

        // Segunda llamada: no invoca el use case de nuevo y devuelve el
        // miembro intacto (no un error falso).
        final second = await cubit.setMemberStatus(tM1, MemberStatus.active);
        expect(second, const Right(tM1));
        verify(
          () => mockUpdateStatus(
            userId: any(named: 'userId'),
            status: any(named: 'status'),
          ),
        ).called(1);

        gate.complete(const Right(tSuspendedM1));
        await first;
      },
    );

    test(
      'setMemberStatus completado tras cerrar la pantalla no emite ni lanza',
      () async {
        stubUpdateStatus(Future.value(const Right(tSuspendedM1)));
        final pending = cubit.setMemberStatus(tM1, MemberStatus.suspended);
        await cubit.close();

        // El PATCH pudo aplicarse en el backend igual — el guard isClosed
        // evita el StateError del emit sobre el cubit muerto.
        await expectLater(pending, completes);
      },
    );
  });

  group('setMemberRole (§54 — PATCH /role real)', () {
    const tCollectorM1 = OrgMember(
      id: 'u1',
      email: 'ana@mail.com',
      name: 'Ana Pérez',
      role: UserRole.collector,
      status: MemberStatus.active,
      organizationId: 'org-1',
    );

    void stubUpdateRole(Future<Either<UsersFailure, OrgMember>> answer) {
      when(
        () => mockUpdateRole(
          userId: any(named: 'userId'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) => answer);
    }

    blocTest<UsersListCubit, UsersListState>(
      'éxito: marca busy, llama al use case, mergea el ítem del 200 y libera busy',
      build: () {
        stubUpdateRole(Future.value(const Right(tCollectorM1)));
        return cubit;
      },
      seed: () => tLoadedPage1,
      act: (c) => c.setMemberRole(tM1, UserRole.collector),
      expect: () => [
        // busy ON — la card muestra loader en vez del ⋮
        isA<UsersListState>().having(
          (s) => s.busyMemberIds,
          'busyMemberIds',
          contains('u1'),
        ),
        // busy OFF
        isA<UsersListState>().having(
          (s) => s.busyMemberIds,
          'busyMemberIds',
          isNot(contains('u1')),
        ),
        // merge del ítem fresco — rol collector en la lista
        isA<UsersListState>().having(
          (s) => s.members.firstWhere((m) => m.id == 'u1').role,
          'members[u1].role',
          UserRole.collector,
        ),
      ],
      verify: (_) {
        verify(
          () => mockUpdateRole(userId: 'u1', role: UserRole.collector),
        ).called(1);
      },
    );

    blocTest<UsersListCubit, UsersListState>(
      'failure: libera busy y NO toca el miembro (la screen tosta el error)',
      build: () {
        stubUpdateRole(Future.value(const Left(OwnerRoleChangeFailure())));
        return cubit;
      },
      seed: () => tLoadedPage1,
      act: (c) async {
        final result = await c.setMemberRole(tM1, UserRole.admin);
        // El Either crudo vuelve a la screen para el toast mapeado.
        expect(result, const Left(OwnerRoleChangeFailure()));
      },
      expect: () => [
        isA<UsersListState>().having(
          (s) => s.busyMemberIds,
          'busyMemberIds',
          contains('u1'),
        ),
        isA<UsersListState>().having(
          (s) => s.busyMemberIds,
          'busyMemberIds',
          isNot(contains('u1')),
        ),
      ],
      verify: (c) {
        // El miembro quedó intacto — nada de flip optimista.
        expect(
          c.state.members.firstWhere((m) => m.id == 'u1').role,
          UserRole.operator,
        );
      },
    );

    test(
      'segunda acción sobre la misma card con PATCH en vuelo es no-op defensivo',
      () async {
        final gate = Completer<Either<UsersFailure, OrgMember>>();
        stubUpdateRole(gate.future);

        final first = cubit.setMemberRole(tM1, UserRole.collector);
        await pumpEventQueue(); // deja emitir el busy
        expect(cubit.state.busyMemberIds, contains('u1'));

        // Segunda llamada: no invoca el use case de nuevo y devuelve el
        // miembro intacto (no un error falso).
        final second = await cubit.setMemberRole(tM1, UserRole.admin);
        expect(second, const Right(tM1));
        verify(
          () => mockUpdateRole(
            userId: any(named: 'userId'),
            role: any(named: 'role'),
          ),
        ).called(1);

        gate.complete(const Right(tCollectorM1));
        await first;
      },
    );

    test(
      'setMemberRole completado tras cerrar la pantalla no emite ni lanza',
      () async {
        stubUpdateRole(Future.value(const Right(tCollectorM1)));
        final pending = cubit.setMemberRole(tM1, UserRole.collector);
        await cubit.close();

        await expectLater(pending, completes);
      },
    );
  });
}
