// lib/features/auth/domain/repositories/i_auth_repository.dart
import 'package:dartz/dartz.dart';
import '../entities/organization_session.dart';
import '../entities/user.dart';
import '../failures/auth_failure.dart';

/// Contrato del Repositorio de Autenticación.
///
/// SOLID (DIP): Los casos de uso (capa superior) dependerán de esta interfaz
/// y NO de la implementación concreta de la base de datos o API.
abstract class IAuthRepository {
  Future<Either<AuthFailure, User>> loginWithEmailPassword({
    required String email,
    required String password,
  });

  Future<Either<AuthFailure, User>> loginWithGoogle();

  /// Crea una organización + cuenta admin (nombre de quesera, nombre de
  /// usuario, email, contraseña) y devuelve el usuario con su sesión
  /// (access/refresh token) — el backend hace auto-login.
  Future<Either<AuthFailure, User>> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  });

  /// Solicita un restablecimiento de contraseña
  Future<Either<AuthFailure, void>> forgotPassword(String email);

  /// Restablece la contraseña con el token recibido por correo
  /// (deep link `/reset-password?token=…`).
  Future<Either<AuthFailure, void>> resetPassword({
    required String token,
    required String password,
  });

  /// Verifica si hay una sesión activa guardada localmente
  Future<Either<AuthFailure, User>> checkAuthStatus();

  /// Entra a otra quesera: pide el par de tokens org-scoped, lo
  /// persiste reemplazando el actual y devuelve la sesión emitida —
  /// con ella el caller reconstruye el User localmente (§63), sin un
  /// `GET /auth/me` extra.
  Future<Either<AuthFailure, OrganizationSession>> selectOrganization(
    String organizationId,
  );

  /// Limpia la sesión actual. Devuelve `Either` como el resto del contrato:
  /// una falla de almacenamiento local se reporta como `CacheFailure`,
  /// nunca como excepción cruda hacia la UI.
  Future<Either<AuthFailure, void>> logout();
}
