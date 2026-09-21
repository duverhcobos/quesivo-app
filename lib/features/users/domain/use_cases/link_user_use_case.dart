import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';
import '../value_objects/member_email.dart';

/// Caso de Uso: vincular a la organización un usuario que ya tiene
/// cuenta global (`POST /auth/users/link`, propuesta backend 058) —
/// espejo de `CreateUserUseCase` sin `MemberName`/`TempPassword` (no
/// aplican: el user ya existe, solo se crea la membresía). Re-valida
/// con el VO como única fuente de verdad — la sheet ya valida, pero el
/// dominio no confía en la UI (mismo patrón que `LoginUseCase` con
/// `Password.dirty`).
class LinkUserUseCase {
  final IUsersRepository repository;

  const LinkUserUseCase(this.repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String email,
    required UserRole role,
  }) {
    if (MemberEmail.dirty(email).isNotValid) {
      return Future.value(const Left(InvalidMemberDataFailure()));
    }

    // Normalización espejo del backend (trim + lowercase) — enviar ya
    // normalizado hace la UI consistente con lo que persiste la API.
    return repository.linkUser(email: email.trim().toLowerCase(), role: role);
  }
}
