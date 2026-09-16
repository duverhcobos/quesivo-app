import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/full_name.dart';
import '../../domain/value_objects/organization_name.dart';
import '../../domain/value_objects/register_password.dart';

/// Estado efímero del formulario de Registro (Presentation Logic local).
///
/// SOLID (SRP): separado del estado global de sesión (`AuthCubit`).
/// `isValid` es matemáticamente puro: todos los campos válidos + términos
/// aceptados.
class RegisterState extends Equatable {
  final OrganizationName organizationName;
  final FullName fullName;
  final Email email;
  final RegisterPassword password;
  final ConfirmPassword confirmPassword;
  final bool termsAccepted;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final bool isValid;

  const RegisterState({
    this.organizationName = const OrganizationName.pure(),
    this.fullName = const FullName.pure(),
    this.email = const Email.pure(),
    this.password = const RegisterPassword.pure(),
    this.confirmPassword = const ConfirmPassword.pure(),
    this.termsAccepted = false,
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isValid = false,
  });

  RegisterState copyWith({
    OrganizationName? organizationName,
    FullName? fullName,
    Email? email,
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
    bool? termsAccepted,
    FormzSubmissionStatus? status,
    String? errorMessage,
    bool? isValid,
  }) {
    return RegisterState(
      organizationName: organizationName ?? this.organizationName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props => [
    organizationName,
    fullName,
    email,
    password,
    confirmPassword,
    termsAccepted,
    status,
    errorMessage,
    isValid,
  ];
}
