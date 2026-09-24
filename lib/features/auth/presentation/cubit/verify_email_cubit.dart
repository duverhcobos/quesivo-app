import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/use_cases/resend_verification_use_case.dart';
import '../../domain/use_cases/verify_email_use_case.dart';
import 'verify_email_state.dart';

/// Cubit de verify-email: recibe `token` + `email` del deep link
/// (inyectados por `AppRouter` desde el query). `verify()` corre una
/// sola vez al entrar — la pantalla lo dispara en el create del
/// BlocProvider. Éxito → la sesión ya quedó guardada por el repo y el
/// listener llama `AuthCubit.refreshSession()`.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  final VerifyEmailUseCase _verifyEmailUseCase;
  final ResendVerificationUseCase _resendVerificationUseCase;
  final String _token;

  VerifyEmailCubit(
    this._verifyEmailUseCase,
    this._resendVerificationUseCase, {
    required String token,
    required String email,
  }) : _token = token,
       super(VerifyEmailState(email: email));

  Future<void> verify() async {
    if (state.status.isInProgress || state.status.isSuccess) return;

    // Deep link sin `?token=` — mismo criterio que ResetPasswordCubit:
    // es un link inválido, no un error de red.
    if (_token.isEmpty) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: const InvalidOrExpiredTokenFailure().message,
        ),
      );
      return;
    }

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _verifyEmailUseCase(token: _token);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: FormzSubmissionStatus.success)),
    );
  }

  Future<void> resend() async {
    if (state.resendStatus.isInProgress || state.email.isEmpty) return;

    emit(state.copyWith(resendStatus: FormzSubmissionStatus.inProgress));

    final result = await _resendVerificationUseCase(state.email);

    result.fold(
      (failure) => emit(
        state.copyWith(
          resendStatus: FormzSubmissionStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(
        state.copyWith(resendStatus: FormzSubmissionStatus.success),
      ),
    );
  }
}
