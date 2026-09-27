import 'package:dartz/dartz.dart';

import '../failures/organization_failure.dart';
import '../repositories/i_organization_repository.dart';

/// PATCH /organizations/me (backend 087): renombra la quesera activa y
/// devuelve el nombre confirmado — el caller (`OrgNameSetupCubit`) avisa
/// al `AuthCubit` para que aplique el rename al `User` en memoria.
class UpdateOrganizationNameUseCase {
  final IOrganizationRepository repository;

  UpdateOrganizationNameUseCase(this.repository);

  Future<Either<OrganizationFailure, String>> call(String name) {
    return repository.updateCurrentName(name);
  }
}
