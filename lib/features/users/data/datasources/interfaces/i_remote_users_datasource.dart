import '../../../domain/entities/org_member.dart';
import '../../../domain/entities/user_role.dart';
import '../../models/org_member_model.dart';
import '../../models/users_page_model.dart';

/// DataSource remoto del módulo Usuarios — habla con el API vía
/// `INetworkService` (con auth/refresh ya cableados en el Dio principal).
abstract class IRemoteUsersDataSource {
  /// `GET /users?page=&limit=&search=&role=` (doc 008 + backend
  /// 059). Lanza `RestApiException`/`UnauthorizedException` según el
  /// status; el repository los mapea a `UsersFailure`.
  Future<UsersPageModel> getUsers({
    required int page,
    required int limit,
    String? search,
    UserRole? role,
  });

  /// `POST /auth/users` — `password == null` → modo invitación (Email-C,
  /// backend 070): el user queda `pending_verification` y recibe el mail.
  /// Lanza `RestApiException`/`UnauthorizedException` según el status;
  /// el repository los mapea a `UsersFailure`.
  Future<OrgMemberModel> createUser({
    required String name,
    required String email,
    required String? password,
    required UserRole role,
  });

  /// `POST /auth/users/:id/resend-invite` — reenvía el mail al miembro
  /// pendiente (doc 018). 204 sin body; `INVITE_NOT_PENDING` si ya aceptó.
  Future<void> resendInvite({required String userId});

  /// `DELETE /auth/users/:id` real (doc 021) — 204 sin body.
  Future<void> removeMember({required String userId});

  /// `POST /auth/users/link` — vincula un user global existente a la org
  /// del JWT (propuesta backend 058).
  Future<OrgMemberModel> linkUser({
    required String email,
    required UserRole role,
  });

  /// `PATCH /users/:id/status` — flip de la membresía (doc 009).
  /// Devuelve el `OrgMemberModel` fresco (mismo shape que el listado).
  Future<OrgMemberModel> updateUserStatus({
    required String userId,
    required MemberStatus status,
  });

  /// `PATCH /auth/users/:id/password` — reset por admin (doc 010):
  /// revoca las sesiones del target en esta org y levanta el lockout.
  Future<OrgMemberModel> updateUserPassword({
    required String userId,
    required String password,
  });

  /// `PATCH /users/:id/role` — cambio de rol de la membresía (doc
  /// 012). Devuelve el `OrgMemberModel` fresco. El backend revoca las
  /// sesiones del target en la org (el JWT lleva `roles` adentro).
  Future<OrgMemberModel> updateUserRole({
    required String userId,
    required UserRole role,
  });
}
