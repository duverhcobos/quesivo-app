import 'package:dartz/dartz.dart';

import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Caso de Uso: reenviar el correo de invitación a un miembro pendiente
/// (`POST /auth/users/:id/resend-invite`, doc 018 — Email-C 070). Solo
/// aplica cuando `invitePending` (user pendiente Y sin password —
/// derivado del backend 071); un activo o un pendiente CON password da
/// `InviteNotPendingFailure` (el ⋮ no lo ofrece — llega solo por data
/// stale).
class ResendInviteUseCase {
  final IUsersRepository repository;

  const ResendInviteUseCase(this.repository);

  Future<Either<UsersFailure, void>> call({required String userId}) {
    return repository.resendInvite(userId: userId);
  }
}
