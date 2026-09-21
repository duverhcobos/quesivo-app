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

  /// `POST /auth/users/link` real — contrato doc 007 post-058: solo
  /// membresía (`{email, role}`); el 201 trae el mismo shape que create
  /// (`linked:true`). La org la infiere el backend del JWT del admin.
  @override
  Future<OrgMemberModel> linkUser({
    required String email,
    required UserRole role,
  }) async {
    final data = await networkService.post<Map<String, dynamic>>(
      '/auth/users/link',
      data: {'email': email, 'role': role.apiValue},
    );
    return OrgMemberModel.fromJson(data);
  }
}
