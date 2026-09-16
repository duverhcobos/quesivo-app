import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/use_cases/reset_password_use_case.dart';
import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/register_password.dart';
import 'reset_password_state.dart';

/// Cubit del formulario de Restablecer Contraseña (Presentation Logic local).
///
/// Igual que `RegisterCubit`: cuando el password cambia, la confirmación se
/// re-evalúa porque su regla depende del valor actualizado. Recibe el `token`
/// del deep link al construirse (inyectado por `AppRouter` desde el query).
class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final ResetPasswordUseCase _resetPasswordUseCase;
  final String _token;

  ResetPasswordCubit(this._resetPasswordUseCase, {required String token})
    : _token = token,
      super(const ResetPasswordState());

  bool _validate({
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
  }) {
    return Formz.validate([
      password ?? state.password,
      confirmPassword ?? state.confirmPassword,
    ]);
  }

  void passwordChanged(String value) {
    final password = RegisterPassword.dirty(value);
    final confirmPassword = state.confirmPassword.isPure
        ? state.confirmPassword
        : ConfirmPassword.dirty(
            password: password.value,
            value: state.confirmPassword.value,
          );
    emit(
      state.copyWith(
        password: password,
        confirmPassword: confirmPassword,
        isValid: _validate(
          password: password,
          confirmPassword: confirmPassword,
        ),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
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
        isValid: _validate(confirmPassword: confirmPassword),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  Future<void> submit() async {
    if (!state.isValid) return;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _resetPasswordUseCase(
      token: _token,
      password: state.password.value,
      confirmPassword: state.confirmPassword.value,
    );

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
