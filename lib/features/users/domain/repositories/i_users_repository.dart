import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../failures/users_failure.dart';

/// Repositorio del módulo Usuarios — administración de membresías de la
/// organización activa. La org la infiere el backend del JWT del admin:
/// nunca viaja en el body (IDOR, doc 007).
abstract class IUsersRepository {
  /// `POST /auth/users` — crea el usuario o lo vincula si el email ya
  /// existe globalmente (`OrgMember.linked` distingue ambos casos).
  Future<Either<UsersFailure, OrgMember>> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
}
