import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: verificar el correo con el `token` del deep link.
/// Éxito = cuenta activa + sesión guardada (auto-login, backend 069).
class VerifyEmailUseCase {
  final IAuthRepository repository;

  const VerifyEmailUseCase(this.repository);

  Future<Either<AuthFailure, User>> call({required String token}) {
    return repository.verifyEmail(token: token);
  }
}
