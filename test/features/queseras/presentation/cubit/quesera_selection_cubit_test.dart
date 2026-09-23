import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/auth/domain/entities/organization_session.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/use_cases/select_organization_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/queseras/presentation/cubit/quesera_selection_cubit.dart';
import 'package:quesivo/features/queseras/presentation/cubit/quesera_selection_state.dart';

class MockSelectOrganizationUseCase extends Mock
    implements SelectOrganizationUseCase {}

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late QueseraSelectionCubit cubit;
  late MockSelectOrganizationUseCase mockSelectOrg;
  late MockAuthCubit mockAuthCubit;

  const tOrgId = 'org-1';
  const tSession = OrganizationSession(
    accessToken: 'access-org',
    refreshToken: 'refresh-org',
    organizationId: tOrgId,
    organizationName: 'Quesera Norte',
  );

  setUpAll(() {
    // Necesario para `any()` en verify/verifyNever sobre métodos que
    // reciben OrganizationSession (enterOrganizationWithSession).
    registerFallbackValue(tSession);
  });

  setUp(() {
    mockSelectOrg = MockSelectOrganizationUseCase();
    mockAuthCubit = MockAuthCubit();
    // Default: sin sesión cargada el shortcut mismo-org (§57) no aplica
    // — el select cae al flujo normal del use case.
    when(() => mockAuthCubit.state).thenReturn(const AuthInitial());

    cubit = QueseraSelectionCubit(mockSelectOrg, mockAuthCubit);
  });

  tearDown(() {
    cubit.close();
  });

  test('el estado inicial no tiene selección ni error', () {
    expect(cubit.state, const QueseraSelectionState());
    expect(cubit.state.isSelecting, isFalse);
  });

  blocTest<QueseraSelectionCubit, QueseraSelectionState>(
    'éxito (tap en otra org): emite selecting → '
    'enterOrganizationWithSession → clear; devuelve true SIN /auth/me',
    build: () {
      when(() => mockSelectOrg(tOrgId)).thenAnswer(
        (_) async => const Right<AuthFailure, OrganizationSession>(tSession),
      );
      return cubit;
    },
    act: (cubit) async {
      final entered = await cubit.select(tOrgId);
      expect(entered, isTrue);
    },
    expect: () => [
      const QueseraSelectionState(selectingId: tOrgId),
      const QueseraSelectionState(),
    ],
    verify: (_) {
      verify(() => mockSelectOrg(tOrgId)).called(1);
      // §63 — el User se reconstruye con la sesión del response; no hay
      // refreshSession/getMe extra ni un enterOrganization() suelto.
      verify(
        () => mockAuthCubit.enterOrganizationWithSession(tSession),
      ).called(1);
      verifyNever(() => mockAuthCubit.refreshSession());
      verifyNever(() => mockAuthCubit.enterOrganization());
    },
  );

  test('tap en la org que ya trae el JWT (§57, sesión restaurada): entrada '
      'gratis — enterOrganization sin POST ni refresh ni spinner', () async {
    when(() => mockAuthCubit.state).thenReturn(
      const AuthSuccess(
        User(
          id: 'u1',
          email: 'ana@test.com',
          name: 'Ana',
          organizationId: tOrgId,
        ),
      ),
    );

    final entered = await cubit.select(tOrgId);

    expect(entered, isTrue);
    // Sin emit: la card ni siquiera llega a mostrar selección.
    expect(cubit.state, const QueseraSelectionState());
    verify(() => mockAuthCubit.enterOrganization()).called(1);
    verifyNever(() => mockSelectOrg(any()));
    verifyNever(() => mockAuthCubit.refreshSession());
    verifyNever(() => mockAuthCubit.enterOrganizationWithSession(any()));
  });

  blocTest<QueseraSelectionCubit, QueseraSelectionState>(
    'enteredOrg ya true: el tap hace el flujo completo aunque sea la '
    'misma org del JWT (POST + enterWithSession, sin refresh)',
    build: () {
      when(() => mockAuthCubit.state).thenReturn(
        const AuthSuccess(
          User(
            id: 'u1',
            email: 'ana@test.com',
            name: 'Ana',
            organizationId: tOrgId,
          ),
          enteredOrg: true,
        ),
      );
      when(() => mockSelectOrg(tOrgId)).thenAnswer(
        (_) async => const Right<AuthFailure, OrganizationSession>(tSession),
      );
      return cubit;
    },
    act: (cubit) async {
      final entered = await cubit.select(tOrgId);
      expect(entered, isTrue);
    },
    expect: () => [
      const QueseraSelectionState(selectingId: tOrgId),
      const QueseraSelectionState(),
    ],
    verify: (_) {
      verify(() => mockSelectOrg(tOrgId)).called(1);
      verify(
        () => mockAuthCubit.enterOrganizationWithSession(tSession),
      ).called(1);
      verifyNever(() => mockAuthCubit.refreshSession());
    },
  );

  blocTest<QueseraSelectionCubit, QueseraSelectionState>(
    'error: emite errorMessage y limpia la selección; devuelve false '
    'sin tocar AuthCubit',
    build: () {
      when(() => mockSelectOrg(tOrgId)).thenAnswer(
        (_) async =>
            const Left<AuthFailure, OrganizationSession>(ServerFailure('Boom')),
      );
      return cubit;
    },
    act: (cubit) async {
      final entered = await cubit.select(tOrgId);
      expect(entered, isFalse);
    },
    expect: () => [
      const QueseraSelectionState(selectingId: tOrgId),
      const QueseraSelectionState(errorMessage: 'Boom'),
    ],
    verify: (_) {
      verifyNever(() => mockAuthCubit.refreshSession());
      verifyNever(() => mockAuthCubit.enterOrganizationWithSession(any()));
    },
  );

  test(
    'doble tap mientras una selección está en vuelo: el segundo se ignora',
    () async {
      final completer = Completer<Either<AuthFailure, OrganizationSession>>();
      when(() => mockSelectOrg(any())).thenAnswer((_) => completer.future);

      final first = cubit.select(tOrgId);
      // El emit de selectingId ocurre antes del primer await — el estado
      // ya está ocupado cuando la segunda llamada evalúa isSelecting.
      final second = await cubit.select('org-2');

      expect(second, isFalse);
      verify(() => mockSelectOrg(tOrgId)).called(1);
      verifyNever(() => mockSelectOrg('org-2'));

      completer.complete(
        const Right<AuthFailure, OrganizationSession>(tSession),
      );
      expect(await first, isTrue);
    },
  );
}
