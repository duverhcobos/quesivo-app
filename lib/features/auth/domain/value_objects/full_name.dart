import 'package:formz/formz.dart';

enum FullNameValidationError { empty, tooShort, invalidFormat }

/// Objeto de Valor para el nombre completo del usuario.
///
/// SOLID (SRP): única fuente de verdad de "qué es un nombre válido" —
/// ni la UI ni el Cubit repiten esta regla.
class FullName extends FormzInput<String, FullNameValidationError> {
  /// Caracteres que el teclado puede ingresar — el widget arma el
  /// `FilteringTextInputFormatter` con esta regex (single source).
  static final allowedChars = RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'\- ]");

  static final _pattern = RegExp(
    r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]+(?:[ '\-][a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]+)*$",
  );

  const FullName.pure() : super.pure('');
  const FullName.dirty([super.value = '']) : super.dirty();

  @override
  FullNameValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return FullNameValidationError.empty;
    if (trimmed.length < 3) return FullNameValidationError.tooShort;
    return _pattern.hasMatch(trimmed)
        ? null
        : FullNameValidationError.invalidFormat;
  }
}
