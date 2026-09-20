import 'package:formz/formz.dart';

enum MemberNameValidationError { empty, invalidFormat }

/// VO del nombre del miembro — letras (con tildes/ñ/ü), espacios,
/// apóstrofes y guiones; separadores simples internos. El backend pide
/// non-empty ≤255 (doc 007); el formato es regla de producto: el campo
/// es "nombre completo", no texto libre.
class MemberName extends FormzInput<String, MemberNameValidationError> {
  /// Caracteres que el teclado puede ingresar — el widget arma el
  /// `FilteringTextInputFormatter` con esta regex (single source).
  static final allowedChars = RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'\- ]");

  static final _pattern = RegExp(
    r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]+(?:[ '\-][a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]+)*$",
  );

  const MemberName.pure() : super.pure('');
  const MemberName.dirty([super.value = '']) : super.dirty();

  @override
  MemberNameValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return MemberNameValidationError.empty;
    return _pattern.hasMatch(trimmed)
        ? null
        : MemberNameValidationError.invalidFormat;
  }
}
