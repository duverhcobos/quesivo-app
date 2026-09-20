import 'package:formz/formz.dart';

enum PasswordValidationError { tooShort, empty }

/// Objeto de Valor (Value Object) para la Contraseña.
///
/// SOLID (SRP): Solo esta clase define qué hace válida a una contraseña en el dominio.
class Password extends FormzInput<String, PasswordValidationError> {
  /// Charset permitido — solo lo que la política de creación produce
  /// (letras y dígitos); todas las contraseñas del sistema nacen
  /// alfanuméricas (register/temp/reset), así que el login bloquea
  /// símbolos y espacios a nivel tecla igual que el resto.
  static final allowedChars = RegExp(r'[a-zA-Z0-9]');

  const Password.pure() : super.pure('');
  const Password.dirty([super.value = '']) : super.dirty();

  @override
  PasswordValidationError? validator(String value) {
    if (value.isEmpty) return PasswordValidationError.empty;
    if (value.length < 6) return PasswordValidationError.tooShort;
    return null;
  }
}
