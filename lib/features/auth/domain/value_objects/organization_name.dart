import 'package:formz/formz.dart';

enum OrganizationNameValidationError { empty, tooShort }

/// Objeto de Valor para el nombre de la organización/quesera (tenant).
///
/// Es la entidad principal del registro: el backend crea la `organizacion`
/// con este nombre en la misma transacción que el usuario administrador
/// (planeaciones/001 §3.1). VO separado de `FullName` porque son reglas de
/// negocio distintas que pueden divergir (longitudes, caracteres, etc.).
class OrganizationName
    extends FormzInput<String, OrganizationNameValidationError> {
  /// Charset permitido — la razón social admite dígitos y signos de
  /// puntuación comunes además de letras; el validator no cambia.
  static final allowedChars = RegExp(r"[a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ '&.,\-]");

  const OrganizationName.pure() : super.pure('');
  const OrganizationName.dirty([super.value = '']) : super.dirty();

  @override
  OrganizationNameValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return OrganizationNameValidationError.empty;
    if (trimmed.length < 3) return OrganizationNameValidationError.tooShort;
    return null;
  }
}
