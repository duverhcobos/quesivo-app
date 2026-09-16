// lib/features/auth/domain/use_cases/register_use_case.dart
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';
import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';
import '../value_objects/email.dart';
import '../value_objects/full_name.dart';
import '../value_objects/organization_name.dart';
import '../value_objects/register_password.dart';

/// Caso de Uso: crear una cuenta nueva con nombre, email y contraseña.
///
/// SOLID (SRP): orquesta solo el flujo de registro. Las reglas de validación
/// viven en los Value Objects (única fuente de verdad); acá solo se verifica
/// que el input cumple el dominio antes de tocar la red.
class RegisterUseCase {
  final IAuthRepository repository;

  const RegisterUseCase(this.repository);

  Future<Either<AuthFailure, User>> call({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    final valid = Formz.validate([
      OrganizationName.dirty(organizationName),
      FullName.dirty(name),
      Email.dirty(email),
      RegisterPassword.dirty(password),
    ]);
    if (!valid) {
      return const Left(
        ServerFailure('Los datos del registro no son válidos.'),
      );
    }

    return repository.register(
      organizationName: organizationName.trim(),
      name: name.trim(),
      email: email,
      password: password,
    );
  }
}
