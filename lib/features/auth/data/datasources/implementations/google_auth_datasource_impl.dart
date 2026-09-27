import 'package:google_sign_in/google_sign_in.dart';

import '../../../../../core/constants/environment/environment.dart';
import '../interfaces/i_google_auth_datasource.dart';

/// Wrapper del plugin `google_sign_in` (v7): única clase que conoce el
/// SDK. `initialize` es lazy en el primer uso — no bloquea el arranque.
class GoogleAuthDataSourceImpl implements IGoogleAuthDataSource {
  // El plugin exige initialize() "exactly once" — el Future cacheado
  // serializa taps concurrentes del botón (dos getIdToken() a la vez no
  // llaman initialize dos veces).
  Future<void>? _initFuture;

  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: Environment.googleServerClientId,
    );
  }

  @override
  Future<String?> getIdToken() async {
    await _ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google Sign-In no soporta authenticate() en esta plataforma.',
      );
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      // Un authenticate() exitoso con idToken null NO es una cancelación
      // (en Android no ocurre, pero en otras plataformas tragarlo como
      // "cancelado" apagaría el error en silencio).
      if (idToken == null) {
        throw StateError(
          'Google authenticate() completó sin devolver idToken.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      // Usuario cerró el picker — no es un fallo, la capa de dominio lo
      // traduce a cancelación silenciosa.
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    // Inicializar aunque esta sesión de app no haya hecho getIdToken:
    // el usuario pudo entrar con Google en una sesión anterior.
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}
