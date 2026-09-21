import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../failures/users_failure.dart';

/// Repositorio del módulo Usuarios — administración de membresías de la
/// organización activa. La org la infiere el backend del JWT del admin:
/// nunca viaja en el body (IDOR, doc 007).
abstract class IUsersRepository {
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
}
