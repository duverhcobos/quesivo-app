// lib/features/auth/domain/use_cases/login_with_google_use_case.dart
import 'package:dartz/dartz.dart';
import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: Iniciar sesión con Google.
///
/// SOLID (SRP): Un caso de uso independiente para Google.
class LoginWithGoogleUseCase {
  final IAuthRepository repository;

  const LoginWithGoogleUseCase(this.repository);

  Future<Either<AuthFailure, User>> call() {
    return repository.loginWithGoogle();
  }
}
