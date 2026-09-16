import 'package:flutter_test/flutter_test.dart';
import 'package:quesivo/features/auth/domain/value_objects/register_password.dart';

void main() {
  group('RegisterPassword', () {
    test('rechaza vacío con empty', () {
      const input = RegisterPassword.dirty('');
      expect(input.displayError, RegisterPasswordValidationError.empty);
    });

    test('rechaza password débil con weak', () {
      const input = RegisterPassword.dirty('queso');
      expect(input.displayError, RegisterPasswordValidationError.weak);
    });

    test('acepta password fuerte', () {
      const input = RegisterPassword.dirty('Queso123');
      expect(input.displayError, isNull);
      expect(input.isValid, isTrue);
    });

    test('predicados evalúan cada requisito por separado', () {
      expect(RegisterPassword.hasMinLength('Queso123'), isTrue);
      expect(RegisterPassword.hasMinLength('Que1'), isFalse);
      expect(RegisterPassword.hasUppercase('Queso123'), isTrue);
      expect(RegisterPassword.hasUppercase('queso123'), isFalse);
      expect(RegisterPassword.hasLowercase('Queso123'), isTrue);
      expect(RegisterPassword.hasLowercase('QUESO123'), isFalse);
      expect(RegisterPassword.hasDigit('Queso123'), isTrue);
      expect(RegisterPassword.hasDigit('Quesosito'), isFalse);
    });
  });
}
