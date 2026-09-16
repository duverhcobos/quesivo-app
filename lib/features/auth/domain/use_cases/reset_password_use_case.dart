import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';
import '../value_objects/confirm_password.dart';
import '../value_objects/register_password.dart';

/// Caso de Uso: restablecer la contraseña con un token del correo.
///
/// SOLID (SRP): orquesta solo el flujo de reset. Las reglas de validación
/// viven en los Value Objects (misma política que el alta — RegisterPassword).
class ResetPasswordUseCase {
  final IAuthRepository repository;

  const ResetPasswordUseCase(this.repository);

  Future<Either<AuthFailure, void>> call({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    final valid = Formz.validate([
      RegisterPassword.dirty(password),
      ConfirmPassword.dirty(password: password, value: confirmPassword),
    ]);
    if (!valid) {
      return const Left(
        ServerFailure('Los datos del formulario no son válidos.'),
      );
    }

    return repository.resetPassword(token: token, password: password);
  }
}
