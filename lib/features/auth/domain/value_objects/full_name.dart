import 'package:formz/formz.dart';

enum FullNameValidationError { empty, tooShort }

/// Objeto de Valor para el nombre completo del usuario.
///
/// SOLID (SRP): única fuente de verdad de "qué es un nombre válido" —
/// ni la UI ni el Cubit repiten esta regla.
class FullName extends FormzInput<String, FullNameValidationError> {
  const FullName.pure() : super.pure('');
  const FullName.dirty([super.value = '']) : super.dirty();

  @override
  FullNameValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return FullNameValidationError.empty;
    if (trimmed.length < 3) return FullNameValidationError.tooShort;
    return null;
  }
}
