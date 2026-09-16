import 'package:formz/formz.dart';

enum PasswordValidationError { tooShort, empty }

/// Objeto de Valor (Value Object) para la Contraseña.
///
/// SOLID (SRP): Solo esta clase define qué hace válida a una contraseña en el dominio.
class Password extends FormzInput<String, PasswordValidationError> {
  const Password.pure() : super.pure('');
  const Password.dirty([super.value = '']) : super.dirty();

  @override
  PasswordValidationError? validator(String value) {
    if (value.isEmpty) return PasswordValidationError.empty;
    if (value.length < 6) return PasswordValidationError.tooShort;
    return null;
  }
}
