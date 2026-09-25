import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/use_cases/accept_invite_use_case.dart';
import '../../domain/use_cases/resend_verification_use_case.dart';
import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/register_password.dart';
import 'accept_invite_state.dart';

/// Cubit de `/accept-invite` (propuesta 68 — Email-C): el link del
/// correo trae `token`+`email`; el invitado define su contraseña, el
/// POST hace login automático (mismo shape que verify-email) y la
/// pantalla dispara `AuthCubit.refreshSession()` → AuthGuard a /home.
///
/// Token: llega por constructor (locator con param1 — misma DI de
/// verify-email), igual que `VerifyEmailCubit`.
///
/// Validación: mismas reglas que `ResetPasswordCubit` — formz con
/// `RegisterPassword` + `ConfirmPassword`, el confirm se re-evalúa al
/// cambiar el password.
class AcceptInviteCubit extends Cubit<AcceptInviteState> {
  final AcceptInviteUseCase _acceptInvite;
  final ResendVerificationUseCase _resendVerification;
  final String _token;

  AcceptInviteCubit(
    this._acceptInvite,
    this._resendVerification, {
    required String token,
    required String email,
  }) : _token = token,
       super(AcceptInviteState(email: email));

  /// `false` cuando el deep link llegó sin `?token=` — la pantalla
  /// muestra la vista de link inválido directo, sin esperar un submit.
  bool get hasToken => _token.isNotEmpty;

  void passwordChanged(String value) {
    final password = RegisterPassword.dirty(value);
    emit(
      state.copyWith(
        password: password,
        confirmPassword: ConfirmPassword.dirty(
          password: password.value,
          value: state.confirmPassword.value,
        ),
        status: FormzSubmissionStatus.initial,
        isValid: _validate(
          password,
          ConfirmPassword.dirty(
            password: password.value,
            value: state.confirmPassword.value,
          ),
        ),
      ),
    );
  }

  void confirmPasswordChanged(String value) {
    final confirmPassword = ConfirmPassword.dirty(
      password: state.password.value,
      value: value,
    );
    emit(
      state.copyWith(
        confirmPassword: confirmPassword,
        status: FormzSubmissionStatus.initial,
        isValid: _validate(state.password, confirmPassword),
      ),
    );
  }

  bool _validate(RegisterPassword password, ConfirmPassword confirm) =>
      Formz.validate([password, confirm]);

  Future<void> submit() async {
    if (!state.isValid || state.status.isInProgress) return;
    // Link roto sin token: ni siquiera viaja al backend.
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
    final result = await _acceptInvite(
      token: _token,
      password: state.password.value,
    );
    if (isClosed) return;
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

  /// "Pedir enlace nuevo" desde la vista de link inválido — reusa
  /// `resend-verification` del backend (para `pending_verification`
  /// el 204 reenvía el MISMO correo de invitación — doc 017).
  Future<void> resend() async {
    if (state.email.isEmpty || state.resendStatus.isInProgress) return;
    emit(state.copyWith(resendStatus: FormzSubmissionStatus.inProgress));
    final result = await _resendVerification(state.email);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          resendStatus: FormzSubmissionStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(resendStatus: FormzSubmissionStatus.success)),
    );
  }
}
