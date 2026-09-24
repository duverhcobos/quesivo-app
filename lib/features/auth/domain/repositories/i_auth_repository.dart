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

  /// Crea una organización + cuenta admin — el usuario queda
  /// `pending_verification` (backend 069): NO hay sesión acá, la primera
  /// la emite `verifyEmail` cuando el link del correo se confirma.
  Future<Either<AuthFailure, void>> register({
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

  /// Verifica el correo con el `token` del deep link
  /// (`quesivo://verify-email?token=…`). Éxito = sesión guardada +
  /// User con token personal (auto-login — backend 069).
  Future<Either<AuthFailure, User>> verifyEmail({required String token});

  /// Reenvía el correo de verificación. Siempre 200 server-side —
  /// nunca revela si el email existe ni si ya está verificado.
  Future<Either<AuthFailure, void>> resendVerification(String email);

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
