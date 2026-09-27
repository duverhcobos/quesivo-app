// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:dartz/dartz.dart';

import '../../domain/entities/organization_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/interfaces/i_google_auth_datasource.dart';
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
  final IGoogleAuthDataSource googleAuthDataSource;
  final ILocalAuthDataSource localDataSource;
  final INetworkInfo networkInfo;
  final ILoggerService logger;

  AuthRepositoryImpl(
    this.remoteDataSource,
    this.googleAuthDataSource,
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
        // Credenciales válidas pero correo sin verificar (backend 069)
        // — la pantalla de login navega a /check-email con este flag.
        if (e.errorCode == 'EMAIL_NOT_VERIFIED') {
          return const Left(EmailNotVerifiedFailure());
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
      return Left(_mapUnmappedError(e));
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
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      // 1. SDK de Google → idToken; null = el usuario canceló el picker.
      final idToken = await googleAuthDataSource.getIdToken();
      if (idToken == null) {
        return const Left(GoogleSignInCancelledFailure());
      }

      // 2. El backend verifica firma/aud/iss y emite sesión personal.
      final userModel = await remoteDataSource.loginWithGoogle(
        idToken: idToken,
      );
      await localDataSource.saveUserSession(userModel);
      return Right(userModel);
    } on RestApiException catch (e, stackTrace) {
      // Contrato api/auth/022: 401 con errorCode distingue token
      // inválido de email no verificado; 403 se distingue por errorCode
      // igual que login — ROLE_NOT_ALLOWED (membresía solo OPERATOR,
      // gate post-login compartido) vs cuenta suspendida; 429 = rate.
      if (e.statusCode == 403) {
        if (e.errorCode == 'ROLE_NOT_ALLOWED') {
          return const Left(RoleNotAllowedFailure());
        }
        return const Left(AccountSuspendedFailure());
      }
      if (e.statusCode == 429) {
        return const Left(TooManyAttemptsFailure());
      }
      if (e.errorCode == 'GOOGLE_EMAIL_UNVERIFIED') {
        return const Left(
          GoogleAuthFailure(
            'Tu cuenta de Google no tiene el correo verificado.',
          ),
        );
      }
      logger.error(
        'Error de API en Google Login',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(GoogleAuthFailure());
    } catch (e, stackTrace) {
      // Fallas del SDK (config de Google Cloud, plataforma sin soporte).
      logger.error('Error en Google Login', error: e, stackTrace: stackTrace);
      return const Left(GoogleAuthFailure());
    }
  }

  @override
  Future<Either<AuthFailure, void>> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      // Sin sesión acá (backend 069): la cuenta queda pendiente de
      // verificación — la pantalla navega a /check-email.
      await remoteDataSource.register(
        organizationName: organizationName,
        name: name,
        email: email,
        password: password,
      );
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      if (e.statusCode == 409) {
        return const Left(EmailAlreadyInUseFailure());
      }
      logger.error(
        'Error de API al registrar usuario',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
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
        organizations: fresh.organizations,
        // Backend 072: sin esto el merge tira las invitaciones que
        // /me sí devolvió — la sección OrgInvites jamás aparecería.
        pendingInvites: fresh.pendingInvites,
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
  Future<Either<AuthFailure, OrganizationSession>> selectOrganization(
    String organizationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final session = await remoteDataSource.selectOrganization(organizationId);
      // CRÍTICO: reemplaza el par completo — con token personal la
      // sesión quedó CONSUMIDA server-side; reusar su refresh token
      // dispara TOKEN_REUSE_DETECTED y revoca TODAS las sesiones
      // (doc 006). Con token org-scoped la sesión vieja sigue viva
      // pero este dispositivo solo conserva la nueva.
      await localDataSource.saveTokens(
        token: session.accessToken,
        refreshToken: session.refreshToken,
      );
      // El perfil cacheado debe reflejar la org del token NUEVO (auditoría
      // §63): si queda el orgId viejo, un restart offline degrada a un
      // User cuya org ya no es la que los tokens autorizan — y el
      // shortcut de "entrada gratis" (§57) entraría a la quesera
      // equivocada mostrando una pero pegándole a otra.
      final cached = await localDataSource.getUserSession();
      if (cached != null) {
        final role = cached.organizations
            .where((o) => o.id == session.organizationId)
            .map((o) => o.role);
        await localDataSource.saveUserSession(
          UserModel(
            id: cached.id,
            email: cached.email,
            name: cached.name,
            token: session.accessToken,
            refreshToken: session.refreshToken,
            organizationId: session.organizationId,
            organizationName: session.organizationName,
            roles: role.isEmpty ? cached.roles : [role.first],
            status: cached.status,
            organizations: cached.organizations,
            pendingInvites: cached.pendingInvites,
          ),
        );
      }
      return Right(session);
    } on UnauthorizedException catch (e, stackTrace) {
      // 401: membresía inexistente/suspendida o rol no-ADMIN — la
      // quesera ya no es accesible; la card reporta el error y el
      // próximo /auth/me natural la saca de la lista (§63).
      logger.warning(
        'select-organization rechazado',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(InvalidCredentialsFailure());
    } on RestApiException catch (e, stackTrace) {
      logger.error(
        'Error de API al seleccionar organización',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al seleccionar organización',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
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

      // Cerrar también la sesión de Google del dispositivo para que el
      // próximo sign-in muestre el picker de cuentas (propuesta 70).
      // Best-effort: un fallo del SDK no debe impedir el logout — la
      // sesión local ya murió.
      try {
        await googleAuthDataSource.signOut();
      } catch (e, stackTrace) {
        logger.warning(
          'Sign-out de Google falló; el logout local ya está hecho',
          error: e,
          stackTrace: stackTrace,
        );
      }

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
    } on RestApiException catch (e, stackTrace) {
      // El endpoint siempre responde 200 salvo un fallo real de
      // infraestructura (mail service caído) o rate limit — nunca por
      // "el email no existe" (anti-enumeración, backend propuesta 068).
      if (e.statusCode == 429) {
        logger.warning(
          'Rate limit alcanzado en forgot-password',
          error: e,
          stackTrace: stackTrace,
        );
        return const Left(TooManyAttemptsFailure());
      }
      logger.error(
        'Error de API al solicitar recuperación de contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al solicitar recuperación de contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
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
      // Contrato real (api/auth/014): 400 + errorCode distingue token
      // inválido/expirado de password débil — ambos merecen un mensaje
      // propio en vez del genérico de `_mapUnmappedError`.
      if (e.statusCode == 400) {
        if (e.errorCode == 'INVALID_OR_EXPIRED_TOKEN') {
          return const Left(InvalidOrExpiredTokenFailure());
        }
        if (e.errorCode == 'INVALID_PASSWORD') {
          return const Left(WeakPasswordFailure());
        }
      }
      logger.error(
        'Error de API al restablecer contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al restablecer contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, User>> verifyEmail({required String token}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      // Auto-login (backend 069): la sesión emitida se guarda igual que
      // en login — el listener de la pantalla llama refreshSession() y
      // el AuthGuard rutea a /home (token personal, selector de quesera).
      final userModel = await remoteDataSource.verifyEmail(token);
      await localDataSource.saveUserSession(userModel);
      return Right(userModel);
    } on RestApiException catch (e, stackTrace) {
      if (e.statusCode == 400 && e.errorCode == 'INVALID_OR_EXPIRED_TOKEN') {
        return const Left(InvalidOrExpiredTokenFailure());
      }
      logger.error(
        'Error de API al verificar correo',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al verificar correo',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, User>> acceptInvite({
    required String token,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      // Auto-login (backend 070 — doc 017): la sesión emitida se guarda
      // igual que en verifyEmail — el listener de la pantalla llama
      // refreshSession() y el AuthGuard rutea a /home.
      final userModel = await remoteDataSource.acceptInvite(
        token: token,
        password: password,
      );
      await localDataSource.saveUserSession(userModel);
      return Right(userModel);
    } on RestApiException catch (e, stackTrace) {
      // Contrato real (api/auth/017): 400 + errorCode distingue token
      // inválido/expirado de password débil — mismo mapeo que
      // resetPassword.
      if (e.statusCode == 400) {
        if (e.errorCode == 'INVALID_OR_EXPIRED_TOKEN') {
          return const Left(InvalidOrExpiredTokenFailure());
        }
        if (e.errorCode == 'INVALID_PASSWORD') {
          return const Left(WeakPasswordFailure());
        }
      }
      logger.error(
        'Error de API al aceptar invitación',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al aceptar invitación',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, void>> resendVerification(String email) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      await remoteDataSource.resendVerification(email);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      // Siempre 200 salvo fallo real de infra o rate limit (anti-
      // enumeración, backend 069 — mismo criterio que forgotPassword).
      if (e.statusCode == 429) {
        logger.warning(
          'Rate limit alcanzado en resend-verification',
          error: e,
          stackTrace: stackTrace,
        );
        return const Left(TooManyAttemptsFailure());
      }
      logger.error(
        'Error de API al reenviar verificación',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al reenviar verificación',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, void>> acceptOrgInvite(
    String organizationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.acceptOrgInvite(organizationId);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      // 404 ORG_INVITE_NOT_FOUND — la invitación ya no está pendiente
      // (la declinaste en otro device o el admin la canceló): dato
      // stale, la sección se refresca tras el toast.
      if (e.statusCode == 404) {
        return const Left(OrgInviteNotFoundFailure());
      }
      if (e.statusCode == 429) {
        return const Left(TooManyAttemptsFailure());
      }
      logger.error(
        'Error de API al aceptar invitación de organización',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al aceptar invitación de organización',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, void>> declineOrgInvite(
    String organizationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.declineOrgInvite(organizationId);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      if (e.statusCode == 404) {
        return const Left(OrgInviteNotFoundFailure());
      }
      if (e.statusCode == 429) {
        return const Left(TooManyAttemptsFailure());
      }
      logger.error(
        'Error de API al rechazar invitación de organización',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al rechazar invitación de organización',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  /// El mensaje crudo del backend nunca llega a la UI — es técnico y
  /// en inglés ('Internal server error'). `ServerException` = request
  /// sin respuesta (server caído, timeout, body ilegible) → "no se
  /// pudo conectar"; cualquier otro status no mapeado → genérico
  /// amigable. El detalle real queda en el logger.
  AuthFailure _mapUnmappedError(RestApiException e) =>
      e is ServerException ? const NetworkFailure() : const ServerFailure();
}
