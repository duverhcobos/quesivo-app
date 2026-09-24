import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: reenviar el correo de verificación — siempre 200
/// server-side (anti-enumeración, backend 069).
class ResendVerificationUseCase {
  final IAuthRepository repository;

  const ResendVerificationUseCase(this.repository);

  Future<Either<AuthFailure, void>> call(String email) {
    return repository.resendVerification(email);
  }
}
