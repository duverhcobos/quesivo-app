import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: aceptar la invitación a una organización (`POST
/// /auth/me/org-invites/:orgId/accept`, doc 019 — backend 072). La
/// membresía `invited` pasa a `active`; la UI actualiza el `User` en
/// el lugar (la org aparece como card "Entrar" sin `GET /me` extra).
class AcceptOrgInviteUseCase {
  final IAuthRepository repository;

  const AcceptOrgInviteUseCase(this.repository);

  Future<Either<AuthFailure, void>> call(String organizationId) {
    return repository.acceptOrgInvite(organizationId);
  }
}
