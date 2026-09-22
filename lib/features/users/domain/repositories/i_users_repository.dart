import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../entities/users_page.dart';
import '../failures/users_failure.dart';

/// Repositorio del módulo Usuarios — administración de membresías de la
/// organización activa. La org la infiere el backend del JWT del admin:
/// nunca viaja en el body (IDOR, doc 007).
abstract class IUsersRepository {
  /// Una página del listado (doc 008): el backend pagina y filtra —
  /// `search` matchea nombre/email (LIKE case-insensitive), `role` el
  /// rol de la membresía. `meta.total` devuelve el total FILTRADO.
  /// Errores del contrato: `UsersForbiddenFailure` (403 no-admin),
  /// `UsersRateLimitFailure` (429), `UsersNetworkFailure` sin conexión.
  Future<Either<UsersFailure, UsersPage>> getUsers({
    required int page,
    required int limit,
    String? search,
    UserRole? role,
  });

  /// `POST /auth/users` — solo crea (propuesta backend 058): un email
  /// ya existente globalmente da `EmailAlreadyExistsFailure`; la
  /// vinculación de un user global vive en `linkUser`.
  Future<Either<UsersFailure, OrgMember>> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });

  /// `POST /auth/users/link` — vincula a la organización un usuario que
  /// ya tiene cuenta global (`{email, role}` → solo membresía; el 201
  /// trae `OrgMember.linked == true`). Errores del contrato:
  /// `UserNotFoundFailure` (404), `LinkedUserSuspendedFailure`/
  /// `MembershipAlreadyExistsFailure`/`UserIsOwnerFailure` (409),
  /// `UsersForbiddenFailure` (403), `UsersRateLimitFailure` (429).
  Future<Either<UsersFailure, OrgMember>> linkUser({
    required String email,
    required UserRole role,
  });

  /// `PATCH /auth/users/:id/status` — activa/suspende la membresía (doc
  /// 009). Errores del contrato: `SelfSuspensionFailure`,
  /// `OwnerSuspensionFailure`, `LastAdminFailure` (400),
  /// `MemberNotFoundFailure` (404), `UsersForbiddenFailure` (403),
  /// `UsersRateLimitFailure` (429), `UsersNetworkFailure` sin conexión.
  Future<Either<UsersFailure, OrgMember>> updateUserStatus({
    required String userId,
    required MemberStatus status,
  });

  /// `PATCH /auth/users/:id/password` — reset manual por admin (doc
  /// 010). Errores: `OwnerPasswordResetFailure`/`InvalidMemberDataFailure`
  /// (400), `MemberNotFoundFailure` (404), 403/429/red como arriba.
  Future<Either<UsersFailure, OrgMember>> updateUserPassword({
    required String userId,
    required String password,
  });

  /// `PATCH /auth/users/:id/role` — cambia el rol de la membresía (doc
  /// 012, propuesta backend 063). El backend revoca las sesiones del
  /// target en la org. Errores: `SelfRoleChangeFailure`/
  /// `OwnerRoleChangeFailure`/`LastAdminFailure` (400),
  /// `MemberNotFoundFailure` (404), 403/429/red como arriba.
  Future<Either<UsersFailure, OrgMember>> updateUserRole({
    required String userId,
    required UserRole role,
  });
}
