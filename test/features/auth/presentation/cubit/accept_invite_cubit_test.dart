import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';

import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/use_cases/accept_invite_use_case.dart';
import 'package:quesivo/features/auth/domain/use_cases/resend_verification_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/accept_invite_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/accept_invite_state.dart';

class MockAcceptInviteUseCase extends Mock implements AcceptInviteUseCase {}

class MockResendVerificationUseCase extends Mock
    implements ResendVerificationUseCase {}

void main() {
  late MockAcceptInviteUseCase mockAcceptInviteUseCase;
  late MockResendVerificationUseCase mockResendVerificationUseCase;

  setUp(() {
    mockAcceptInviteUseCase = MockAcceptInviteUseCase();
    mockResendVerificationUseCase = MockResendVerificationUseCase();
  });

  const tToken = 'invite-token-abc';
  const tEmail = 'invitado@test.com';
  const tUser = User(id: '1', email: tEmail, name: 'Invitado', token: 'token');

  AcceptInviteCubit buildCubit({
    String token = tToken,
    String email = tEmail,
  }) => AcceptInviteCubit(
    mockAcceptInviteUseCase,
    mockResendVerificationUseCase,
    token: token,
    email: email,
  );

  void fillValidForm(AcceptInviteCubit cubit) {
    cubit
      ..passwordChanged('Queso123')
      ..confirmPasswordChanged('Queso123');
  }

  test('el estado inicial conserva el email del query param y es inválido', () {
    expect(buildCubit().state, const AcceptInviteState(email: tEmail));
    expect(buildCubit().state.isValid, false);
    expect(buildCubit().state.status, FormzSubmissionStatus.initial);
    expect(buildCubit().hasToken, isTrue);
  });

  test('hasToken es false cuando el deep link llegó sin ?token=', () {
    expect(buildCubit(token: '').hasToken, isFalse);
  });

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'formulario completo y coincidente => isValid true',
    build: buildCubit,
    act: fillValidForm,
    verify: (cubit) => expect(cubit.state.isValid, true),
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'confirmar un password distinto invalida el formulario',
    build: buildCubit,
    act: (cubit) {
      fillValidForm(cubit);
      cubit.confirmPasswordChanged('Otro123');
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'cambiar el password re-evalúa la confirmación ya escrita',
    build: buildCubit,
    act: (cubit) {
      fillValidForm(cubit);
      cubit.passwordChanged('Queso124'); // la confirmación quedó con Queso123
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'submit con formulario inválido no emite nada ni llama al use case',
    build: buildCubit,
    act: (cubit) => cubit.submit(),
    expect: () => const <AcceptInviteState>[],
    verify: (_) => verifyZeroInteractions(mockAcceptInviteUseCase),
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'submit válido emite inProgress y luego success (auto-login lo '
    'persiste el repo — la pantalla llama refreshSession)',
    build: buildCubit,
    seed: () => const AcceptInviteState(email: tEmail, isValid: true),
    setUp: () {
      when(
        () => mockAcceptInviteUseCase(
          token: any(named: 'token'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Right(tUser));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const AcceptInviteState(
        email: tEmail,
        isValid: true,
        status: FormzSubmissionStatus.inProgress,
      ),
      const AcceptInviteState(
        email: tEmail,
        isValid: true,
        status: FormzSubmissionStatus.success,
      ),
    ],
    verify: (_) {
      verify(
        () => mockAcceptInviteUseCase(
          token: tToken,
          password: any(named: 'password'),
        ),
      ).called(1);
    },
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'submit con INVALID_OR_EXPIRED_TOKEN emite failure con el mensaje '
    'de token (la pantalla pasa a la vista de link inválido)',
    build: buildCubit,
    seed: () => const AcceptInviteState(email: tEmail, isValid: true),
    setUp: () {
      when(
        () => mockAcceptInviteUseCase(
          token: any(named: 'token'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(InvalidOrExpiredTokenFailure()));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const AcceptInviteState(
        email: tEmail,
        isValid: true,
        status: FormzSubmissionStatus.inProgress,
      ),
      AcceptInviteState(
        email: tEmail,
        isValid: true,
        status: FormzSubmissionStatus.failure,
        errorMessage: const InvalidOrExpiredTokenFailure().message,
      ),
    ],
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'submit con token vacío emite failure de token SIN llamar al '
    'use case (link roto — no viaja al backend)',
    build: () => buildCubit(token: ''),
    seed: () => const AcceptInviteState(email: tEmail, isValid: true),
    act: (cubit) => cubit.submit(),
    expect: () => [
      AcceptInviteState(
        email: tEmail,
        isValid: true,
        status: FormzSubmissionStatus.failure,
        errorMessage: const InvalidOrExpiredTokenFailure().message,
      ),
    ],
    verify: (_) => verifyZeroInteractions(mockAcceptInviteUseCase),
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'resend exitoso emite resendStatus [inProgress, success]',
    build: buildCubit,
    setUp: () {
      when(
        () => mockResendVerificationUseCase(tEmail),
      ).thenAnswer((_) async => const Right(null));
    },
    act: (cubit) => cubit.resend(),
    expect: () => [
      const AcceptInviteState(
        email: tEmail,
        resendStatus: FormzSubmissionStatus.inProgress,
      ),
      const AcceptInviteState(
        email: tEmail,
        resendStatus: FormzSubmissionStatus.success,
      ),
    ],
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'resend con falla emite resendStatus failure con errorMessage',
    build: buildCubit,
    setUp: () {
      when(
        () => mockResendVerificationUseCase(tEmail),
      ).thenAnswer((_) async => const Left(TooManyAttemptsFailure()));
    },
    act: (cubit) => cubit.resend(),
    expect: () => [
      const AcceptInviteState(
        email: tEmail,
        resendStatus: FormzSubmissionStatus.inProgress,
      ),
      AcceptInviteState(
        email: tEmail,
        resendStatus: FormzSubmissionStatus.failure,
        errorMessage: const TooManyAttemptsFailure().message,
      ),
    ],
  );

  blocTest<AcceptInviteCubit, AcceptInviteState>(
    'resend con email vacío no llama al use case',
    build: () => buildCubit(email: ''),
    act: (cubit) => cubit.resend(),
    expect: () => const <AcceptInviteState>[],
    verify: (_) => verifyZeroInteractions(mockResendVerificationUseCase),
  );
}
