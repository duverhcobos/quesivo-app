import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';

import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/use_cases/resend_verification_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/check_email_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/check_email_state.dart';

class MockResendVerificationUseCase extends Mock
    implements ResendVerificationUseCase {}

void main() {
  late MockResendVerificationUseCase mockResendVerificationUseCase;

  setUp(() {
    mockResendVerificationUseCase = MockResendVerificationUseCase();
  });

  const tEmail = 'test@test.com';

  CheckEmailCubit buildCubit() =>
      CheckEmailCubit(mockResendVerificationUseCase, email: tEmail);

  test('el estado inicial conserva el email del query param', () {
    expect(buildCubit().state, const CheckEmailState(email: tEmail));
    expect(buildCubit().state.status, FormzSubmissionStatus.initial);
  });

  blocTest<CheckEmailCubit, CheckEmailState>(
    'resend exitoso emite [inProgress, success]',
    build: buildCubit,
    setUp: () {
      when(
        () => mockResendVerificationUseCase(tEmail),
      ).thenAnswer((_) async => const Right(null));
    },
    act: (cubit) => cubit.resend(),
    expect: () => [
      const CheckEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.inProgress,
      ),
      const CheckEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.success,
      ),
    ],
  );

  blocTest<CheckEmailCubit, CheckEmailState>(
    'resend con falla emite [inProgress, failure] con errorMessage',
    build: buildCubit,
    setUp: () {
      when(
        () => mockResendVerificationUseCase(tEmail),
      ).thenAnswer((_) async => const Left(TooManyAttemptsFailure()));
    },
    act: (cubit) => cubit.resend(),
    expect: () => [
      const CheckEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.inProgress,
      ),
      CheckEmailState(
        email: tEmail,
        status: FormzSubmissionStatus.failure,
        errorMessage: const TooManyAttemptsFailure().message,
      ),
    ],
  );

  blocTest<CheckEmailCubit, CheckEmailState>(
    'un segundo resend mientras hay uno en progreso no llama al use case',
    build: buildCubit,
    seed: () => const CheckEmailState(
      email: tEmail,
      status: FormzSubmissionStatus.inProgress,
    ),
    act: (cubit) => cubit.resend(),
    expect: () => const <CheckEmailState>[],
    verify: (_) => verifyZeroInteractions(mockResendVerificationUseCase),
  );
}
