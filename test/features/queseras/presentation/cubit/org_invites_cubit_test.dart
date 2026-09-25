import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/auth/domain/entities/org_invite.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/use_cases/accept_org_invite_use_case.dart';
import 'package:quesivo/features/auth/domain/use_cases/decline_org_invite_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/queseras/presentation/cubit/org_invites_cubit.dart';
import 'package:quesivo/features/queseras/presentation/cubit/org_invites_state.dart';

class MockAcceptOrgInviteUseCase extends Mock
    implements AcceptOrgInviteUseCase {}

class MockDeclineOrgInviteUseCase extends Mock
    implements DeclineOrgInviteUseCase {}

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late OrgInvitesCubit cubit;
  late MockAcceptOrgInviteUseCase mockAccept;
  late MockDeclineOrgInviteUseCase mockDecline;
  late MockAuthCubit mockAuthCubit;

  const tInvite = OrgInvite(
    id: 'mem-1',
    organizationId: 'org-9',
    organizationName: 'Quesera Norte',
    role: 'OPERATOR',
  );

  setUpAll(() {
    // Para `any()` en verify/verifyNever de applyOrgInviteAccepted/Declined.
    registerFallbackValue(tInvite);
  });

  setUp(() {
    mockAccept = MockAcceptOrgInviteUseCase();
    mockDecline = MockDeclineOrgInviteUseCase();
    mockAuthCubit = MockAuthCubit();
    when(() => mockAuthCubit.state).thenReturn(const AuthInitial());

    cubit = OrgInvitesCubit(mockAccept, mockDecline, mockAuthCubit);
  });

  tearDown(() {
    cubit.close();
  });

  test('el estado inicial no tiene respuesta en vuelo ni error', () {
    expect(cubit.state, const OrgInvitesState());
    expect(cubit.state.isResponding, isFalse);
  });

  blocTest<OrgInvitesCubit, OrgInvitesState>(
    'accept ok: emite respondingId → limpio, llama applyOrgInviteAccepted '
    'en AuthCubit (el User se actualiza en el lugar) y devuelve true',
    build: () {
      when(
        () => mockAccept('org-9'),
      ).thenAnswer((_) async => const Right<AuthFailure, void>(null));
      return cubit;
    },
    act: (cubit) async {
      final ok = await cubit.accept(tInvite);
      expect(ok, isTrue);
    },
    expect: () => [
      const OrgInvitesState(respondingId: 'mem-1'),
      const OrgInvitesState(),
    ],
    verify: (_) {
      verify(() => mockAccept('org-9')).called(1);
      verify(() => mockAuthCubit.applyOrgInviteAccepted(tInvite)).called(1);
      verifyNever(() => mockAuthCubit.refreshSession());
    },
  );

  blocTest<OrgInvitesCubit, OrgInvitesState>(
    'accept 404: emite failure, limpia respondingId y REMUEVE la card '
    'stale vía applyOrgInviteDeclined (la membresía ya no existe)',
    build: () {
      when(() => mockAccept('org-9')).thenAnswer(
        (_) async => const Left<AuthFailure, void>(OrgInviteNotFoundFailure()),
      );
      return cubit;
    },
    act: (cubit) async {
      final ok = await cubit.accept(tInvite);
      expect(ok, isFalse);
    },
    expect: () => [
      const OrgInvitesState(respondingId: 'mem-1'),
      const OrgInvitesState(failure: OrgInviteNotFoundFailure()),
    ],
    verify: (_) {
      verifyNever(() => mockAuthCubit.applyOrgInviteAccepted(any()));
      verify(() => mockAuthCubit.applyOrgInviteDeclined(tInvite)).called(1);
    },
  );

  blocTest<OrgInvitesCubit, OrgInvitesState>(
    'accept falla no-404 (ej. red): failure + respondingId limpio, la '
    'card sigue (la invitación existe todavía)',
    build: () {
      when(() => mockAccept('org-9')).thenAnswer(
        (_) async => const Left<AuthFailure, void>(NetworkFailure()),
      );
      return cubit;
    },
    act: (cubit) async {
      final ok = await cubit.accept(tInvite);
      expect(ok, isFalse);
    },
    expect: () => [
      const OrgInvitesState(respondingId: 'mem-1'),
      const OrgInvitesState(failure: NetworkFailure()),
    ],
    verify: (_) {
      verifyNever(() => mockAuthCubit.applyOrgInviteAccepted(any()));
      verifyNever(() => mockAuthCubit.applyOrgInviteDeclined(any()));
    },
  );

  blocTest<OrgInvitesCubit, OrgInvitesState>(
    'decline ok: emite respondingId → limpio y llama '
    'applyOrgInviteDeclined (la card desaparece de pendingInvites)',
    build: () {
      when(
        () => mockDecline('org-9'),
      ).thenAnswer((_) async => const Right<AuthFailure, void>(null));
      return cubit;
    },
    act: (cubit) async {
      final ok = await cubit.decline(tInvite);
      expect(ok, isTrue);
    },
    expect: () => [
      const OrgInvitesState(respondingId: 'mem-1'),
      const OrgInvitesState(),
    ],
    verify: (_) {
      verify(() => mockDecline('org-9')).called(1);
      verify(() => mockAuthCubit.applyOrgInviteDeclined(tInvite)).called(1);
    },
  );

  blocTest<OrgInvitesCubit, OrgInvitesState>(
    'decline falla no-404: failure + respondingId limpio, sin tocar AuthCubit',
    build: () {
      when(() => mockDecline('org-9')).thenAnswer(
        (_) async => const Left<AuthFailure, void>(NetworkFailure()),
      );
      return cubit;
    },
    act: (cubit) async {
      final ok = await cubit.decline(tInvite);
      expect(ok, isFalse);
    },
    expect: () => [
      const OrgInvitesState(respondingId: 'mem-1'),
      const OrgInvitesState(failure: NetworkFailure()),
    ],
    verify: (_) {
      verifyNever(() => mockAuthCubit.applyOrgInviteDeclined(any()));
    },
  );

  blocTest<OrgInvitesCubit, OrgInvitesState>(
    'decline 404: también remueve la card stale vía '
    'applyOrgInviteDeclined (el resultado es el mismo que un decline ok)',
    build: () {
      when(() => mockDecline('org-9')).thenAnswer(
        (_) async => const Left<AuthFailure, void>(OrgInviteNotFoundFailure()),
      );
      return cubit;
    },
    act: (cubit) async {
      final ok = await cubit.decline(tInvite);
      expect(ok, isFalse);
    },
    expect: () => [
      const OrgInvitesState(respondingId: 'mem-1'),
      const OrgInvitesState(failure: OrgInviteNotFoundFailure()),
    ],
    verify: (_) {
      verify(() => mockAuthCubit.applyOrgInviteDeclined(tInvite)).called(1);
    },
  );

  test(
    'isResponding bloquea el segundo tap (una respuesta a la vez)',
    () async {
      final completer = Completer<Either<AuthFailure, void>>();
      when(() => mockAccept(any())).thenAnswer((_) => completer.future);

      final first = cubit.accept(tInvite);
      // El emit de respondingId ocurre antes del primer await — el estado
      // ya está ocupado cuando la segunda llamada evalúa isResponding.
      const other = OrgInvite(
        id: 'mem-2',
        organizationId: 'org-2',
        organizationName: 'Quesera Sur',
        role: 'ADMIN',
      );
      final second = await cubit.accept(other);

      expect(second, isFalse);
      verify(() => mockAccept('org-9')).called(1);
      verifyNever(() => mockAccept('org-2'));

      completer.complete(const Right<AuthFailure, void>(null));
      expect(await first, isTrue);
    },
  );
}
