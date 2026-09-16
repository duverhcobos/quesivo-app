import 'package:formz/formz.dart';

enum RegisterPasswordValidationError { empty, weak }

/// Contraseña para creación de cuenta — política más estricta que el `Password`
/// de login: mínimo 8 caracteres con minúscula, mayúscula y dígito, espejo de
/// `RegisterDto` del backend (`src/modules/auth/application/dtos/register.dto.ts`).
///
/// Se mantiene como VO separado para no endurecer la validación del login
/// (un usuario con credenciales viejas debe poder intentar loguearse).
class RegisterPassword
    extends FormzInput<String, RegisterPasswordValidationError> {
  const RegisterPassword.pure() : super.pure('');
  const RegisterPassword.dirty([super.value = '']) : super.dirty();

  static final _hasLower = RegExp(r'[a-z]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasDigit = RegExp(r'\d');

  /// Predicados de la política — única fuente de verdad compartida por el
  /// validator y por el checklist visual de la pantalla.
  static bool hasMinLength(String v) => v.length >= 8;
  static bool hasLowercase(String v) => _hasLower.hasMatch(v);
  static bool hasUppercase(String v) => _hasUpper.hasMatch(v);
  static bool hasDigit(String v) => _hasDigit.hasMatch(v);

  @override
  RegisterPasswordValidationError? validator(String value) {
    if (value.isEmpty) return RegisterPasswordValidationError.empty;
    final strong =
        hasMinLength(value) &&
        hasLowercase(value) &&
        hasUppercase(value) &&
        hasDigit(value);
    return strong ? null : RegisterPasswordValidationError.weak;
  }
}
