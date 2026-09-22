import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';
import '../value_objects/temp_password.dart';

/// Caso de Uso: reset manual de la contraseña de un miembro por el
/// admin (`PATCH /auth/users/:id/password`, doc 010 — propuesta backend
/// 053). Re-valida con el VO como única fuente de verdad — la sheet ya
/// valida, pero el dominio no confía en la UI (mismo patrón que
/// `CreateUserUseCase` con `TempPassword.dirty`).
class UpdateUserPasswordUseCase {
  final IUsersRepository repository;

  const UpdateUserPasswordUseCase(this.repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String userId,
    required String password,
  }) {
    if (TempPassword.dirty(password).isNotValid) {
      return Future.value(const Left(InvalidMemberDataFailure()));
    }
    return repository.updateUserPassword(userId: userId, password: password);
  }
}
