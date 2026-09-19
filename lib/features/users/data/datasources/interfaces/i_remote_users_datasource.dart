import '../../../domain/entities/user_role.dart';
import '../../models/org_member_model.dart';

/// DataSource remoto del módulo Usuarios — habla con el API vía
/// `INetworkService` (con auth/refresh ya cableados en el Dio principal).
abstract class IRemoteUsersDataSource {
  /// `POST /auth/users` — lanza `RestApiException`/`UnauthorizedException`
  /// según el status; el repository los mapea a `UsersFailure`.
  Future<OrgMemberModel> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
}
