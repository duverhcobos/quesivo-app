import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/use_cases/login_use_case.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/password.dart';
import 'login_state.dart';

/// Cubit especializado en el formulario de Login (Presentation Logic local).
///
/// SOLID (SRP/ISP): No maneja estado global de app, solo orquesta la pantalla de forma aislada.
class LoginCubit extends Cubit<LoginState> {
  final LoginUseCase _loginUseCase;

  LoginCubit(this._loginUseCase) : super(const LoginState());

  void emailChanged(String value) {
    final email = Email.dirty(value);

    // Evalúa la pura validez de todo el formulario cuando cambia el correo
    emit(
      state.copyWith(
        email: email,
        isValid: Formz.validate([email, state.password]),
        status: FormzSubmissionStatus.initial,
        errorMessage: null, // Borramos errores viejos de sumisión
      ),
    );
  }

  void passwordChanged(String value) {
    final password = Password.dirty(value);
    emit(
      state.copyWith(
        password: password,
        isValid: Formz.validate([state.email, password]),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  Future<void> submit() async {
    // Si la pantalla desobedece e invoca submit, el estado lo detiene si es inválido
    if (!state.isValid) return;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _loginUseCase(
      email: state.email.value,
      password: state.password.value,
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: FormzSubmissionStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (userModel) {
        emit(state.copyWith(status: FormzSubmissionStatus.success));
      },
    );
  }
}
