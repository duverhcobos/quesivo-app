// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:dartz/dartz.dart';

import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/interfaces/i_remote_auth_datasource.dart';
import '../datasources/interfaces/i_local_auth_datasource.dart';
import '../exceptions/auth_exceptions.dart';
import '../models/user_model.dart';

import '../../../../core/network/interfaces/i_network_info.dart';
import '../../../../core/logging/interfaces/i_logger_service.dart';

/// Implementación concreta del Repositorio de Domain.
///
/// SOLID (LSP): Esta clase puede sustituir a IAuthRepository en cualquier lugar.
class AuthRepositoryImpl implements IAuthRepository {
  final IRemoteAuthDataSource remoteDataSource;
  final ILocalAuthDataSource localDataSource;
  final INetworkInfo networkInfo;
  final ILoggerService logger;

  AuthRepositoryImpl(
    this.remoteDataSource,
    this.localDataSource,
    this.networkInfo,
    this.logger,
  );

  @override
  Future<Either<AuthFailure, User>> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // 1. Verificamos conexión a Internet antes de tocar la capa remota
    // SOLID (SRP/OCP): Se delega la infraestructura. Orquestación pura.
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final userModel = await remoteDataSource.loginWithEmailPassword(
        email: email,
        password: password,
      );

      // Guardar sesión tras éxito
      await localDataSource.saveUserSession(userModel);

      return Right(userModel);
    } on UnauthorizedException catch (e, stackTrace) {
      // No loguear el email del usuario (PII): cuando Crashlytics se conecte
      // en prod, estos warnings llegarían a un tercero con datos personales.
      logger.warning(
        'Intento de login con credenciales inválidas',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(InvalidCredentialsFailure());
    } on RestApiException catch (e, stackTrace) {
      // Contrato real (api/auth/002): 403 = cuenta suspendida O rol
      // no-ADMIN (propuesta 062 — se distinguen por errorCode: el de
      // suspendida viaja sin código), 429 = rate limit — ambos merecen
      // mensaje propio, no el crudo del body.
      if (e.statusCode == 403) {
        if (e.errorCode == 'ROLE_NOT_ALLOWED') {
          return const Left(RoleNotAllowedFailure());
        }
        return const Left(AccountSuspendedFailure());
      }
      if (e.statusCode == 429) {
        return const Left(TooManyAttemptsFailure());
      }
      logger.error(
        'Error de API al hacer login',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado durante el login',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, User>> loginWithGoogle() async {
    // Misma verificación de red que el resto de los métodos que llaman
    // a la capa remota (antes esta rama era inconsistente con el resto).
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final userModel = await remoteDataSource.loginWithGoogle();
      await localDataSource.saveUserSession(userModel);
      return Right(userModel);
    } catch (e, stackTrace) {
      logger.error('Error en Google Login', error: e, stackTrace: stackTrace);
      return Left(ServerFailure('No se pudo iniciar sesión con Google.'));
    }
  }

  @override
  Future<Either<AuthFailure, User>> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final userModel = await remoteDataSource.register(
        organizationName: organizationName,
        name: name,
        email: email,
        password: password,
      );
      // Auto-login: el registro exitoso guarda sesión igual que el login.
      await localDataSource.saveUserSession(userModel);
      return Right(userModel);
    } on RestApiException catch (e, stackTrace) {
      if (e.statusCode == 409) {
        return const Left(EmailAlreadyInUseFailure());
      }
      logger.error(
        'Error de API al registrar usuario',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado durante el registro',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, User>> checkAuthStatus() async {
    late final UserModel local;
    try {
      final session = await localDataSource.getUserSession();
      if (session == null) {
        return const Left(NoSessionFailure()); // No session found
      }
      local = session;
    } catch (e, stackTrace) {
      logger.warning(
        'Error leyendo sesión local de flutter_secure_storage',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error leyendo sesión local'));
    }

    // Hay sesión local: sin conectividad se degrada a ella (la app entra
    // igual; el próximo request autenticado ejercita refresh o expira).
    if (!await networkInfo.isConnected) {
      return Right(local);
    }

    // Validación remota: perfil fresco + status real de la cuenta
    // (documentacion/api/auth/005-get-me.md).
    try {
      final fresh = await remoteDataSource.getMe();

      // 'suspended' llega con 200: la cuenta murió del lado del servidor
      // aunque los tokens sigan vivos — sesión inválida igual.
      if (fresh.status == 'suspended') {
        // La cuenta murió del lado del servidor: reportar suspensión
        // aunque el borrado local falle (si lanza, igual hay que
        // desloguear — peor caso queda un cache huérfano que se limpia
        // en el próximo 401).
        try {
          await localDataSource.clearSession();
        } catch (_) {}
        return const Left(AccountSuspendedFailure());
      }

      // Merge: perfil fresco del servidor + tokens EN VIVO del storage.
      // CRÍTICO: re-leerlos DESPUÉS de getMe — si el access token venía
      // vencido, el RefreshTokenInterceptor ya rotó y persistió tokens
      // nuevos; usar local.token/local.refreshToken acá pisaría esos
      // valores con los revocados (y reusar un refresh token rotado hace
      // que el backend revoque TODAS las sesiones — ver doc 003).
      final liveToken = await localDataSource.getToken();
      final liveRefreshToken = await localDataSource.getRefreshToken();
      final merged = UserModel(
        id: fresh.id,
        email: fresh.email,
        name: fresh.name,
        token: liveToken,
        refreshToken: liveRefreshToken,
        organizationId: fresh.organizationId,
        organizationName: fresh.organizationName,
        roles: fresh.roles,
        status: fresh.status,
      );
      await localDataSource.saveUserSession(merged);
      return Right(merged);
    } on UnauthorizedException {
      // Puede ser sesión muerta de verdad (refresh 401 → interceptor
      // limpió storage + notificó) O un refresh transitorio fallido que
      // propagó el 401 original con la sesión intacta. Se distingue
      // re-leyendo el storage:
      final stillThere = await localDataSource.getUserSession();
      if (stillThere == null) {
        return const Left(NoSessionFailure());
      }
      return Right(local); // transitorio — conservar sesión
    } on RestApiException catch (e, stackTrace) {
      // 5xx, rate limit, etc.: transitorio — conservar sesión local.
      logger.warning(
        'GET /auth/me falló; se conserva la sesión cacheada',
        error: e,
        stackTrace: stackTrace,
      );
      return Right(local);
    } catch (e, stackTrace) {
      logger.warning(
        'Error inesperado validando sesión; se conserva la cacheada',
        error: e,
        stackTrace: stackTrace,
      );
      return Right(local);
    }
  }

  @override
  Future<Either<AuthFailure, void>> logout() async {
    // 1. Best-effort: revocar la sesión server-side ANTES de borrar el
    //    refresh token local. Cualquier fallo acá (offline, 5xx, 401 =
    //    "token ya muerto", storage ilegible) se loguea y se sigue —
    //    el usuario no debe quedar atrapado en la app por un error de red.
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken != null &&
          refreshToken.isNotEmpty &&
          await networkInfo.isConnected) {
        await remoteDataSource.logout(refreshToken);
      }
    } catch (e, stackTrace) {
      logger.warning(
        'Logout remoto falló; se cierra la sesión local igual',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 2. El cierre local es lo único obligatorio.
    try {
      await localDataSource.clearSession();
      return const Right(null);
    } catch (e, stackTrace) {
      logger.error(
        'Error al cerrar la sesión local',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(CacheFailure('No se pudo cerrar la sesión.'));
    }
  }

  @override
  Future<Either<AuthFailure, void>> forgotPassword(String email) async {
    // 1. Verificación universal de red para cualquier llamada API
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      await remoteDataSource.forgotPassword(email);
      return const Right(null);
    } catch (e, stackTrace) {
      logger.error(
        'Error al solicitar recuperación de contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(
        ServerFailure('No se pudo enviar el correo de recuperación'),
      );
    }
  }

  @override
  Future<Either<AuthFailure, void>> resetPassword({
    required String token,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      await remoteDataSource.resetPassword(token: token, password: password);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      logger.error(
        'Error de API al restablecer contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al restablecer contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }
}
