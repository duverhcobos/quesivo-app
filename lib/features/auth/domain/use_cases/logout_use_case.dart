// lib/features/auth/domain/use_cases/logout_use_case.dart
import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: Cerrar Sesión.
/// SOLID (SRP): Su única labor es coordinar el logout.
class LogoutUseCase {
  final IAuthRepository repository;

  LogoutUseCase(this.repository);

  Future<Either<AuthFailure, void>> call() {
    return repository.logout();
  }
}
