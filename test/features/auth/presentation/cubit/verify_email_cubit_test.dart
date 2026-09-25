import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';

import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/use_cases/resend_verification_use_case.dart';
import 'package:quesivo/features/auth/domain/use_cases/verify_email_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/verify_email_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/verify_email_state.dart';

class MockVerifyEmailUseCase extends Mock implements VerifyEmailUseCase {}

class MockResendVerificationUseCase extends Mock
    implements ResendVerificationUseCase {}

void main() {
  late MockVerifyEmailUseCase mockVerifyEmailUseCase;
  late MockResendVerificationUseCase mockResendVerificationUseCase;

  setUp(() {
    mockVerifyEmailUseCase = MockVerifyEmailUseCase();
    mockResendVerificationUseCase = MockResendVerificationUseCase();
  });

  const tToken = 'token-del-correo';
  const tEmail = 'test@test.com';
  const tUser = User(id: '1', email: tEmail, name: 'John Doe', token: 'token');

  VerifyEmailCubit buildCubit({String token = tToken, String email = tEmail}) =>
      VerifyEmailCubit(
        mockVerifyEmailUseCase,
        mockResendVerificationUseCase,
        token: token,
        email: email,
      );

  test('el estado inicial conserva el email del query param', () {
    expect(buildCubit().state, const VerifyEmailState(email: tEmail));
    expect(buildCubit().state.status, FormzSubmissionStatus.initial);
  });

  blocTest<VerifyEmailCubit, VerifyEmailState>(
    'token vacío => failure InvalidOrExpiredTokenFailure sin llamar '
    'al use case (link inválido, no error de red)',
    build: () => buildCubit(token: ''),
    act: (cubit) => cubit.verify(),
    expect: () => [
      VerifyEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.failure,
        errorMessage: const InvalidOrExpiredTokenFailure().message,
      ),
    ],
    verify: (_) {
      verifyZeroInteractions(mockVerifyEmailUseCase);
      verifyZeroInteractions(mockResendVerificationUseCase);
    },
  );

  blocTest<VerifyEmailCubit, VerifyEmailState>(
    'verify exitoso emite [inProgress, success]',
    build: buildCubit,
    setUp: () {
      when(
        () => mockVerifyEmailUseCase(token: tToken),
      ).thenAnswer((_) async => const Right(tUser));
    },
    act: (cubit) => cubit.verify(),
    expect: () => [
      const VerifyEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.inProgress,
      ),
      const VerifyEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.success,
      ),
    ],
    verify: (_) =>
        verify(() => mockVerifyEmailUseCase(token: tToken)).called(1),
  );

  blocTest<VerifyEmailCubit, VerifyEmailState>(
    'verify con falla emite [inProgress, failure] con errorMessage',
    build: buildCubit,
    setUp: () {
      when(
        () => mockVerifyEmailUseCase(token: tToken),
      ).thenAnswer((_) async => const Left(InvalidOrExpiredTokenFailure()));
    },
    act: (cubit) => cubit.verify(),
    expect: () => [
      const VerifyEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.inProgress,
      ),
      VerifyEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.failure,
        errorMessage: const InvalidOrExpiredTokenFailure().message,
      ),
    ],
  );

  blocTest<VerifyEmailCubit, VerifyEmailState>(
    'verify no corre dos veces si ya está en progreso',
    build: buildCubit,
    seed: () => const VerifyEmailState(
      email: tEmail,
      status: FormzSubmissionStatus.inProgress,
    ),
    act: (cubit) => cubit.verify(),
    expect: () => const <VerifyEmailState>[],
    verify: (_) => verifyZeroInteractions(mockVerifyEmailUseCase),
  );

  blocTest<VerifyEmailCubit, VerifyEmailState>(
    'resend exitoso emite resendStatus [inProgress, success]',
    build: buildCubit,
    setUp: () {
      when(
        () => mockResendVerificationUseCase(tEmail),
      ).thenAnswer((_) async => const Right(null));
    },
    act: (cubit) => cubit.resend(),
    expect: () => [
      const VerifyEmailState(
        email: tEmail,
        resendStatus: FormzSubmissionStatus.inProgress,
      ),
      const VerifyEmailState(
        email: tEmail,
        resendStatus: FormzSubmissionStatus.success,
      ),
    ],
  );

  blocTest<VerifyEmailCubit, VerifyEmailState>(
    'resend con falla emite resendStatus failure con errorMessage',
    build: buildCubit,
    setUp: () {
      when(
        () => mockResendVerificationUseCase(tEmail),
      ).thenAnswer((_) async => const Left(TooManyAttemptsFailure()));
    },
    act: (cubit) => cubit.resend(),
    expect: () => [
      const VerifyEmailState(
        email: tEmail,
        resendStatus: FormzSubmissionStatus.inProgress,
      ),
      VerifyEmailState(
        email: tEmail,
        resendStatus: FormzSubmissionStatus.failure,
        errorMessage: const TooManyAttemptsFailure().message,
      ),
    ],
  );

  blocTest<VerifyEmailCubit, VerifyEmailState>(
    'resend con email vacío no llama al use case',
    build: () => buildCubit(email: ''),
    act: (cubit) => cubit.resend(),
    expect: () => const <VerifyEmailState>[],
    verify: (_) => verifyZeroInteractions(mockResendVerificationUseCase),
  );
}
