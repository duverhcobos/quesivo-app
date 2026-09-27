import 'package:dartz/dartz.dart';

import '../../../../core/logging/interfaces/i_logger_service.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../../auth/data/datasources/interfaces/i_local_auth_datasource.dart';
import '../../../auth/data/exceptions/auth_exceptions.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/organization_summary.dart';
import '../../domain/failures/organization_failure.dart';
import '../../domain/repositories/i_organization_repository.dart';
import '../datasources/interfaces/i_remote_organization_datasource.dart';

/// Implementación del repositorio de Organization (propuesta 71).
///
/// SOLID (SRP): orquesta datasources y mapea excepciones de
/// infraestructura a `OrganizationFailure` — la UI nunca ve excepciones
/// crudas (mismo patrón que `UsersRepositoryImpl`).
class OrganizationRepositoryImpl implements IOrganizationRepository {
  final IRemoteOrganizationDataSource remoteDataSource;
  final ILocalAuthDataSource localAuthDataSource;
  final INetworkInfo networkInfo;
  final ILoggerService logger;

  OrganizationRepositoryImpl(
    this.remoteDataSource,
    this.localAuthDataSource,
    this.networkInfo,
    this.logger,
  );

  /// `PATCH /organizations/me` — doc organizations/001. Tras el 200 la
  /// sesión cacheada queda al día: `organizationName`, la entrada del
  /// selector en `organizations` y `isNewSignup: false` (el nombrado ya
  /// se completó — el AuthGuard no vuelve a forzar la pantalla).
  @override
  Future<Either<OrganizationFailure, String>> updateCurrentName(
    String name,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(OrganizationNetworkFailure());
    }

    try {
      final newName = await remoteDataSource.updateCurrentName(name.trim());
      await _updateCachedSession(newName: newName);
      return Right(newName);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado renombrando la organización',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(OrganizationUpdateFailure());
    }
  }

  /// "Por ahora no": mismo rebuild de la sesión cacheada pero sin PATCH
  /// ni cambio de nombre — solo `isNewSignup: false` (el flag no debe
  /// reaparecer tras un restart).
  @override
  Future<Either<OrganizationFailure, void>> skipNameSetup() async {
    try {
      await _updateCachedSession();
      return const Right(null);
    } catch (e, stackTrace) {
      logger.warning(
        'No se pudo limpiar isNewSignup de la sesión cacheada',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(OrganizationUpdateFailure());
    }
  }

  /// Reconstruye el `UserModel` cacheado campo a campo — el `copyWith`
  /// de `User` devuelve la entity base (no `UserModel`), mismo motivo
  /// por el que `AuthRepositoryImpl.selectOrganization` hace un rebuild
  /// explícito. `newName == null` = solo limpiar el flag (skip).
  Future<void> _updateCachedSession({String? newName}) async {
    final session = await localAuthDataSource.getUserSession();
    if (session == null) return;

    await localAuthDataSource.saveUserSession(
      UserModel(
        id: session.id,
        email: session.email,
        name: session.name,
        token: session.token,
        refreshToken: session.refreshToken,
        organizationId: session.organizationId,
        organizationName: newName ?? session.organizationName,
        roles: session.roles,
        status: session.status,
        organizations: [
          for (final o in session.organizations)
            newName != null && o.id == session.organizationId
                ? OrganizationSummary(id: o.id, name: newName, role: o.role)
                : o,
        ],
        pendingInvites: session.pendingInvites,
        isNewSignup: false,
      ),
    );
  }

  /// Un 401 que llega hasta acá ya pasó por el RefreshTokenInterceptor;
  /// 401/403 → sin permiso (defensivo — la pantalla solo la ve el admin).
  /// `ServerException` = request sin respuesta (server caído, timeout):
  /// se reporta como "no se pudo conectar", no el crudo en inglés.
  OrganizationFailure _mapError(RestApiException e, StackTrace stackTrace) {
    if (e is ServerException) return const OrganizationNetworkFailure();
    if (e.statusCode == 401 || e.statusCode == 403) {
      return const OrganizationForbiddenFailure();
    }
    logger.error(
      'Error de API renombrando la organización',
      error: e,
      stackTrace: stackTrace,
    );
    return const OrganizationUpdateFailure();
  }
}
