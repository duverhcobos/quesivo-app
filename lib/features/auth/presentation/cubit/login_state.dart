import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/password.dart';

/// Estado dedicado exclusivamente a la pantalla de Login y su formulario.
///
/// SOLID (SRP): Separa el estado temporal del formulario visual
/// (errores tipográficos temporales), del estado global de sesión
/// de toda la aplicación (AuthCubit).
class LoginState extends Equatable {
  final Email email;
  final Password password;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final bool isValid; // Propiedad centralizada matemáticamente pura

  const LoginState({
    this.email = const Email.pure(),
    this.password = const Password.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isValid = false,
  });

  LoginState copyWith({
    Email? email,
    Password? password,
    FormzSubmissionStatus? status,
    String? errorMessage,
    bool? isValid,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      errorMessage: errorMessage, // Notice: No falla en nullable re-asignación
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props => [email, password, status, errorMessage, isValid];
}
