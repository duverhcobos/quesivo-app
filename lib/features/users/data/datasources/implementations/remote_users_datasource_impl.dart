import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../../domain/entities/org_member.dart';
import '../../../domain/entities/user_role.dart';
import '../../models/org_member_model.dart';
import '../../models/users_page_model.dart';
import '../interfaces/i_remote_users_datasource.dart';

/// `POST /auth/users` real — contrato doc 007. La organización NO viaja
/// en el body: la infiere el backend del JWT del admin (IDOR).
class RemoteUsersDataSourceImpl implements IRemoteUsersDataSource {
  final INetworkService networkService;

  RemoteUsersDataSourceImpl(this.networkService);

  /// `GET /users` real — contrato doc users/008 (backend 052+059):
  /// paginación + filtros server-side. Solo viajan los params presentes
  /// (`search`/`role` se omiten cuando no hay filtro activo); la org y
  /// el orden (`created_at ASC` + tiebreaker `id`) los fija el backend.
  @override
  Future<UsersPageModel> getUsers({
    required int page,
    required int limit,
    String? search,
    UserRole? role,
  }) async {
    final data = await networkService.get<Map<String, dynamic>>(
      '/users',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
        if (role != null) 'role': role.apiValue,
      },
    );
    return UsersPageModel.fromJson(data);
  }

  @override
  Future<OrgMemberModel> createUser({
    required String name,
    required String email,
    required String? password,
    required UserRole role,
  }) async {
    final data = await networkService.post<Map<String, dynamic>>(
      '/auth/users',
      data: {
        'name': name,
        'email': email,
        // Ausente = invite mode (Email-C, backend 070): el backend crea
        // el user pending_verification + manda el mail con el link
        // accept-invite.
        if (password != null) 'password': password,
        'role': role.apiValue,
      },
    );
    // Doc 007: el `status` del 201 es el del USER global — la membresía
    // nueva nace active (fromCreatedJson lo interpreta así).
    return OrgMemberModel.fromCreatedJson(data);
  }

  /// `POST /users/:id/resend-invite` real (doc users/018 — ruta nueva
  /// desde la 081) — 204 sin body.
  @override
  Future<void> resendInvite({required String userId}) async {
    await networkService.post<void>('/users/$userId/resend-invite');
  }

  /// `DELETE /users/:id` real (doc users/021 — backend 072, ruta nueva
  /// desde la 080): cancela la invitación pendiente; la org la infiere
  /// el backend del JWT.
  @override
  Future<void> removeMember({required String userId}) async {
    await networkService.delete<void>('/users/$userId');
  }

  /// `POST /users/link` real — contrato doc users/011 (ruta nueva desde
  /// la 082): solo membresía (`{email, role}`); el 201 trae el mismo
  /// shape que create (`linked:true` — su `status` también es el del
  /// user global, por eso parsea con `fromCreatedJson`). La org la
  /// infiere el backend del JWT.
  @override
  Future<OrgMemberModel> linkUser({
    required String email,
    required UserRole role,
  }) async {
    final data = await networkService.post<Map<String, dynamic>>(
      '/users/link',
      data: {'email': email, 'role': role.apiValue},
    );
    return OrgMemberModel.fromCreatedJson(data);
  }

  /// `PATCH /users/:id/status` real (doc users/009) — la org la infiere
  /// el backend del JWT; el 200 trae el ítem fresco para mergear.
  @override
  Future<OrgMemberModel> updateUserStatus({
    required String userId,
    required MemberStatus status,
  }) async {
    final data = await networkService.patch<Map<String, dynamic>>(
      '/users/$userId/status',
      data: {'status': status.apiValue},
    );
    return OrgMemberModel.fromJson(data);
  }

  /// `PATCH /users/:id/password` real (doc users/010) — el password es
  /// global pero la autorización es por membresía; revoca solo las
  /// sesiones del target en ESTA org.
  @override
  Future<OrgMemberModel> updateUserPassword({
    required String userId,
    required String password,
  }) async {
    final data = await networkService.patch<Map<String, dynamic>>(
      '/users/$userId/password',
      data: {'password': password},
    );
    return OrgMemberModel.fromJson(data);
  }

  /// `PATCH /users/:id/role` real (doc users/012) — mismo molde que
  /// `updateUserStatus`: la org la infiere el backend del JWT y el 200
  /// trae el ítem fresco para mergear.
  @override
  Future<OrgMemberModel> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    final data = await networkService.patch<Map<String, dynamic>>(
      '/users/$userId/role',
      data: {'role': role.apiValue},
    );
    return OrgMemberModel.fromJson(data);
  }
}
