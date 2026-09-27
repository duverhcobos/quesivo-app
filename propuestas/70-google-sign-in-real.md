# Propuesta: Login con Google real — consume `POST /auth/google` (backend 085)

El botón `GoogleAuthButton` ya está en login y register, el cubit y el
use-case existen, pero `RemoteAuthDataSourceImpl.loginWithGoogle` es un
**mock dev-only** que devuelve un user falso. Esta propuesta lo conecta
con el backend real (propuesta backend 085, doc `api/auth/022`):

```
GoogleAuthButton → AuthCubit.loginWithGoogle → LoginWithGoogleUseCase
  → AuthRepositoryImpl.loginWithGoogle
      1. IGoogleAuthDataSource.getIdToken()   ← SDK Google (nuevo)
      2. remote.loginWithGoogle(idToken)      ← POST /auth/google
      3. localDataSource.saveUserSession(modelo)  ← igual que login
```

La respuesta es `AuthResponseDto` de sesión **personal** (mismo shape que
`/auth/login`: `accessToken`/`refreshToken`/datos del user a nivel raíz —
`UserModel.fromJson` sirve tal cual). El post-login (selector de queseras
vía `/me` + `select-organization`) ya existe y no cambia.

Paquete: `google_sign_in: ^7.2.0` (API v7: `GoogleSignIn.instance` +
`initialize` + `authenticate`).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | `google_sign_in: ^7.2.0` |
| `lib/core/constants/environment/environment.dart` | `googleServerClientId` via dart-define |
| `lib/features/auth/data/datasources/interfaces/i_google_auth_datasource.dart` | **nuevo** — abstracción del SDK |
| `lib/features/auth/data/datasources/implementations/google_auth_datasource_impl.dart` | **nuevo** — wrapper `GoogleSignIn.instance` |
| `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart` | `loginWithGoogle({required String idToken})` |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | impl real `POST /auth/google` |
| `lib/features/auth/domain/failures/auth_failure.dart` | `GoogleSignInCancelledFailure` + `GoogleAuthFailure` |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | orquesta SDK→remote + mapeo de errores + signOut en logout |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | cancel → `AuthInitial()` (sin error) |
| `lib/core/di/setup_di.dart` | registrar `IGoogleAuthDataSource` |
| `.vscode/launch.json`, `ENVIRONMENTS.md` | documentar `GOOGLE_SERVER_CLIENT_ID` |
| tests | datasource (`idToken`→POST), repository (cancel/token/errores), cubit (cancel→initial) |

## Setup externo (NO es código — lo hace el usuario en Google Cloud)

1. Proyecto en Google Cloud Console → OAuth consent screen.
2. **Web client ID** → es el `serverClientId` de la app
   (`--dart-define=GOOGLE_SERVER_CLIENT_ID=...`) **y** va en el
   `GOOGLE_CLIENT_IDS` del `.env` del backend (es la audience que el
   backend valida).
3. **Android client** con el SHA-1 del keystore de debug
   (`keytool -list -v -keystore ~/.android/debug.keystore`) — lo exige
   Credential Manager en Android.

Sin estos IDs el código queda funcional pero `authenticate()` falla con
error de configuración — el usuario lo ve como `GoogleAuthFailure`
genérico, no rompe la app.

---

## 1. `pubspec.yaml` (existente — actualización)

**Después (en `dependencies:`):**

```yaml
  google_sign_in: ^7.2.0
```

## 2. `environment.dart` (existente — actualización)

**Después** (junto a `apiBaseUrl`):

```dart
  /// Web OAuth client ID de Google Cloud — audience que el backend
  /// valida en `POST /auth/google` (backend propuesta 085). Se inyecta
  /// con `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`; vacío = Google
  /// sign-in no configurado en este entorno (el datasource falla con
  /// error claro, no silencioso).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
```

## 3. `i_google_auth_datasource.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_google_auth_datasource.dart`

```dart
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
```

## 4. `google_auth_datasource_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/data/datasources/implementations/google_auth_datasource_impl.dart`

```dart
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../../core/constants/environment/environment.dart';
import '../interfaces/i_google_auth_datasource.dart';

/// Wrapper del plugin `google_sign_in` (v7): única clase que conoce el
/// SDK. `initialize` es lazy en el primer uso — no bloquea el arranque.
class GoogleAuthDataSourceImpl implements IGoogleAuthDataSource {
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: Environment.googleServerClientId,
    );
    _initialized = true;
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
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      // Usuario cerró el picker — no es un fallo, la capa de dominio lo
      // traduce a cancelación silenciosa.
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (!_initialized) return;
    await GoogleSignIn.instance.signOut();
  }
}
```

## 5. `i_remote_auth_datasource.dart` (existente — actualización)

**Antes:**

```dart
  Future<UserModel> loginWithGoogle();
```

**Después:**

```dart
  /// El idToken de Google ES la credencial (backend 085) — el
  /// repository la obtiene del SDK antes de llamar acá.
  Future<UserModel> loginWithGoogle({required String idToken});
```

## 6. `remote_auth_datasource_impl.dart` (existente — actualización)

**Antes:** el método completo del mock dev-only (bloque `UnimplementedError` + `Future.delayed` + `UserModel` falso).

**Después:**

```dart
  @override
  Future<UserModel> loginWithGoogle({required String idToken}) async {
    // Backend real — contrato documentacion/api/auth/022 (propuesta 085).
    // El DTO solo acepta idToken (forbidNonWhitelisted): NO enviar
    // deviceId/deviceName como en login — el server toma ip/user-agent
    // de los headers.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/google',
      data: {'idToken': idToken},
    );

    // AuthResponseDto de sesión personal — mismo shape que /auth/login.
    return UserModel.fromJson(responseData);
  }
```

El import de `Environment`/`EnvType` queda solo si otro método lo usa;
si queda huérfano, retirarlo.

## 7. `auth_failure.dart` (existente — actualización)

**Después** (al final, siguiendo el patrón `class X extends AuthFailure` con mensaje en español):

```dart
/// El usuario cerró el picker de Google sin elegir cuenta — no es un
/// error: el cubit lo traduce a volver al estado inicial sin mostrar
/// mensaje.
class GoogleSignInCancelledFailure extends AuthFailure {
  const GoogleSignInCancelledFailure()
    : super('Inicio de sesión con Google cancelado.');
}

/// El idToken de Google fue rechazado por el backend (401
/// GOOGLE_TOKEN_INVALID / GOOGLE_EMAIL_UNVERIFIED — propuesta 085) o el
/// SDK falló (config, red de Google, plataforma sin soporte).
class GoogleAuthFailure extends AuthFailure {
  const GoogleAuthFailure([String? message])
    : super(
        message ??
            'No se pudo iniciar sesión con Google. Inténtalo más tarde.',
      );
}
```

## 8. `auth_repository_impl.dart` (existente — actualización)

Inyectar `IGoogleAuthDataSource` en el constructor (campo nuevo
`googleAuthDataSource`).

**Antes** (`loginWithGoogle`, línea ~99-115):

```dart
  @override
  Future<Either<AuthFailure, User>> loginWithGoogle() async {
    // Misma verificación de red ...
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
```

**Después:**

```dart
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
      // inválido de email no verificado; 403 = suspendido (misma
      // semántica que login); 429 = rate limit.
      if (e.statusCode == 403) {
        return const Left(AccountSuspendedFailure());
      }
      if (e.statusCode == 429) {
        return const Left(TooManyAttemptsFailure());
      }
      if (e.errorCode == 'GOOGLE_EMAIL_UNVERIFIED') {
        return const Left(
          GoogleAuthFailure('Tu cuenta de Google no tiene el correo verificado.'),
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
```

Y en `logout()` (línea ~327): tras limpiar la sesión local, agregar
`await googleAuthDataSource.signOut();` dentro del try existente (un
fallo del signOut de Google no debe impedir el logout — envolver en su
propio try/catch con `logger.warning`).

## 9. `auth_cubit.dart` (existente — actualización)

**Antes:**

```dart
  Future<void> loginWithGoogle() async {
    emit(const AuthLoading());

    final failureOrUser = await _loginWithGoogleUseCase();

    failureOrUser.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }
```

**Después:**

```dart
  Future<void> loginWithGoogle() async {
    emit(const AuthLoading());

    final failureOrUser = await _loginWithGoogleUseCase();

    failureOrUser.fold(
      (failure) {
        // Cancelar el picker no es un error: volver al estado inicial
        // sin mensaje — el usuario simplemente desistió.
        if (failure is GoogleSignInCancelledFailure) {
          emit(const AuthInitial());
          return;
        }
        emit(AuthError(failure.message));
      },
      (user) => emit(AuthSuccess(user)),
    );
  }
```

## 10. `setup_di.dart` (existente — actualización)

Registrar el datasource nuevo y cablearlo al repository:

```dart
  sl.registerLazySingleton<IGoogleAuthDataSource>(
    () => GoogleAuthDataSourceImpl(),
  );
```

y agregarlo como argumento donde se construya `AuthRepositoryImpl`.

## 11. `.vscode/launch.json` + `ENVIRONMENTS.md` (existentes — actualización)

Documentar el dart-define nuevo (sin commitear el ID real — es público,
pero la convención es que los valores viven en el launch local/CI):

- `launch.json`: agregar `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>` al perfil dev (placeholder).
- `ENVIRONMENTS.md`: una línea describiendo `GOOGLE_SERVER_CLIENT_ID` junto a `API_URL`.

## 12. Tests

- `remote_auth_datasource_impl` spec: `loginWithGoogle(idToken)` hace
  `POST /auth/google` con `{idToken}` y nada más, y mapea la respuesta a
  `UserModel` (mockear `networkService`).
- `auth_repository_impl` spec: datasource google mockeado —
  cancel (`null` → `GoogleSignInCancelledFailure`), happy path
  (token → POST → `saveUserSession` llamado → `Right`), y mapping de
  403/429/`GOOGLE_EMAIL_UNVERIFIED`.
- `auth_cubit` spec: `GoogleSignInCancelledFailure` → `AuthInitial`,
  otro failure → `AuthError`.
- `GoogleAuthDataSourceImpl` NO lleva spec — es un wrapper fino del
  plugin (seam no testeable en unit, igual que `DeviceInfoService`).

## Orden de aplicación

1. `pubspec.yaml` + `flutter pub get`
2. `environment.dart`
3. `i_google_auth_datasource.dart` + `google_auth_datasource_impl.dart`
4. `auth_failure.dart`
5. `i_remote_auth_datasource.dart` → `remote_auth_datasource_impl.dart`
6. `auth_repository_impl.dart`
7. `auth_cubit.dart`
8. `setup_di.dart`
9. `launch.json` + `ENVIRONMENTS.md`
10. Tests + `flutter analyze` + `flutter test`

## Verificación

- `flutter analyze` sin issues · `flutter test` verde (560 + nuevos).
- Manual (requiere los client IDs de Google Cloud): botón Google en
  login → picker → backend `POST /auth/google` 200 → selector de queseras.

## Fuera de alcance

- Configuración de Google Cloud Console (client IDs, consent screen,
  SHA-1) — la hace el usuario; el código está listo para recibirlos.
- iOS `Info.plist` (reversed client ID) — solo si se da soporte iOS
  (hoy el target es Android).
