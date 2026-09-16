import 'package:formz/formz.dart';

enum ConfirmPasswordValidationError { empty, mismatch }

/// Confirmación de contraseña — válida solo si es igual a la contraseña
/// original (recibida por constructor, porque Formz no compara campos).
class ConfirmPassword
    extends FormzInput<String, ConfirmPasswordValidationError> {
  final String password;

  const ConfirmPassword.pure({this.password = ''}) : super.pure('');
  const ConfirmPassword.dirty({required this.password, String value = ''})
    : super.dirty(value);

  @override
  ConfirmPasswordValidationError? validator(String value) {
    if (value.isEmpty) return ConfirmPasswordValidationError.empty;
    if (value != password) return ConfirmPasswordValidationError.mismatch;
    return null;
  }
}
