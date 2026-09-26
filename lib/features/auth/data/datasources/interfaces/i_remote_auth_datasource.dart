// lib/features/auth/data/datasources/i_remote_auth_datasource.dart
import '../../models/organization_session_model.dart';
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
  /// Desde la propuesta backend 069 el 201 viene con body vacío: la
  /// cuenta nace `pending_verification` y la sesión la emite
  /// `verifyEmail` al confirmar el correo.
  Future<void> register({
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

  /// Revoca la sesión server-side en `POST /auth/logout`
  /// (`documentacion/api/auth/004-post-logout.md`). Endpoint público desde
  /// la propuesta backend 047: el refreshToken enviado ES la credencial a
  /// revocar. Un 401 significa "token ya muerto" — no dispara refresh
  /// (la ruta está exenta en RefreshTokenInterceptor).
  Future<void> logout(String refreshToken);

  /// Emite un par de tokens ligado a la membresía de otra quesera
  /// (`POST /auth/select-organization`, doc 006). Con token personal
  /// consume esa sesión; con token org-scoped la sesión anterior queda
  /// viva (multi-org legítimo). 401 = no sos miembro activo de esa org.
  Future<OrganizationSessionModel> selectOrganization(String organizationId);

  /// Verifica el correo con el `token` del deep link
  /// (`POST /auth/verify-email`, doc 015). Devuelve la sesión emitida —
  /// auto-login con token personal, mismo shape que login.
  Future<UserModel> verifyEmail(String token);

  /// Acepta la invitación por correo (`POST /auth/accept-invite`,
  /// doc 017 — Email-C, backend 070): el invitado define su contraseña
  /// y el backend emite la sesión de una — auto-login con token
  /// personal, mismo shape que verify-email/login.
  Future<UserModel> acceptInvite({
    required String token,
    required String password,
  });

  /// Reenvía el correo de verificación (`POST /auth/resend-verification`,
  /// doc 016). Siempre 200 — anti-enumeración.
  Future<void> resendVerification(String email);

  /// Acepta la invitación a una organización (`POST
  /// /me/org-invites/:orgId/accept`, doc 019 — backend 072): la
  /// membresía `invited` pasa a `active` y la org aparece en
  /// `organizations` del próximo `/me`. 404 = ya no está pendiente
  /// (la declinaste o el admin la canceló — dato stale).
  Future<void> acceptOrgInvite(String organizationId);

  /// Rechaza la invitación (`POST /me/org-invites/:orgId/decline`,
  /// doc 020 — backend 072): borra la membresía `invited` — el typo de
  /// email del admin se resuelve solo. 404 = idem accept.
  Future<void> declineOrgInvite(String organizationId);
}
