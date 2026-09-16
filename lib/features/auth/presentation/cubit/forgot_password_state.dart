import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import '../../domain/value_objects/email.dart';

class ForgotPasswordState extends Equatable {
  final Email email;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final bool isValid;

  const ForgotPasswordState({
    this.email = const Email.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isValid = false,
  });

  ForgotPasswordState copyWith({
    Email? email,
    FormzSubmissionStatus? status,
    String? errorMessage,
    bool? isValid,
  }) {
    return ForgotPasswordState(
      email: email ?? this.email,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props => [email, status, errorMessage, isValid];
}
