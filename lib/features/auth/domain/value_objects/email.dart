import 'package:formz/formz.dart';

// Diferentes tipos de error que puede tener un correo
enum EmailValidationError { invalid, empty }

/// Objeto de Valor (Value Object) para el Correo Electrónico.
///
/// SOLID (SRP y OCP): Encapsula la validación matemática de un correo.
/// La UI y el Estado no necesitan saber de Expresiones Regulares.
class Email extends FormzInput<String, EmailValidationError> {
  // Constante estática para la RegEx
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  /// Charset de email — bloquea espacios y símbolos ajenos al formato.
  static final allowedChars = RegExp(r'[a-zA-Z0-9@._%+\-]');

  // Estado inicial "puro" (sin tocar)
  const Email.pure() : super.pure('');
  // Estado "sucio" (usuario modificó el campo)
  const Email.dirty([super.value = '']) : super.dirty();

  @override
  EmailValidationError? validator(String value) {
    if (value.trim().isEmpty) return EmailValidationError.empty;
    if (!_emailRegex.hasMatch(value)) return EmailValidationError.invalid;
    return null; // Nulo significa que es un correo válido
  }
}
