import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

void main() {
  late AuthCubit cubit;
  late MockLoginUseCase mockLoginUseCase;
  late MockLoginWithGoogleUseCase mockLoginWithGoogleUseCase;
  late MockCheckAuthStatusUseCase mockCheckAuthStatusUseCase;
  late MockLogoutUseCase mockLogoutUseCase;

  const tEmail = 'test@test.com';
  const tPassword = 'password123';
  const tUser = User(id: '1', email: tEmail, name: 'John Doe', token: 'token');

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockLoginWithGoogleUseCase = MockLoginWithGoogleUseCase();
    mockCheckAuthStatusUseCase = MockCheckAuthStatusUseCase();
    mockLogoutUseCase = MockLogoutUseCase();

    cubit = AuthCubit(
      mockLoginUseCase,
      mockLoginWithGoogleUseCase,
      mockCheckAuthStatusUseCase,
      mockLogoutUseCase,
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
}
