// lib/features/auth/domain/use_cases/login_use_case.dart
import 'package:dartz/dartz.dart';
import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';
import '../value_objects/password.dart';

/// Caso de Uso: Iniciar sesión con email y clave.
///
/// SOLID (SRP - Single Responsibility Principle):
/// Su única responsabilidad es orquestar el flujo de inicio de sesión
/// con correo y contraseña. Si las validaciones del negocio relacionadas a
/// solo este flujo cambian, únicamente esta clase cambiará.
class LoginUseCase {
  final IAuthRepository repository;

  // SOLID (DIP): Inyectamos la dependencia mediante la interfaz (IAuthRepository)
  const LoginUseCase(this.repository);

  /// Método de ejecución principal del caso de uso.
  Future<Either<AuthFailure, User>> call({
    required String email,
    required String password,
  }) async {
    // Reutilizamos el Value Object como única fuente de verdad de la regla
    // de negocio (evita duplicar el mínimo de caracteres en dos lugares).
    if (!Password.dirty(password).isValid) {
      return const Left(InvalidCredentialsFailure());
    }

    return repository.loginWithEmailPassword(email: email, password: password);
  }
}
