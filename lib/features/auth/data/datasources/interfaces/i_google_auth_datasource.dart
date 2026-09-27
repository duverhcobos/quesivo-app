/// Abstracción del SDK de Google Sign-In (DIP: el repository no conoce
/// el paquete `google_sign_in`; los tests lo mockean).
abstract class IGoogleAuthDataSource {
  /// Lanza el picker de cuentas y devuelve el **idToken** (JWT firmado
  /// por Google, audience = GOOGLE_SERVER_CLIENT_ID). Devuelve `null`
  /// si el usuario cancela — no es un error, es navegación hacia atrás.
  Future<String?> getIdToken();

  /// Cierra la sesión de Google del dispositivo (llamado desde logout)
  /// para que el próximo sign-in muestre el picker de cuentas.
  Future<void> signOut();
}
