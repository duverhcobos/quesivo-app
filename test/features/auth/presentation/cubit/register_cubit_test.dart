import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';

import 'package:quesivo/features/auth/domain/use_cases/register_use_case.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/presentation/cubit/register_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/register_state.dart';

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  late MockRegisterUseCase mockRegisterUseCase;

  setUp(() {
    mockRegisterUseCase = MockRegisterUseCase();
  });

  RegisterCubit buildCubit() => RegisterCubit(mockRegisterUseCase);

  const tUser = User(id: '1', email: 'maria@quesera.com', name: 'María');

  void fillValidForm(RegisterCubit cubit) {
    cubit
      ..organizationNameChanged('Quesera Los Alpes')
      ..fullNameChanged('María Quesera')
      ..emailChanged('maria@quesera.com')
      ..passwordChanged('Queso123')
      ..confirmPasswordChanged('Queso123')
      ..termsToggled(true);
  }

  test('el estado inicial es RegisterState limpio e inválido', () {
    expect(buildCubit().state, const RegisterState());
    expect(buildCubit().state.isValid, false);
  });

  blocTest<RegisterCubit, RegisterState>(
    'sin aceptar términos el formulario completo sigue inválido',
    build: buildCubit,
    act: (cubit) {
      cubit
        ..organizationNameChanged('Quesera Los Alpes')
        ..fullNameChanged('María Quesera')
        ..emailChanged('maria@quesera.com')
        ..passwordChanged('Queso123')
        ..confirmPasswordChanged('Queso123');
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<RegisterCubit, RegisterState>(
    'formulario completo + términos aceptados => isValid true',
    build: buildCubit,
    act: fillValidForm,
    verify: (cubit) => expect(cubit.state.isValid, true),
  );

  blocTest<RegisterCubit, RegisterState>(
    'confirmar un password distinto invalida el formulario',
    build: buildCubit,
    act: (cubit) {
      fillValidForm(cubit);
      cubit.confirmPasswordChanged('Otro123');
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<RegisterCubit, RegisterState>(
    'cambiar el password re-evalúa la confirmación ya escrita',
    build: buildCubit,
    act: (cubit) {
      fillValidForm(cubit);
      cubit.passwordChanged('Queso124'); // la confirmación quedó con Queso123
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<RegisterCubit, RegisterState>(
    'submit con formulario inválido no emite nada ni llama al use case',
    build: buildCubit,
    act: (cubit) => cubit.submit(),
    expect: () => const <RegisterState>[],
    verify: (_) => verifyZeroInteractions(mockRegisterUseCase),
  );

  blocTest<RegisterCubit, RegisterState>(
    'submit válido emite inProgress y luego success',
    build: buildCubit,
    seed: () => const RegisterState(isValid: true),
    setUp: () {
      when(
        () => mockRegisterUseCase(
          organizationName: any(named: 'organizationName'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Right(tUser));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const RegisterState(
        isValid: true,
        status: FormzSubmissionStatus.inProgress,
      ),
      const RegisterState(isValid: true, status: FormzSubmissionStatus.success),
    ],
  );

  blocTest<RegisterCubit, RegisterState>(
    'submit con falla del servidor emite failure con errorMessage',
    build: buildCubit,
    seed: () => const RegisterState(isValid: true),
    setUp: () {
      when(
        () => mockRegisterUseCase(
          organizationName: any(named: 'organizationName'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(EmailAlreadyInUseFailure()));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const RegisterState(
        isValid: true,
        status: FormzSubmissionStatus.inProgress,
      ),
      const RegisterState(
        isValid: true,
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Ya existe una cuenta con ese correo.',
      ),
    ],
  );
}
