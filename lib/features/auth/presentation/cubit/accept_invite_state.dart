import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/register_password.dart';

/// Estado inmutable de `/accept-invite` (propuesta 68 — Email-C):
/// formulario de definición de contraseña para el invitado — combina el
/// estado vivo de la pantalla de reset (Vos + isValid +
/// FormzSubmissionStatus) con `email`/`resendStatus` de verify-email:
/// el email viaja en el query param del link (solo display + resend).
///
/// `resendStatus` es el canal del botón "Pedir link nuevo" de la vista
/// de link inválido: `initial` → botón, `inProgress` → loader,
/// `success` → ForgotPasswordInfoCard de confirmación.
class AcceptInviteState extends Equatable {
  final RegisterPassword password;
  final ConfirmPassword confirmPassword;
  final bool isValid;
  final FormzSubmissionStatus status;

  /// Feedback del submit o del reenvío — `null` = sin error. La
  /// pantalla mapea los failures a l10n SOLO para el error de
  /// contraseña; el mensaje de link inválido viene del state
  /// (verify-email hace lo mismo).
  final String? errorMessage;

  /// Email del invitado — llega como query param del link; solo para
  /// mostrar ("…para ana@mail.com") y para el reenvío del link.
  final String email;

  /// Ciclo del reenvío del link — separado de `status` para no pisar
  /// el estado del form.
  final FormzSubmissionStatus resendStatus;

  const AcceptInviteState({
    this.password = const RegisterPassword.pure(),
    this.confirmPassword = const ConfirmPassword.pure(),
    this.isValid = false,
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    required this.email,
    this.resendStatus = FormzSubmissionStatus.initial,
  });

  AcceptInviteState copyWith({
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
    bool? isValid,
    FormzSubmissionStatus? status,
    String? errorMessage,
    String? email,
    FormzSubmissionStatus? resendStatus,
  }) {
    return AcceptInviteState(
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isValid: isValid ?? this.isValid,
      status: status ?? this.status,
      errorMessage: errorMessage,
      email: email ?? this.email,
      resendStatus: resendStatus ?? this.resendStatus,
    );
  }

  @override
  List<Object?> get props => [
    password,
    confirmPassword,
    isValid,
    status,
    errorMessage,
    email,
    resendStatus,
  ];
}
