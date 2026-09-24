# Propuesta 66: Integración real de forgot/reset password + deep link `quesivo://`

Conecta las pantallas ya existentes de "Olvidé mi contraseña" / "Restablecer contraseña" al backend real (`POST /auth/forgot-password` + `POST /auth/reset-password`, propuesta backend 068) y agrega el deep link nativo (esquema custom `quesivo://`, sin depender de un dominio propio) para que tocar el enlace del correo abra la app directo en la pantalla de reset con el token.

**Decisión de diseño (esquema custom en vez de App Links/Universal Links)**: sin dominio propio verificado todavía (mismo bloqueo que el proveedor de email, ver `planeaciones/005` del backend), un Android App Link / iOS Universal Link real (`https://`) no es viable hoy — requieren hostear `assetlinks.json`/`apple-app-site-association` en un dominio verificado. Un esquema de URI custom (`quesivo://`) no necesita dominio, se registra solo en el manifest/plist de cada plataforma, y es el mismo patrón que usan apps sin dominio propio para sus "magic links". Migrar a `https://` el día que haya dominio es **solo cambiar `APP_DEEP_LINK_BASE` en el backend** — cero cambios de código Flutter (el deep link service ya normaliza ambas formas, ver punto 4).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | agregar dependencia `app_links` |
| `android/app/src/main/AndroidManifest.xml` | intent-filter del esquema `quesivo` |
| `ios/Runner/Info.plist` | `CFBundleURLTypes` con el esquema `quesivo` |
| `lib/core/deeplink/i_deep_link_service.dart` | nuevo |
| `lib/core/deeplink/app_links_deep_link_service_impl.dart` | nuevo |
| `lib/core/di/setup_di.dart` | actualización — registrar `IDeepLinkService` |
| `lib/main.dart` | actualización — inicializar el listener de deep links |
| `lib/features/auth/domain/failures/auth_failure.dart` | actualización — 2 failures nuevos |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | actualización — `forgotPassword`/`resetPassword` reales en todos los entornos |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | actualización — mapeo de `errorCode` |
| `lib/features/auth/presentation/widgets/forgot_password_actions.dart` | actualización — quitar el botón temporal de dev |
| `lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` | actualización — quitar `devResetLink` (ejecutar `flutter gen-l10n` después) |

---

## 1. pubspec.yaml (archivo existente — actualización)

**Ruta:** `pubspec.yaml`

**Antes:**
```yaml
  flutter_svg: ^2.3.0
  formz: ^0.8.0
  get_it: ^9.2.1
```

**Después:**
```yaml
  flutter_svg: ^2.3.0
  formz: ^0.8.0
  get_it: ^9.2.1
  app_links: ^7.2.1
```

Correr `flutter pub get` después de aplicar.

---

## 2. AndroidManifest.xml (archivo existente — actualización)

**Ruta:** `android/app/src/main/AndroidManifest.xml`

**Antes:**
```xml
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
```

**Después:**
```xml
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <!-- Deep link forgot/reset password (propuesta 66 / backend 068).
                 Esquema custom (no https): sin dominio propio verificado
                 todavía no se puede usar un App Link real (assetlinks.json).
                 android:autoVerify NO aplica a esquemas custom (solo a
                 http/https) — se omite a propósito. -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="quesivo"/>
            </intent-filter>
        </activity>
```

---

## 3. Info.plist (archivo existente — actualización)

**Ruta:** `ios/Runner/Info.plist`

**Antes:**
```xml
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
</dict>
</plist>
```

**Después:**
```xml
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<!-- Deep link forgot/reset password (propuesta 66 / backend 068) —
	     esquema custom, sin dominio propio verificado todavía (por eso no
	     es un Universal Link real con apple-app-site-association). -->
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>dev.quesivo.app</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>quesivo</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

---

## 4. i_deep_link_service.dart (archivo nuevo)

**Ruta:** `lib/core/deeplink/i_deep_link_service.dart`

```dart
import 'package:go_router/go_router.dart';

/// Contrato del servicio de deep links entrantes (forgot/reset password
/// hoy; cualquier flujo futuro que necesite abrir la app desde un link
/// externo se agrega acá).
///
/// SOLID (DIP): la capa de presentación/bootstrap no conoce el paquete
/// concreto (`app_links`) — solo este contrato.
abstract class IDeepLinkService {
  /// Arranca la escucha de deep links (cold start + con la app ya
  /// corriendo) y navega con [router] cuando la URI corresponde a una
  /// ruta pública conocida.
  void initialize(GoRouter router);

  /// Libera la suscripción — se llama si la app tuviera un ciclo de vida
  /// que lo requiera (hoy no aplica, pero completa el contrato).
  Future<void> dispose();
}
```

---

## 5. app_links_deep_link_service_impl.dart (archivo nuevo)

**Ruta:** `lib/core/deeplink/app_links_deep_link_service_impl.dart`

```dart
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

import '../logging/interfaces/i_logger_service.dart';
import '../routes/auth_guard.dart';
import 'i_deep_link_service.dart';

/// Implementación con el paquete `app_links` — soporta esquema custom
/// (`quesivo://...`) en Android/iOS sin necesitar dominio verificado.
class AppLinksDeepLinkServiceImpl implements IDeepLinkService {
  final AppLinks _appLinks = AppLinks();
  final ILoggerService _logger;
  StreamSubscription<Uri>? _subscription;

  AppLinksDeepLinkServiceImpl(this._logger);

  static const _scheme = 'quesivo';

  @override
  void initialize(GoRouter router) {
    // Cold start: la app se abrió DESDE el link (estaba cerrada).
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(router, uri);
    });

    // La app ya estaba corriendo (foreground/background).
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handle(router, uri),
      onError: (Object e, StackTrace st) => _logger.error(
        'Error escuchando deep links entrantes',
        error: e,
        stackTrace: st,
      ),
    );
  }

  void _handle(GoRouter router, Uri uri) {
    if (uri.scheme != _scheme) return;

    // Normaliza las dos formas válidas de un URI de esquema custom:
    //   quesivo://reset-password?token=x  → host='reset-password', path=''
    //   quesivo:/reset-password?token=x   → host='',                path='/reset-password'
    // a la misma ruta relativa, sin acoplarse a cuántas barras use
    // exactamente `APP_DEEP_LINK_BASE` del backend.
    final path = uri.host.isNotEmpty ? '/${uri.host}${uri.path}' : uri.path;

    // Solo reaccionamos a rutas públicas conocidas — un deep link con una
    // ruta que no reconocemos se ignora (fail-safe, no navegamos a ciegas).
    if (path != AuthGuard.resetPasswordRoute) {
      _logger.warning('Deep link con ruta desconocida ignorado: $uri');
      return;
    }

    final target = uri.query.isEmpty ? path : '$path?${uri.query}';
    router.go(target);
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
```

---

## 6. setup_di.dart (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**
```dart
import '../logging/interfaces/i_logger_service.dart';
import '../logging/implementations/debug_logger_service_impl.dart';
import '../logging/implementations/crashlytics_logger_service_impl.dart';
```

```dart
  // Le pasamos el AuthCubit global para que escuche sus estados
  locator.registerLazySingleton<AppRouter>(
    () => AppRouter(locator<AuthCubit>(), locator<AuthGuard>()),
  );
}
```

**Después:**
```dart
import '../deeplink/i_deep_link_service.dart';
import '../deeplink/app_links_deep_link_service_impl.dart';
import '../logging/interfaces/i_logger_service.dart';
import '../logging/implementations/debug_logger_service_impl.dart';
import '../logging/implementations/crashlytics_logger_service_impl.dart';
```

```dart
  // Le pasamos el AuthCubit global para que escuche sus estados
  locator.registerLazySingleton<AppRouter>(
    () => AppRouter(locator<AuthCubit>(), locator<AuthGuard>()),
  );

  // Deep link de forgot/reset password (propuesta 66) — se inicializa
  // desde main.dart una vez que el router ya existe.
  locator.registerLazySingleton<IDeepLinkService>(
    () => AppLinksDeepLinkServiceImpl(locator<ILoggerService>()),
  );
}
```

---

## 7. main.dart (archivo existente — actualización)

**Ruta:** `lib/main.dart`

**Antes:**
```dart
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/di/setup_di.dart';
import 'core/localization/cubit/locale_cubit.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';

// main.dart 100% S.O.L.I.D.
void main() async {
  // 1. Delegamos el caótico arranque a un Bootstrap externo (SRP)
  await AppBootstrap.init();

  // 2. Extraemos las dependencias puras desde el Service Locator en la raíz
  final appRouter = locator<AppRouter>().router;
  final authCubit = locator<AuthCubit>();
  final localeCubit = locator<LocaleCubit>();

  // 3. Inyectamos explícitamente por constructor (DIP)
  runApp(
    MainApp(router: appRouter, authCubit: authCubit, localeCubit: localeCubit),
  );
}
```

**Después:**
```dart
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/deeplink/i_deep_link_service.dart';
import 'core/di/setup_di.dart';
import 'core/localization/cubit/locale_cubit.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';

// main.dart 100% S.O.L.I.D.
void main() async {
  // 1. Delegamos el caótico arranque a un Bootstrap externo (SRP)
  await AppBootstrap.init();

  // 2. Extraemos las dependencias puras desde el Service Locator en la raíz
  final appRouter = locator<AppRouter>().router;
  final authCubit = locator<AuthCubit>();
  final localeCubit = locator<LocaleCubit>();

  // Deep link de forgot/reset password (propuesta 66) — necesita el
  // GoRouter ya construido para poder navegar cuando llegue un link.
  locator<IDeepLinkService>().initialize(appRouter);

  // 3. Inyectamos explícitamente por constructor (DIP)
  runApp(
    MainApp(router: appRouter, authCubit: authCubit, localeCubit: localeCubit),
  );
}
```

---

## 8. auth_failure.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/domain/failures/auth_failure.dart`

**Antes:**
```dart
class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure(super.message);
}
```

**Después:**
```dart
/// El `token` del link de reset no existe, ya fue usado, o expiró
/// (HTTP 400 + errorCode `INVALID_OR_EXPIRED_TOKEN` — backend propuesta
/// 068). El usuario debe volver a pedir "olvidé mi contraseña".
class InvalidOrExpiredTokenFailure extends AuthFailure {
  const InvalidOrExpiredTokenFailure()
    : super(
        'Este enlace ya no es válido o expiró. Solicita uno nuevo desde "¿Olvidaste tu contraseña?".',
      );
}

/// El password nuevo no cumple las reglas de fuerza del backend (HTTP 400
/// + errorCode `INVALID_PASSWORD`) — caso borde: el formulario ya valida
/// las mismas reglas client-side (RegisterPassword VO) antes de enviar.
class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure()
    : super(
        'La contraseña no cumple los requisitos de seguridad (mínimo 8 caracteres, mayúscula, minúscula y número).',
      );
}

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure(super.message);
}
```

---

## 9. remote_auth_datasource_impl.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

**Antes:**
```dart
  @override
  Future<void> forgotPassword(String email) async {
    // ⚠️ MOCK EXCLUSIVO DE DESARROLLO: DummyJSON no expone este endpoint.
    // Se bloquea explícitamente fuera de `dev` para que la app nunca reporte
    // un "correo enviado" falso en staging/producción.
    if (Environment.currentEnvironment != EnvType.dev) {
      throw UnimplementedError(
        'Recuperación de contraseña no está implementada para este entorno todavía.',
      );
    }

    await Future.delayed(const Duration(seconds: 1));
    return;
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    // ⚠️ MOCK EXCLUSIVO DE DESARROLLO: DummyJSON no expone
    // /auth/reset-password. En stg/prod va al endpoint real del backend.
    if (Environment.currentEnvironment == EnvType.dev) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    }

    await networkService.post<void>(
      '/auth/reset-password',
      data: {'token': token, 'password': password},
    );
  }
```

**Después:**
```dart
  @override
  Future<void> forgotPassword(String email) async {
    // Backend real en todos los entornos (propuesta backend 068) —
    // contrato documentacion/api/auth/013-post-forgot-password.md:
    // siempre 200, nunca revela si el email existe.
    await networkService.post<void>(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    // Backend real en todos los entornos (propuesta backend 068) —
    // contrato documentacion/api/auth/014-post-reset-password.md.
    await networkService.post<void>(
      '/auth/reset-password',
      data: {'token': token, 'password': password},
    );
  }
```

> Si tras este cambio `Environment`/`EnvType` quedan sin uso en este archivo (verificar `loginWithGoogle`, que sigue usándolos), quitar el import; si `loginWithGoogle` lo sigue necesitando, dejar el import como está.

---

## 10. auth_repository_impl.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Antes:**
```dart
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
```

**Después:**
```dart
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
```

---

## 11. forgot_password_actions.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/presentation/widgets/forgot_password_actions.dart`

**Antes:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/constants/environment/environment.dart';
import '../../../../core/routes/auth_guard.dart';
```

```dart
            // ⚠️ ACCESO TEMPORAL DE DESARROLLO: hasta que el
            // deep link del correo exista (backend), la pantalla
            // de reset solo se alcanza por este botón — jamás
            // se renderiza fuera de `dev`.
            if (Environment.currentEnvironment == EnvType.dev)
              TextButton(
                onPressed: () =>
                    context.push('${AuthGuard.resetPasswordRoute}?token=dev'),
                child: Text(l10n.devResetLink),
              ),
            const SizedBox(height: 20),
```

**Después:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
```

```dart
            // El acceso a /reset-password ahora es real: llega por el
            // deep link `quesivo://reset-password?token=...` del correo
            // (propuesta 66) — ya no hace falta un atajo de desarrollo.
            const SizedBox(height: 20),
```

También actualizar el comentario de cabecera del widget (líneas ~16-21) que menciona "el acceso temporal a reset solo en `EnvType.dev`" — quitar esa frase, ya no aplica.

---

## 12. Diccionarios i18n (archivos existentes — actualización)

Quitar la entrada `devResetLink` de los 3 diccionarios (ya no se usa):

**`lib/l10n/app_es.arb`** — quitar `"devResetLink": "Probar restablecer (dev)",`
**`lib/l10n/app_en.arb`** — quitar `"devResetLink": "Try reset (dev)",`
**`lib/l10n/app_pt.arb`** — quitar `"devResetLink": "Testar redefinição (dev)",`

Correr `flutter gen-l10n` después para regenerar `app_localizations*.dart` (no se edita a mano).

---

## Cómo probar de punta a punta (sin dominio propio)

1. Backend con `.env` `APP_DEEP_LINK_BASE=quesivo:/` (ya seteado en el `.env` local del backend).
2. Flutter: `flutter run --dart-define=ENV=dev` (o el launch profile que ya usan) en un emulador/dispositivo con la app instalada.
3. Pantalla "¿Olvidaste tu contraseña?" → ingresar el email real de una cuenta → el backend manda el correo (Resend sandbox: llega a `MAIL_SANDBOX_REDIRECT_TO`, no al email ingresado — ver planeaciones/005 §9 del backend).
4. Abrir ese correo **desde el dispositivo/emulador donde está instalada la app** y tocar el enlace `quesivo://reset-password?token=...`. Android/iOS deben ofrecer abrir con Quesivo (o abrirla directo si es la única app registrada para ese esquema).
5. La app debe abrir en `ResetPasswordScreen` con el token ya cargado — completar el formulario y confirmar que redirige a login con el toast de éxito.
6. Caso de error: tocar un link ya usado o esperar a que expire (30 min) → toast con el mensaje de `InvalidOrExpiredTokenFailure`.

---

## Orden de aplicación

1. `pubspec.yaml` + `flutter pub get`
2. `android/app/src/main/AndroidManifest.xml`
3. `ios/Runner/Info.plist`
4. `lib/core/deeplink/i_deep_link_service.dart`
5. `lib/core/deeplink/app_links_deep_link_service_impl.dart`
6. `lib/core/di/setup_di.dart`
7. `lib/main.dart`
8. `lib/features/auth/domain/failures/auth_failure.dart`
9. `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`
10. `lib/features/auth/data/repositories/auth_repository_impl.dart`
11. `lib/features/auth/presentation/widgets/forgot_password_actions.dart`
12. `lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` + `flutter gen-l10n`
13. `flutter analyze` + `flutter test` — verde antes de avisar al usuario para la validación visual (ver skill `code-proposals`: la propuesta se implementa de inmediato, la auditoría de código va después de que el usuario valide en el device).
