import 'package:formz/formz.dart';

enum TempPasswordValidationError { weak }

/// VO de la contraseña temporal que el admin define para el miembro —
/// misma política que `RegisterPassword` de auth y `RegisterDto` del
/// backend (doc 007: min 8 + minúscula + mayúscula + dígito).
///
/// Los predicados por regla alimentan el checklist vivo del sheet —
/// reemplazan los regexes espejo que la UI-phase dejó en el widget.
class TempPassword extends FormzInput<String, TempPasswordValidationError> {
  static final _hasLower = RegExp(r'[a-z]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasDigit = RegExp(r'\d');

  /// Charset permitido — solo lo que el requisito pide (letras y
  /// dígitos); símbolos y espacios se bloquean a nivel tecla.
  static final allowedChars = RegExp(r'[a-zA-Z0-9]');

  const TempPassword.pure() : super.pure('');
  const TempPassword.dirty([super.value = '']) : super.dirty();

  bool get hasMinLength => value.length >= 8;
  bool get hasLowercase => _hasLower.hasMatch(value);
  bool get hasUppercase => _hasUpper.hasMatch(value);
  bool get hasDigit => _hasDigit.hasMatch(value);

  @override
  TempPasswordValidationError? validator(String value) {
    final ok = hasMinLength && hasLowercase && hasUppercase && hasDigit;
    return ok ? null : TempPasswordValidationError.weak;
  }
}
