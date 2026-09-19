import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';
import '../value_objects/member_email.dart';
import '../value_objects/member_name.dart';
import '../value_objects/temp_password.dart';

/// Caso de Uso: crear o vincular un miembro de la organización
/// (`POST /auth/users`, doc 007). Re-valida con los VOs como única
/// fuente de verdad — la sheet ya valida, pero el dominio no confía en
/// la UI (mismo patrón que `LoginUseCase` con `Password.dirty`).
class CreateUserUseCase {
  final IUsersRepository repository;

  const CreateUserUseCase(this.repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) {
    final valid =
        MemberName.dirty(name).isValid &&
        MemberEmail.dirty(email).isValid &&
        TempPassword.dirty(password).isValid;
    if (!valid) {
      return Future.value(const Left(InvalidMemberDataFailure()));
    }

    // Normalización espejo del backend (trim + lowercase) — enviar ya
    // normalizado hace la UI consistente con lo que persiste la API.
    return repository.createUser(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      password: password,
      role: role,
    );
  }
}
