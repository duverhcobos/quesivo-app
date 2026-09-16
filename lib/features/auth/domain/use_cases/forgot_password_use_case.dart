import 'package:dartz/dartz.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso para Recuperar Contraseña.
///
/// SOLID (SRP): Solo se encarga de orquestar la petición de recuperación.
class ForgotPasswordUseCase {
  final IAuthRepository repository;

  ForgotPasswordUseCase(this.repository);

  Future<Either<AuthFailure, void>> call(String email) async {
    return repository.forgotPassword(email);
  }
}
