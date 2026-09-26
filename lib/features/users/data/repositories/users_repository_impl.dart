import 'package:dartz/dartz.dart';

import '../../../../core/logging/interfaces/i_logger_service.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../../auth/data/exceptions/auth_exceptions.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/entities/users_page.dart';
import '../../domain/failures/users_failure.dart';
import '../../domain/repositories/i_users_repository.dart';
import '../datasources/interfaces/i_remote_users_datasource.dart';

/// Implementación del repositorio de Usuarios.
///
/// SOLID (SRP): orquesta datasources y mapea excepciones de
/// infraestructura a `UsersFailure` — la UI nunca ve excepciones crudas
/// (mismo patrón que `AuthRepositoryImpl`).
class UsersRepositoryImpl implements IUsersRepository {
  final IRemoteUsersDataSource remoteDataSource;
  final INetworkInfo networkInfo;
  final ILoggerService logger;

  UsersRepositoryImpl(this.remoteDataSource, this.networkInfo, this.logger);

  /// `GET /users` — listado paginado real (doc 008, backend
  /// 052+059). Mismo try/catch + `_mapError` que `createUser`/`linkUser`;
  /// un 401 (JWT sin org) cae al default genérico — la sesión ya se está
  /// cerrando vía SessionExpiredNotifier.
  @override
  Future<Either<UsersFailure, UsersPage>> getUsers({
    required int page,
    required int limit,
    String? search,
    UserRole? role,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }

    try {
      final usersPage = await remoteDataSource.getUsers(
        page: page,
        limit: limit,
        search: search,
        role: role,
      );
      return Right(usersPage);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado listando usuarios',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// `POST /users` — `password == null` → modo invitación (Email-C,
  /// backend 070): el body viaja sin password y el backend le manda al
  /// invitado el correo con el link accept-invite.
  @override
  Future<Either<UsersFailure, OrgMember>> createUser({
    required String name,
    required String email,
    required String? password,
    required UserRole role,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }

    try {
      final member = await remoteDataSource.createUser(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      return Right(member);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado creando usuario',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// `POST /users/link` — vincula un user global existente (solo
  /// membresía; propuesta backend 058). Mismo try/catch de `createUser`.
  @override
  Future<Either<UsersFailure, OrgMember>> linkUser({
    required String email,
    required UserRole role,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }

    try {
      final member = await remoteDataSource.linkUser(email: email, role: role);
      return Right(member);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado vinculando usuario',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// `PATCH /users/:id/status` — doc 009. Mismo try/catch +
  /// `_mapError` de `createUser`/`linkUser`.
  @override
  Future<Either<UsersFailure, OrgMember>> updateUserStatus({
    required String userId,
    required MemberStatus status,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }
    try {
      final member = await remoteDataSource.updateUserStatus(
        userId: userId,
        status: status,
      );
      return Right(member);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado cambiando estado de membresía',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// `PATCH /users/:id/password` — doc 010. Ídem.
  @override
  Future<Either<UsersFailure, OrgMember>> updateUserPassword({
    required String userId,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }
    try {
      final member = await remoteDataSource.updateUserPassword(
        userId: userId,
        password: password,
      );
      return Right(member);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado restableciendo contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// `PATCH /users/:id/role` — doc 012. Ídem `updateUserStatus`.
  @override
  Future<Either<UsersFailure, OrgMember>> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }
    try {
      final member = await remoteDataSource.updateUserRole(
        userId: userId,
        role: role,
      );
      return Right(member);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado cambiando rol de membresía',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// `POST /users/:id/resend-invite` — doc 018 (Email-C, §68):
  /// reenvía el mail de invitación al miembro pendiente. 204 sin body;
  /// `INVITE_NOT_PENDING` (400) si ya aceptó — el ⋮ no lo ofrece, llega
  /// solo con data stale.
  @override
  Future<Either<UsersFailure, void>> resendInvite({
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }
    try {
      await remoteDataSource.resendInvite(userId: userId);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado reenviando invitación',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// `DELETE /users/:id` — doc 021 (backend 072): cancela la
  /// invitación pendiente (unión invitePending). 204 sin body;
  /// `MEMBERSHIP_NOT_INVITED` (409) si ya no está pendiente — llega
  /// solo con data stale.
  @override
  Future<Either<UsersFailure, void>> removeMember({
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }
    try {
      await remoteDataSource.removeMember(userId: userId);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado cancelando invitación',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// Un 401 que llega hasta acá ya pasó por el RefreshTokenInterceptor:
  /// si el refresh también falló, la sesión se está cerrando vía
  /// SessionExpiredNotifier — se reporta genérico, no hay acción de UI.
  ///
  /// Los `errorCode` de dominio distinguen errores que comparten status:
  /// el 409 cubre create (`EMAIL_ALREADY_EXISTS`) y link
  /// (`USER_IS_OWNER` + los ya mapeados); `USER_NOT_FOUND` llega con 404
  /// (link — el email no tiene cuenta global).
  UsersFailure _mapError(RestApiException e, StackTrace stackTrace) {
    // `ServerException` = request sin respuesta (server caído, timeout,
    // body ilegible): el crudo 'Internal server error' no debe llegar a
    // la UI — se reporta como "no se pudo conectar".
    if (e is ServerException) return const UsersNetworkFailure();
    switch (e.statusCode) {
      case 400:
        // Los PATCH de fila traen sus reglas de dominio como 400 +
        // errorCode (docs 009/010); INVALID_PASSWORD es la segunda
        // línea del VO — la sheet ya validó.
        final mapped = switch (e.errorCode) {
          'SELF_SUSPENSION' => const SelfSuspensionFailure(),
          'OWNER_SUSPENSION' => const OwnerSuspensionFailure(),
          'LAST_ADMIN' => const LastAdminFailure(),
          'OWNER_PASSWORD_RESET' => const OwnerPasswordResetFailure(),
          'INVALID_PASSWORD' => const InvalidMemberDataFailure(),
          'SELF_ROLE_CHANGE' => const SelfRoleChangeFailure(),
          'OWNER_ROLE_CHANGE' => const OwnerRoleChangeFailure(),
          // §68 — Email-C (doc 018): el reenvío solo aplica a invitados
          // pendientes; llega acá solo con data stale.
          'INVITE_NOT_PENDING' => const InviteNotPendingFailure(),
          _ => null,
        };
        if (mapped != null) return mapped;
        logger.error(
          'Error de API en gestión de usuarios',
          error: e,
          stackTrace: stackTrace,
        );
        return const UsersServerFailure();
      case 403:
        return const UsersForbiddenFailure();
      case 404:
        final mapped404 = switch (e.errorCode) {
          'USER_NOT_FOUND' => const UserNotFoundFailure(),
          'MEMBERSHIP_NOT_FOUND' => const MemberNotFoundFailure(),
          _ => null,
        };
        if (mapped404 != null) return mapped404;
        logger.error(
          'Error de API en gestión de usuarios',
          error: e,
          stackTrace: stackTrace,
        );
        return const UsersServerFailure();
      case 409:
        final mapped409 = switch (e.errorCode) {
          'MEMBERSHIP_ALREADY_EXISTS' => const MembershipAlreadyExistsFailure(),
          'USER_SUSPENDED' => const LinkedUserSuspendedFailure(),
          'EMAIL_ALREADY_EXISTS' => const EmailAlreadyExistsFailure(),
          'USER_IS_OWNER' => const UserIsOwnerFailure(),
          'MEMBERSHIP_NOT_INVITED' => const MemberNotInvitedFailure(),
          _ => null,
        };
        if (mapped409 != null) return mapped409;
        logger.error(
          'Error de API en gestión de usuarios',
          error: e,
          stackTrace: stackTrace,
        );
        return const UsersServerFailure();
      case 429:
        return const UsersRateLimitFailure();
      default:
        logger.error(
          'Error de API en gestión de usuarios',
          error: e,
          stackTrace: stackTrace,
        );
        return const UsersServerFailure();
    }
  }
}
