import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/session/session_expired_notifier.dart';
import 'package:quesivo/features/auth/domain/entities/organization_session.dart';
import 'package:quesivo/features/auth/domain/entities/organization_summary.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/use_cases/check_auth_status_use_case.dart';
import 'package:quesivo/features/auth/domain/use_cases/login_use_case.dart';
import 'package:quesivo/features/auth/domain/use_cases/login_with_google_use_case.dart';
import 'package:quesivo/features/auth/domain/use_cases/logout_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockLoginWithGoogleUseCase extends Mock
    implements LoginWithGoogleUseCase {}

class MockCheckAuthStatusUseCase extends Mock
    implements CheckAuthStatusUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockSessionExpiredNotifier extends Mock
    implements SessionExpiredNotifier {}

void main() {
  late AuthCubit cubit;
  late MockLoginUseCase mockLoginUseCase;
  late MockLoginWithGoogleUseCase mockLoginWithGoogleUseCase;
  late MockCheckAuthStatusUseCase mockCheckAuthStatusUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockSessionExpiredNotifier mockSessionExpiredNotifier;

  const tEmail = 'test@test.com';
  const tPassword = 'password123';
  const tUser = User(id: '1', email: tEmail, name: 'John Doe', token: 'token');

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockLoginWithGoogleUseCase = MockLoginWithGoogleUseCase();
    mockCheckAuthStatusUseCase = MockCheckAuthStatusUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockSessionExpiredNotifier = MockSessionExpiredNotifier();
    when(
      () => mockSessionExpiredNotifier.stream,
    ).thenAnswer((_) => const Stream<void>.empty());

    cubit = AuthCubit(
      mockLoginUseCase,
      mockLoginWithGoogleUseCase,
      mockCheckAuthStatusUseCase,
      mockLogoutUseCase,
      mockSessionExpiredNotifier,
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('el estado inicial es AuthLoading', () {
    expect(cubit.state, const AuthLoading());
  });

  blocTest<AuthCubit, AuthState>(
    'checkSession emite [AuthLoading, AuthSuccess] cuando hay sesión válida',
    build: () {
      when(
        () => mockCheckAuthStatusUseCase(),
      ).thenAnswer((_) async => const Right(tUser));
      return cubit;
    },
    seed: () => const AuthInitial(),
    act: (cubit) => cubit.checkSession(),
    expect: () => [const AuthLoading(), const AuthSuccess(tUser)],
  );

  blocTest<AuthCubit, AuthState>(
    'checkSession emite [AuthLoading, AuthInitial] cuando no hay sesión',
    build: () {
      when(
        () => mockCheckAuthStatusUseCase(),
      ).thenAnswer((_) async => const Left(NoSessionFailure()));
      return cubit;
    },
    seed: () => const AuthSuccess(tUser),
    act: (cubit) => cubit.checkSession(),
    expect: () => [const AuthLoading(), const AuthInitial()],
  );

  blocTest<AuthCubit, AuthState>(
    'login emite [AuthLoading, AuthSuccess] cuando el UseCase responde éxito',
    build: () {
      when(
        () => mockLoginUseCase(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Right(tUser));
      return cubit;
    },
    seed: () => const AuthInitial(),
    act: (cubit) => cubit.login(tEmail, tPassword),
    expect: () => [const AuthLoading(), const AuthSuccess(tUser)],
  );

  blocTest<AuthCubit, AuthState>(
    'login emite [AuthLoading, AuthError] cuando el UseCase falla',
    build: () {
      when(
        () => mockLoginUseCase(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Left(InvalidCredentialsFailure()));
      return cubit;
    },
    seed: () => const AuthInitial(),
    act: (cubit) => cubit.login(tEmail, tPassword),
    expect: () => [
      const AuthLoading(),
      const AuthError('Correo o contraseña incorrectos.'),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'loginWithGoogle emite [AuthLoading, AuthSuccess] en éxito',
    build: () {
      when(
        () => mockLoginWithGoogleUseCase(),
      ).thenAnswer((_) async => const Right(tUser));
      return cubit;
    },
    seed: () => const AuthInitial(),
    act: (cubit) => cubit.loginWithGoogle(),
    expect: () => [const AuthLoading(), const AuthSuccess(tUser)],
  );

  blocTest<AuthCubit, AuthState>(
    'loginWithGoogle emite [AuthLoading, AuthError] cuando falla',
    build: () {
      when(() => mockLoginWithGoogleUseCase()).thenAnswer(
        (_) async =>
            const Left(ServerFailure('No se pudo iniciar sesión con Google.')),
      );
      return cubit;
    },
    seed: () => const AuthInitial(),
    act: (cubit) => cubit.loginWithGoogle(),
    expect: () => [
      const AuthLoading(),
      const AuthError('No se pudo iniciar sesión con Google.'),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'logout invoca al UseCase y emite AuthInitial en éxito',
    build: () {
      when(
        () => mockLogoutUseCase(),
      ).thenAnswer((_) async => const Right<AuthFailure, void>(null));
      return cubit;
    },
    seed: () => const AuthSuccess(tUser),
    act: (cubit) => cubit.logout(),
    expect: () => [const AuthInitial()],
    verify: (_) {
      verify(() => mockLogoutUseCase()).called(1);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'logout emite AuthError si falla el borrado de sesión',
    build: () {
      when(() => mockLogoutUseCase()).thenAnswer(
        (_) async => const Left<AuthFailure, void>(
          CacheFailure('No se pudo cerrar la sesión.'),
        ),
      );
      return cubit;
    },
    seed: () => const AuthSuccess(tUser),
    act: (cubit) => cubit.logout(),
    expect: () => [const AuthError('No se pudo cerrar la sesión.')],
  );

  test(
    'emite AuthInitial cuando el refresh token muere estando autenticado',
    () async {
      when(
        () => mockLoginUseCase(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Right(tUser));

      // Notifier REAL: el evento "sesión muerta" es el disparador que se
      // prueba (interceptor -> cubit -> AuthInitial), no tiene sentido
      // mockearlo porque no tiene dependencias.
      final notifier = SessionExpiredNotifier();
      final c = AuthCubit(
        mockLoginUseCase,
        mockLoginWithGoogleUseCase,
        mockCheckAuthStatusUseCase,
        mockLogoutUseCase,
        notifier,
      );
      addTearDown(() async {
        await c.close();
        notifier.dispose();
      });

      await c.login(tEmail, tPassword);
      expect(c.state, const AuthSuccess(tUser));

      notifier.notifySessionExpired();
      await Future<void>.delayed(Duration.zero);

      expect(c.state, isA<AuthInitial>());
    },
  );

  group('enterOrganization (§57)', () {
    blocTest<AuthCubit, AuthState>(
      'en AuthSuccess re-emite el mismo user con enteredOrg=true',
      build: () => cubit,
      seed: () => const AuthSuccess(tUser),
      act: (cubit) => cubit.enterOrganization(),
      expect: () => [const AuthSuccess(tUser, enteredOrg: true)],
    );

    blocTest<AuthCubit, AuthState>(
      'con enteredOrg ya true no re-emite (el flag ya está prendido)',
      build: () => cubit,
      seed: () => const AuthSuccess(tUser, enteredOrg: true),
      act: (cubit) => cubit.enterOrganization(),
      expect: () => <AuthState>[],
    );

    blocTest<AuthCubit, AuthState>(
      'fuera de AuthSuccess no hace nada (p.ej. si refreshSession '
      'terminó en AuthInitial)',
      build: () => cubit,
      seed: () => const AuthInitial(),
      act: (cubit) => cubit.enterOrganization(),
      expect: () => <AuthState>[],
    );
  });

  group('enterOrganizationWithSession (§63)', () {
    const tOrgs = [
      OrganizationSummary(id: 'org-1', name: 'Quesera Norte', role: 'ADMIN'),
      OrganizationSummary(id: 'org-2', name: 'Quesera Sur', role: 'OPERATOR'),
    ];
    const tOrgUser = User(
      id: '1',
      email: tEmail,
      name: 'John Doe',
      token: 'token-personal',
      refreshToken: 'refresh-personal',
      roles: ['PERSONAL'],
      organizations: tOrgs,
    );
    const tSession = OrganizationSession(
      accessToken: 'access-org',
      refreshToken: 'refresh-org',
      organizationId: 'org-2',
      organizationName: 'Quesera Sur',
    );

    blocTest<AuthCubit, AuthState>(
      'reconstruye el User con tokens/org/rol de la sesión y prende '
      'enteredOrg — sin llamar /me',
      build: () => cubit,
      seed: () => const AuthSuccess(tOrgUser),
      act: (cubit) => cubit.enterOrganizationWithSession(tSession),
      expect: () => [
        const AuthSuccess(
          User(
            id: '1',
            email: tEmail,
            name: 'John Doe',
            token: 'access-org',
            refreshToken: 'refresh-org',
            organizationId: 'org-2',
            organizationName: 'Quesera Sur',
            roles: ['OPERATOR'],
            organizations: tOrgs,
          ),
          enteredOrg: true,
        ),
      ],
      verify: (_) {
        verifyNever(() => mockCheckAuthStatusUseCase());
      },
    );

    blocTest<AuthCubit, AuthState>(
      'si la org no está en organizations conserva los roles actuales',
      build: () => cubit,
      seed: () => const AuthSuccess(tOrgUser),
      act: (cubit) => cubit.enterOrganizationWithSession(
        const OrganizationSession(
          accessToken: 'a',
          refreshToken: 'r',
          organizationId: 'org-99',
          organizationName: 'Desconocida',
        ),
      ),
      expect: () => [
        const AuthSuccess(
          User(
            id: '1',
            email: tEmail,
            name: 'John Doe',
            token: 'a',
            refreshToken: 'r',
            organizationId: 'org-99',
            organizationName: 'Desconocida',
            roles: ['PERSONAL'],
            organizations: tOrgs,
          ),
          enteredOrg: true,
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'fuera de AuthSuccess no hace nada',
      build: () => cubit,
      seed: () => const AuthInitial(),
      act: (cubit) => cubit.enterOrganizationWithSession(tSession),
      expect: () => <AuthState>[],
    );
  });

  group('exitOrganization (§58)', () {
    blocTest<AuthCubit, AuthState>(
      'con enteredOrg=true re-emite el mismo user con la flag limpia',
      build: () => cubit,
      seed: () => const AuthSuccess(tUser, enteredOrg: true),
      act: (cubit) => cubit.exitOrganization(),
      expect: () => [const AuthSuccess(tUser)],
    );

    blocTest<AuthCubit, AuthState>(
      'con enteredOrg=false no re-emite (ya está en el selector)',
      build: () => cubit,
      seed: () => const AuthSuccess(tUser),
      act: (cubit) => cubit.exitOrganization(),
      expect: () => <AuthState>[],
    );

    blocTest<AuthCubit, AuthState>(
      'fuera de AuthSuccess no hace nada',
      build: () => cubit,
      seed: () => const AuthInitial(),
      act: (cubit) => cubit.exitOrganization(),
      expect: () => <AuthState>[],
    );
  });
}
