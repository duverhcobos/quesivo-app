import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/auth/domain/entities/organization_session.dart';
import 'package:quesivo/features/auth/domain/entities/organization_summary.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/use_cases/select_organization_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/organization/domain/failures/organization_failure.dart';
import 'package:quesivo/features/organization/domain/use_cases/skip_org_name_setup_use_case.dart';
import 'package:quesivo/features/organization/domain/use_cases/update_organization_name_use_case.dart';
import 'package:quesivo/features/organization/presentation/cubit/org_name_setup_cubit.dart';
import 'package:quesivo/features/organization/presentation/cubit/org_name_setup_state.dart';

class MockUpdateOrganizationNameUseCase extends Mock
    implements UpdateOrganizationNameUseCase {}

class MockSkipOrgNameSetupUseCase extends Mock
    implements SkipOrgNameSetupUseCase {}

class MockSelectOrganizationUseCase extends Mock
    implements SelectOrganizationUseCase {}

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late OrgNameSetupCubit cubit;
  late MockUpdateOrganizationNameUseCase mockUpdateName;
  late MockSkipOrgNameSetupUseCase mockSkipSetup;
  late MockSelectOrganizationUseCase mockSelectOrg;
  late MockAuthCubit mockAuthCubit;

  const tName = 'Quesera Los Alpes';

  setUpAll(() {
    registerFallbackValue(
      const OrganizationSession(
        accessToken: '',
        refreshToken: '',
        organizationId: '',
        organizationName: '',
      ),
    );
  });

  setUp(() {
    mockUpdateName = MockUpdateOrganizationNameUseCase();
    mockSkipSetup = MockSkipOrgNameSetupUseCase();
    mockSelectOrg = MockSelectOrganizationUseCase();
    mockAuthCubit = MockAuthCubit();
    when(() => mockAuthCubit.state).thenReturn(const AuthInitial());
    // MockCubit intercepta isClosed — sin el stub el getter lanza
    // MissingStubError en los guards post-await del cubit.
    when(() => mockAuthCubit.isClosed).thenReturn(false);

    cubit = OrgNameSetupCubit(
      mockUpdateName,
      mockSkipSetup,
      mockSelectOrg,
      mockAuthCubit,
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('el estado inicial no está en vuelo ni tiene failure', () {
    expect(cubit.state, const OrgNameSetupState());
    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.failure, isNull);
  });

  blocTest<OrgNameSetupCubit, OrgNameSetupState>(
    'submit ok: emite submitting → llama applyOrganizationRenamed en el '
    'AuthCubit con el nombre confirmado (sin emit de "idle" — la '
    'pantalla sale por el guard con el flag ya limpio)',
    build: () {
      when(() => mockUpdateName(tName)).thenAnswer(
        (_) async => const Right<OrganizationFailure, String>(tName),
      );
      return cubit;
    },
    act: (cubit) => cubit.submit(tName),
    expect: () => [const OrgNameSetupState(isSubmitting: true)],
    verify: (_) {
      verify(() => mockUpdateName(tName)).called(1);
      verify(() => mockAuthCubit.applyOrganizationRenamed(tName)).called(1);
      verifyNever(() => mockAuthCubit.skipOrgNameSetup());
    },
  );

  blocTest<OrgNameSetupCubit, OrgNameSetupState>(
    'submit failure: emite submitting → failure tipado para que la '
    'pantalla lo mapee a su l10n (offline vs genérico)',
    build: () {
      when(() => mockUpdateName(tName)).thenAnswer(
        (_) async => const Left<OrganizationFailure, String>(
          OrganizationNetworkFailure(),
        ),
      );
      return cubit;
    },
    act: (cubit) => cubit.submit(tName),
    expect: () => [
      const OrgNameSetupState(isSubmitting: true),
      const OrgNameSetupState(
        isSubmitting: false,
        failure: OrganizationNetworkFailure(),
      ),
    ],
    verify: (_) {
      verifyNever(() => mockAuthCubit.applyOrganizationRenamed(any()));
    },
  );

  test('un segundo submit mientras hay uno en vuelo se ignora '
      '(anti doble-tap — solo un PATCH a la vez)', () async {
    final completer = Completer<Either<OrganizationFailure, String>>();
    when(() => mockUpdateName(any())).thenAnswer((_) => completer.future);

    final first = cubit.submit('Primero');
    // El emit de isSubmitting ocurre antes del primer await — el estado
    // ya está ocupado cuando el segundo submit lo evalúa.
    await cubit.submit('Segundo');

    verify(() => mockUpdateName('Primero')).called(1);
    verifyNever(() => mockUpdateName('Segundo'));

    completer.complete(const Right<OrganizationFailure, String>(tName));
    await first;
  });

  blocTest<OrgNameSetupCubit, OrgNameSetupState>(
    'skip: emite submitting (anti doble-tap), persiste el flag limpio '
    'vía use case y luego limpia el flag en memoria — sin PATCH',
    build: () {
      when(
        () => mockSkipSetup(),
      ).thenAnswer((_) async => const Right<OrganizationFailure, void>(null));
      return cubit;
    },
    act: (cubit) => cubit.skip(),
    expect: () => [const OrgNameSetupState(isSubmitting: true)],
    verify: (_) {
      verify(() => mockSkipSetup()).called(1);
      verify(() => mockAuthCubit.skipOrgNameSetup()).called(1);
      verifyNever(() => mockUpdateName(any()));
      verifyNever(() => mockAuthCubit.applyOrganizationRenamed(any()));
    },
  );

  blocTest<OrgNameSetupCubit, OrgNameSetupState>(
    'skip con falla de persistencia limpia el flag en memoria igual '
    '(best-effort — peor caso: la pantalla reaparece tras un restart)',
    build: () {
      when(() => mockSkipSetup()).thenAnswer(
        (_) async =>
            const Left<OrganizationFailure, void>(OrganizationUpdateFailure()),
      );
      return cubit;
    },
    act: (cubit) => cubit.skip(),
    expect: () => [const OrgNameSetupState(isSubmitting: true)],
    verify: (_) {
      verify(() => mockAuthCubit.skipOrgNameSetup()).called(1);
    },
  );

  blocTest<OrgNameSetupCubit, OrgNameSetupState>(
    'submit con sesión personal (isNewSignup sin entrar a la org): entra '
    'por debajo vía select-organization y luego PATCH — la pantalla va '
    'antes del home',
    build: () {
      when(() => mockAuthCubit.state).thenReturn(
        const AuthSuccess(
          User(
            id: '1',
            email: 'd@t.com',
            name: 'D',
            isNewSignup: true,
            organizations: [
              OrganizationSummary(
                id: 'org-1',
                name: 'Duver Cobos',
                role: 'ADMIN',
              ),
            ],
          ),
        ),
      );
      when(() => mockSelectOrg('org-1')).thenAnswer(
        (_) async => const Right<AuthFailure, OrganizationSession>(
          OrganizationSession(
            accessToken: 't',
            refreshToken: 'r',
            organizationId: 'org-1',
            organizationName: 'Duver Cobos',
          ),
        ),
      );
      when(() => mockUpdateName(tName)).thenAnswer(
        (_) async => const Right<OrganizationFailure, String>(tName),
      );
      return cubit;
    },
    act: (cubit) => cubit.submit(tName),
    expect: () => [const OrgNameSetupState(isSubmitting: true)],
    verify: (_) {
      verify(() => mockSelectOrg('org-1')).called(1);
      verify(() => mockAuthCubit.enterOrganizationWithSession(any())).called(1);
      verify(() => mockUpdateName(tName)).called(1);
      verify(() => mockAuthCubit.applyOrganizationRenamed(tName)).called(1);
    },
  );

  blocTest<OrgNameSetupCubit, OrgNameSetupState>(
    'submit con sesión personal y falla en select-organization → '
    'failure genérico, sin PATCH',
    build: () {
      when(() => mockAuthCubit.state).thenReturn(
        const AuthSuccess(
          User(
            id: '1',
            email: 'd@t.com',
            name: 'D',
            isNewSignup: true,
            organizations: [
              OrganizationSummary(
                id: 'org-1',
                name: 'Duver Cobos',
                role: 'ADMIN',
              ),
            ],
          ),
        ),
      );
      when(() => mockSelectOrg('org-1')).thenAnswer(
        (_) async =>
            const Left<AuthFailure, OrganizationSession>(ServerFailure('boom')),
      );
      return cubit;
    },
    act: (cubit) => cubit.submit(tName),
    expect: () => [
      const OrgNameSetupState(isSubmitting: true),
      const OrgNameSetupState(
        isSubmitting: false,
        failure: OrganizationUpdateFailure(),
      ),
    ],
    verify: (_) {
      verifyNever(() => mockUpdateName(any()));
      verifyNever(() => mockAuthCubit.applyOrganizationRenamed(any()));
    },
  );
}
