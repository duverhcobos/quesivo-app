import 'package:dartz/dartz.dart';

import '../failures/organization_failure.dart';
import '../repositories/i_organization_repository.dart';

/// "Por ahora no" en la pantalla de nombrado (propuesta 71): limpia
/// `isNewSignup` de la sesión persistida sin llamar al backend — la org
/// conserva el nombre generado y la pantalla no reaparece tras restart.
class SkipOrgNameSetupUseCase {
  final IOrganizationRepository repository;

  SkipOrgNameSetupUseCase(this.repository);

  Future<Either<OrganizationFailure, void>> call() {
    return repository.skipNameSetup();
  }
}
