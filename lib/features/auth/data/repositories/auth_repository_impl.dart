// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:dartz/dartz.dart';

import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/interfaces/i_remote_auth_datasource.dart';
import '../datasources/interfaces/i_local_auth_datasource.dart';
import '../exceptions/auth_exceptions.dart';

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
    try {
      final userModel = await localDataSource.getUserSession();
      if (userModel != null) {
        return Right(userModel);
      } else {
        return const Left(NoSessionFailure()); // No session found
      }
    } catch (e, stackTrace) {
      logger.warning(
        'Error leyendo sesión local de flutter_secure_storage',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure('Error leyendo sesión local'));
    }
  }

  @override
  Future<Either<AuthFailure, void>> logout() async {
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
