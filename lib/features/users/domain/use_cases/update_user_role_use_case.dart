import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Passthrough a `PATCH /auth/users/:id/role` (doc 012, §54) — las
/// reglas de dominio (SELF/OWNER/LAST_ADMIN) son del backend; el
/// `UserRole` ya es enum válido, no hay VO que verificar acá (mismo
/// molde que `UpdateUserStatusUseCase`).
class UpdateUserRoleUseCase {
  final IUsersRepository _repository;

  UpdateUserRoleUseCase(this._repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String userId,
    required UserRole role,
  }) => _repository.updateUserRole(userId: userId, role: role);
}
