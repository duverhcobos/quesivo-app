import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Caso de Uso: activar/suspender la membresía de un miembro
/// (`PATCH /auth/users/:id/status`, doc 009 — propuesta backend 052).
/// Las reglas SELF_SUSPENSION/OWNER_SUSPENSION/LAST_ADMIN son del
/// backend — el dominio solo transporta; la UI ya no ofrece el ⋮ al
/// dueño ni a la card propia.
class UpdateUserStatusUseCase {
  final IUsersRepository repository;

  const UpdateUserStatusUseCase(this.repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String userId,
    required MemberStatus status,
  }) {
    return repository.updateUserStatus(userId: userId, status: status);
  }
}
