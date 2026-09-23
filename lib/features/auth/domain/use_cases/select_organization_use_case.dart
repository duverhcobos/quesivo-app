import 'package:dartz/dartz.dart';

import '../entities/organization_session.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Emite el par de tokens ligado a la membresía de la quesera tocada
/// (propuesta backend 064) y devuelve la sesión: el caller reconstruye
/// el `User` en el lugar (§63) — este flujo no llama `/auth/me`.
class SelectOrganizationUseCase {
  final IAuthRepository repository;

  SelectOrganizationUseCase(this.repository);

  Future<Either<AuthFailure, OrganizationSession>> call(String organizationId) {
    return repository.selectOrganization(organizationId);
  }
}
