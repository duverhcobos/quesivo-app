// lib/features/auth/data/datasources/i_remote_auth_datasource.dart
import '../../models/user_model.dart';

/// Contrato para la fuente de datos remota.
///
/// SOLID (ISP - Interface Segregation Principle):
/// Solo contiene métodos relevantes para auth remoto. Si más adelante
/// introducimos un LocalAuthDataSource, tendrá su propia interfaz en lugar de
/// forzar métodos en una interfaz masiva.
abstract class IRemoteAuthDataSource {
  Future<UserModel> loginWithEmailPassword({
    required String email,
    required String password,
  });

  Future<UserModel> loginWithGoogle();

  /// Registra organización + usuario nuevo contra `POST /auth/register`.
  Future<UserModel> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  });

  /// Envía la solicitud de recuperación de contraseña al servidor
  Future<void> forgotPassword(String email);

  /// Envía la nueva contraseña + token a `POST /auth/reset-password`.
  Future<void> resetPassword({required String token, required String password});

  /// Perfil fresco del usuario autenticado desde `GET /auth/me`
  /// (`documentacion/api/auth/005-get-me.md`). Incluye `status` leído de
  /// BD. El Bearer lo inyecta AuthInterceptor; un 401 dispara el refresh
  /// automático del RefreshTokenInterceptor antes de llegar acá.
  Future<UserModel> getMe();
}
