import 'package:formz/formz.dart';

enum MemberNameValidationError { empty }

/// VO del nombre del miembro a crear — el backend pide `MaxLength(255)`
/// (doc 007); el único rechazo útil en UI es el vacío tras trim.
class MemberName extends FormzInput<String, MemberNameValidationError> {
  const MemberName.pure() : super.pure('');
  const MemberName.dirty([super.value = '']) : super.dirty();

  @override
  MemberNameValidationError? validator(String value) {
    return value.trim().isEmpty ? MemberNameValidationError.empty : null;
  }
}
