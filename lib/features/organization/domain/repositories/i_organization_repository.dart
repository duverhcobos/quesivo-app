import 'package:dartz/dartz.dart';

import '../failures/organization_failure.dart';

/// Contrato del repositorio de Organization — operaciones sobre la org
/// del JWT org-scoped (módulo nuevo, propuesta 71 / backend 087).
///
/// SOLID (DIP): los casos de uso dependen de esta interfaz y NO de la
/// implementación concreta.
abstract class IOrganizationRepository {
  /// Renombra la org activa: PATCH + actualiza la sesión cacheada
  /// (organizationName + la entrada en `organizations` + limpia
  /// `isNewSignup`). Devuelve el nombre confirmado por el backend.
  Future<Either<OrganizationFailure, String>> updateCurrentName(String name);
}
