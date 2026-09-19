import 'package:formz/formz.dart';

enum MemberEmailValidationError { empty, invalid }

/// VO del email del miembro — espejo deliberado del `Email` de auth:
/// importarlo acoplaría users→auth (misma razón por la que
/// `PasswordRequirementsChecklist` vive en core y no se comparte el VO).
/// El backend normaliza `trim` + `lowercase` (doc 007 §Notas).
class MemberEmail extends FormzInput<String, MemberEmailValidationError> {
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  const MemberEmail.pure() : super.pure('');
  const MemberEmail.dirty([super.value = '']) : super.dirty();

  @override
  MemberEmailValidationError? validator(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return MemberEmailValidationError.empty;
    if (!_emailRegex.hasMatch(normalized)) {
      return MemberEmailValidationError.invalid;
    }
    return null;
  }
}
