import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/use_cases/resend_verification_use_case.dart';
import 'check_email_state.dart';

/// Cubit de la pantalla "Revisá tu correo" — recibe el email por
/// parámetro de ruta y expone el reenvío (resend-verification).
class CheckEmailCubit extends Cubit<CheckEmailState> {
  final ResendVerificationUseCase _resendVerificationUseCase;

  CheckEmailCubit(this._resendVerificationUseCase, {required String email})
    : super(CheckEmailState(email: email));

  Future<void> resend() async {
    if (state.status.isInProgress) return;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _resendVerificationUseCase(state.email);

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
}
