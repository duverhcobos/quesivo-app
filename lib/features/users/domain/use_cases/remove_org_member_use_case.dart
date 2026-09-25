import 'package:dartz/dartz.dart';

import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Caso de Uso: cancelar la invitación pendiente de un miembro
/// (`DELETE /auth/users/:id`, doc 021 — backend 072). Cubre la unión
/// `invitePending`: membresía `invited` (link) o artefacto
/// pending+passwordless (alta por correo). Sobre el artefacto también
/// cae la cuenta si era su única membresía.
class RemoveOrgMemberUseCase {
  final IUsersRepository repository;

  const RemoveOrgMemberUseCase(this.repository);

  Future<Either<UsersFailure, void>> call({required String userId}) {
    return repository.removeMember(userId: userId);
  }
}
