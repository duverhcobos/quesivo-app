import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';

import 'package:quesivo/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/presentation/cubit/reset_password_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/reset_password_state.dart';

class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

void main() {
  late MockResetPasswordUseCase mockResetPasswordUseCase;

  setUp(() {
    mockResetPasswordUseCase = MockResetPasswordUseCase();
  });

  ResetPasswordCubit buildCubit() =>
      ResetPasswordCubit(mockResetPasswordUseCase, token: 'token-del-correo');

  void fillValidForm(ResetPasswordCubit cubit) {
    cubit
      ..passwordChanged('Queso123')
      ..confirmPasswordChanged('Queso123');
  }

  test('el estado inicial es ResetPasswordState limpio e inválido', () {
    expect(buildCubit().state, const ResetPasswordState());
    expect(buildCubit().state.isValid, false);
  });

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'formulario completo y coincidente => isValid true',
    build: buildCubit,
    act: fillValidForm,
    verify: (cubit) => expect(cubit.state.isValid, true),
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'password débil mantiene el formulario inválido',
    build: buildCubit,
    act: (cubit) {
      cubit
        ..passwordChanged('debil')
        ..confirmPasswordChanged('debil');
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'confirmar un password distinto invalida el formulario',
    build: buildCubit,
    act: (cubit) {
      fillValidForm(cubit);
      cubit.confirmPasswordChanged('Otro123');
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'cambiar el password re-evalúa la confirmación ya escrita',
    build: buildCubit,
    act: (cubit) {
      fillValidForm(cubit);
      cubit.passwordChanged('Queso124'); // la confirmación quedó con Queso123
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'submit con formulario inválido no emite nada ni llama al use case',
    build: buildCubit,
    act: (cubit) => cubit.submit(),
    expect: () => const <ResetPasswordState>[],
    verify: (_) => verifyZeroInteractions(mockResetPasswordUseCase),
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'submit válido emite inProgress y luego success',
    build: buildCubit,
    seed: () => const ResetPasswordState(isValid: true),
    setUp: () {
      when(
        () => mockResetPasswordUseCase(
          token: any(named: 'token'),
          password: any(named: 'password'),
          confirmPassword: any(named: 'confirmPassword'),
        ),
      ).thenAnswer((_) async => const Right(null));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const ResetPasswordState(
        isValid: true,
        status: FormzSubmissionStatus.inProgress,
      ),
      const ResetPasswordState(
        isValid: true,
        status: FormzSubmissionStatus.success,
      ),
    ],
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'submit con falla del servidor emite failure con errorMessage',
    build: buildCubit,
    seed: () => const ResetPasswordState(isValid: true),
    setUp: () {
      when(
        () => mockResetPasswordUseCase(
          token: any(named: 'token'),
          password: any(named: 'password'),
          confirmPassword: any(named: 'confirmPassword'),
        ),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('Token inválido o expirado')),
      );
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const ResetPasswordState(
        isValid: true,
        status: FormzSubmissionStatus.inProgress,
      ),
      const ResetPasswordState(
        isValid: true,
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Token inválido o expirado',
      ),
    ],
  );
}
