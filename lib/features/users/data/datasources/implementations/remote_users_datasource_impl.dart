import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../../domain/entities/user_role.dart';
import '../../models/org_member_model.dart';
import '../interfaces/i_remote_users_datasource.dart';

/// `POST /auth/users` real — contrato doc 007. La organización NO viaja
/// en el body: la infiere el backend del JWT del admin (IDOR).
class RemoteUsersDataSourceImpl implements IRemoteUsersDataSource {
  final INetworkService networkService;

  RemoteUsersDataSourceImpl(this.networkService);

  @override
  Future<OrgMemberModel> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final data = await networkService.post<Map<String, dynamic>>(
      '/auth/users',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role.apiValue,
      },
    );
    return OrgMemberModel.fromJson(data);
  }
}
