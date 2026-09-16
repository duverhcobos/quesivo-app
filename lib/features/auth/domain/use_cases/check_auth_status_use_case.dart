// lib/features/auth/domain/use_cases/check_auth_status_use_case.dart
import 'package:dartz/dartz.dart';
import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: Verificar Estado de Autenticación.
/// SOLID (SRP): Solo se encarga de revisar si hay sesión activa
class CheckAuthStatusUseCase {
  final IAuthRepository repository;

  CheckAuthStatusUseCase(this.repository);

  Future<Either<AuthFailure, User>> call() async {
    return await repository.checkAuthStatus();
  }
}
