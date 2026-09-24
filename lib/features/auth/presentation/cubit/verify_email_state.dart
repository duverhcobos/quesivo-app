import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

/// Estado de la pantalla verify-email: `status` = la verificación
/// (inProgress → success/failure); `resendStatus` = el reenvío desde
/// el estado de error. `email` viene del query param para reenviar sin
/// pedirlo de nuevo.
class VerifyEmailState extends Equatable {
  final String email;
  final FormzSubmissionStatus status;
  final FormzSubmissionStatus resendStatus;
  final String? errorMessage;

  const VerifyEmailState({
    required this.email,
    this.status = FormzSubmissionStatus.initial,
    this.resendStatus = FormzSubmissionStatus.initial,
    this.errorMessage,
  });

  VerifyEmailState copyWith({
    FormzSubmissionStatus? status,
    FormzSubmissionStatus? resendStatus,
    String? errorMessage,
  }) {
    return VerifyEmailState(
      email: email,
      status: status ?? this.status,
      resendStatus: resendStatus ?? this.resendStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, status, resendStatus, errorMessage];
}
