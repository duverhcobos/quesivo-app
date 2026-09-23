import 'package:dartz/dartz.dart';

import '../entities/user_role.dart';
import '../entities/users_page.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Caso de Uso: una página del listado de miembros (`GET /auth/users`,
/// doc 008). Thin pass-through — el backend pagina y filtra
/// (`search`/`role` viajan en el query); no hay VO que re-validar ni
/// normalización local que adelantar (el backend hace trim del search).
class ListUsersUseCase {
  final IUsersRepository repository;

  const ListUsersUseCase(this.repository);

  Future<Either<UsersFailure, UsersPage>> call({
    required int page,
    required int limit,
    String? search,
    UserRole? role,
  }) =>
      repository.getUsers(page: page, limit: limit, search: search, role: role);
}
