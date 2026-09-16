import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/register_password.dart';

/// Estado efímero del formulario de Restablecer Contraseña
/// (Presentation Logic local).
class ResetPasswordState extends Equatable {
  final RegisterPassword password;
  final ConfirmPassword confirmPassword;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final bool isValid;

  const ResetPasswordState({
    this.password = const RegisterPassword.pure(),
    this.confirmPassword = const ConfirmPassword.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isValid = false,
  });

  ResetPasswordState copyWith({
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
    FormzSubmissionStatus? status,
    String? errorMessage,
    bool? isValid,
  }) {
    return ResetPasswordState(
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props => [
    password,
    confirmPassword,
    status,
    errorMessage,
    isValid,
  ];
}
