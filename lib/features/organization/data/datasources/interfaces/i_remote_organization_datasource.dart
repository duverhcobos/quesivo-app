/// PATCH /organizations/me — backend 087, doc api/organizations/001.
abstract class IRemoteOrganizationDataSource {
  /// Renombra la org del JWT org-scoped. Devuelve el nombre confirmado.
  /// Lanza UnauthorizedException / RestApiException.
  Future<String> updateCurrentName(String name);
}
