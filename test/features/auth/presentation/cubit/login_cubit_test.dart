import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';

import 'package:quesivo/features/auth/domain/use_cases/login_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/login_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/login_state.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/value_objects/email.dart';
import 'package:quesivo/features/auth/domain/value_objects/password.dart';

// Disfrazamos al UseCase completo (Inversión de Control local)
class MockLoginUseCase extends Mock implements LoginUseCase {}

// Fallo falso para probar errores
class FakeAuthFailure extends AuthFailure {
  const FakeAuthFailure(super.message);
}

void main() {
  late LoginCubit cubit;
  late MockLoginUseCase mockLoginUseCase;

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    cubit = LoginCubit(mockLoginUseCase);
  });

  tearDown(() {
    cubit.close();
  });

  const tEmail = 'test@test.com';
  const tPassword = 'password123';
  const tUser = User(id: '1', email: tEmail, name: 'John Doe', token: 'token');

  test('el estado inicial debe ser LoginState limpio', () {
    expect(cubit.state, const LoginState());
    expect(cubit.state.status, FormzSubmissionStatus.initial);
  });

  blocTest<LoginCubit, LoginState>(
    'cuando el email cambia, deberia emitir un nuevo estado donde el formulario no es válido aún',
    build: () => cubit,
    act: (cubit) => cubit.emailChanged('invalid_email'),
    expect: () => [
      isA<LoginState>()
          .having((s) => s.email.value, 'email', 'invalid_email')
          .having(
            (s) => s.isValid,
            'isValid',
            false,
          ), // Falta el password para ser válido
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'cuando submit se llama exitosamente, emite [inProgress, success]',
    build: () {
      // Le enseñamos al mock cómo responder
      when(
        () => mockLoginUseCase(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Right(tUser));
      return cubit;
    },
    // Le damos una semilla (estado pre-arrancado donde los campos sí son válidos)
    seed: () => const LoginState(
      email: Email.dirty(tEmail),
      password: Password.dirty(tPassword),
      isValid: true,
    ),
    act: (cubit) => cubit.submit(),
    expect: () => [
      isA<LoginState>().having(
        (state) => state.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<LoginState>().having(
        (state) => state.status,
        'status',
        FormzSubmissionStatus.success,
      ),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'cuando submit falla en el UseCase, emite [inProgress, failure]',
    build: () {
      when(
        () => mockLoginUseCase(email: tEmail, password: tPassword),
      ).thenAnswer(
        (_) async => const Left(FakeAuthFailure('Error falso de internet')),
      );
      return cubit;
    },
    seed: () => const LoginState(
      email: Email.dirty(tEmail),
      password: Password.dirty(tPassword),
      isValid: true,
    ),
    act: (cubit) => cubit.submit(),
    expect: () => [
      isA<LoginState>().having(
        (state) => state.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<LoginState>()
          .having(
            (state) => state.status,
            'status',
            FormzSubmissionStatus.failure,
          )
          .having(
            (state) => state.errorMessage,
            'mensaje',
            'Error falso de internet',
          ),
    ],
  );
}
