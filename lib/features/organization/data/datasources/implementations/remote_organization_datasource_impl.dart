import '../../../../../core/network/interfaces/i_network_service.dart';
import '../interfaces/i_remote_organization_datasource.dart';

/// `PATCH /organizations/me` real — backend 087, doc organizations/001:
/// la org objetivo sale SIEMPRE del JWT org-scoped (sin `:id` — IDOR
/// descartado por diseño) y el 200 trae `{id, name}` con el nombre
/// confirmado.
///
/// SOLID (DIP): depende del `INetworkService` central, no de Dio ni de
/// Http — mismo patrón que `RemoteUsersDataSourceImpl`.
class RemoteOrganizationDataSourceImpl
    implements IRemoteOrganizationDataSource {
  final INetworkService networkService;

  RemoteOrganizationDataSourceImpl(this.networkService);

  @override
  Future<String> updateCurrentName(String name) async {
    final data = await networkService.patch<Map<String, dynamic>>(
      '/organizations/me',
      data: {'name': name},
    );
    return data['name'] as String;
  }
}
