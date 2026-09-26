import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: rechazar la invitación a una organización (`POST
/// /me/org-invites/:orgId/decline`, doc 020 — backend 072). Borra
/// la membresía `invited` — el typo de email del admin se resuelve
/// desde el lado del invitado.
class DeclineOrgInviteUseCase {
  final IAuthRepository repository;

  const DeclineOrgInviteUseCase(this.repository);

  Future<Either<AuthFailure, void>> call(String organizationId) {
    return repository.declineOrgInvite(organizationId);
  }
}
