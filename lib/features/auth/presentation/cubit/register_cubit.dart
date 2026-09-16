import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/use_cases/register_use_case.dart';
import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/full_name.dart';
import '../../domain/value_objects/organization_name.dart';
import '../../domain/value_objects/register_password.dart';
import 'register_state.dart';

/// Cubit del formulario de Registro (Presentation Logic local).
///
/// SOLID (SRP/ISP): no maneja sesión global — solo orquesta esta pantalla.
/// Cuando el password cambia, la confirmación se re-evalúa porque su regla
/// ("igual al password") depende del valor actualizado.
class RegisterCubit extends Cubit<RegisterState> {
  final RegisterUseCase _registerUseCase;

  RegisterCubit(this._registerUseCase) : super(const RegisterState());

  bool _validate({
    OrganizationName? organizationName,
    FullName? fullName,
    Email? email,
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
    bool? termsAccepted,
  }) {
    return Formz.validate([
          organizationName ?? state.organizationName,
          fullName ?? state.fullName,
          email ?? state.email,
          password ?? state.password,
          confirmPassword ?? state.confirmPassword,
        ]) &&
        (termsAccepted ?? state.termsAccepted);
  }

  void organizationNameChanged(String value) {
    final organizationName = OrganizationName.dirty(value);
    emit(
      state.copyWith(
        organizationName: organizationName,
        isValid: _validate(organizationName: organizationName),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  void fullNameChanged(String value) {
    final fullName = FullName.dirty(value);
    emit(
      state.copyWith(
        fullName: fullName,
        isValid: _validate(fullName: fullName),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  void emailChanged(String value) {
    final email = Email.dirty(value);
    emit(
      state.copyWith(
        email: email,
        isValid: _validate(email: email),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  void passwordChanged(String value) {
    final password = RegisterPassword.dirty(value);
    // La confirmación hereda el password nuevo: si ya fue tocada se
    // re-evalúa contra el valor actualizado; si está pura sigue pura.
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

  void termsToggled(bool accepted) {
    emit(
      state.copyWith(
        termsAccepted: accepted,
        isValid: _validate(termsAccepted: accepted),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  Future<void> submit() async {
    if (!state.isValid) return;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _registerUseCase(
      organizationName: state.organizationName.value,
      name: state.fullName.value,
      email: state.email.value,
      password: state.password.value,
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
