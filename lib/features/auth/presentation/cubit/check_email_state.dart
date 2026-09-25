import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

/// Estado de la pantalla "Revisa tu correo" — el `email` llega por
/// query param (register/login/deep link); `status` es del reenvío.
class CheckEmailState extends Equatable {
  final String email;
  final FormzSubmissionStatus status;
  final String? errorMessage;

  const CheckEmailState({
    required this.email,
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
  });

  CheckEmailState copyWith({
    FormzSubmissionStatus? status,
    String? errorMessage,
  }) {
    return CheckEmailState(
      email: email,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, status, errorMessage];
}
