# Propuesta 01: Corregir 4 hallazgos críticos de seguridad

Resuelve los 4 puntos marcados como 🔴 Crítico en la auditoría de arquitectura/seguridad:

1. Fuga del `API_TOKEN` real en logs de `AppBootstrap`.
2. Bypass de validación SSL demasiado permisivo en `AuthApiService` (matching por substring).
3. `RefreshTokenInterceptor` no funcional (solo comentarios, ningún refresh real ocurre).
4. `clearSession()` borra **todo** el `FlutterSecureStorage`, no solo las claves de auth.

> ⚠️ **Nota sobre el punto 3:** el backend real de stg/prod todavía no define el contrato del
> endpoint de refresh (confirmado con el usuario). Se implementa un contrato **provisional**
> (`POST /auth/refresh` con `{ "refreshToken": "..." }`, esperando `{ "token"|"accessToken",
> "refreshToken" }` en la respuesta), marcado explícitamente con un comentario `// PROVISIONAL:`
> en el código. **Debe revisarse y ajustarse en cuanto el equipo de backend confirme el contrato
> real.**

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/bootstrap/app_bootstrap.dart` | Actualización — eliminar log del token real |
| `lib/core/network/api/auth_api_service.dart` | Actualización — bypass SSL restringido a IPs privadas reales y solo en `dev` |
| `lib/core/network/interceptors/refresh_token_interceptor.dart` | Actualización — implementación real del refresh (contrato provisional) |
| `lib/core/di/setup_di.dart` | Actualización — inyectar dependencias reales al interceptor |
| `lib/features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart` | Actualización — `clearSession()` borra solo claves de auth |

---

## 1. app_bootstrap.dart (actualización)

**Ruta:** `lib/core/bootstrap/app_bootstrap.dart`

**Antes:**
```dart
    logger.info('Motores de la aplicación listos y en marcha...');
    logger.info('🌍 Entorno actual: ${Environment.currentEnvironment.name.toUpperCase()}');
    logger.info('🔗 API URL Activa: ${Environment.urlAuth}');
    logger.info('🔑 API Token Inyectado: ${Environment.apiToken}');
```

**Después:**
```dart
    logger.info('Motores de la aplicación listos y en marcha...');
    logger.info('🌍 Entorno actual: ${Environment.currentEnvironment.name.toUpperCase()}');
    logger.info('🔗 API URL Activa: ${Environment.urlAuth}');
    // Nunca se loguea el token real, ni siquiera en debug (evita fugas en consola/CI).
    logger.debug('🔑 API Token Inyectado: ${Environment.apiToken.isEmpty ? "(vacío)" : "(presente, oculto)"}');
```

---

## 2. auth_api_service.dart (actualización)

**Ruta:** `lib/core/network/api/auth_api_service.dart`

**Antes:**
```dart
    // Permitir certificados auto-firmados en localhost
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        final isLocal =
            host.contains('192.168.') ||
            host.contains('172.') ||
            host.contains('10.') ||
            host.contains('localhost') ||
            host.contains('127.0.0.1');
        return isLocal;
      };
      return client;
    };
```

**Después:**
```dart
    // Permitir certificados auto-firmados SOLO en desarrollo local y SOLO para IPs
    // privadas reales (RFC 1918) o localhost. Nunca se activa en stg/prod, y ya no
    // usamos matching por substring (evita bypass accidental en hosts como "miapi172.com").
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        if (Environment.currentEnvironment != EnvType.dev) return false;
        return _localDevHostRegex.hasMatch(host);
      };
      return client;
    };
```

Y agregar, como miembro estático de la clase (junto a `_dio`):
```dart
  static final RegExp _localDevHostRegex = RegExp(
    r'^(localhost|127\.0\.0\.1|10(\.\d{1,3}){3}|172\.(1[6-9]|2\d|3[0-1])(\.\d{1,3}){2}|192\.168(\.\d{1,3}){2})$',
  );
```

---

## 3. refresh_token_interceptor.dart (actualización)

**Ruta:** `lib/core/network/interceptors/refresh_token_interceptor.dart`

**Antes (archivo completo actual):**
```dart
// lib/core/network/interceptors/refresh_token_interceptor.dart
import 'package:dio/dio.dart';

/// Interceptor responsable de capturar errores 401 y refrescar el token.
///
/// Arquitectura: Cuando el token expira, captura la respuesta fallida,
/// frena la cascada de errores, manda a refrescar silenciosamente usando
/// el Repositorio de Auth, y re-intenta la petición original.
class RefreshTokenInterceptor extends Interceptor {

  // Por simplicidad de inyección cíclica, puedes usar un callback
  // o inyectar directamente el caso de uso de refresh.

  RefreshTokenInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Si la API nos expulsa porque el token expiró
    if (err.response?.statusCode == 401) {
      // 1. Llamar al RefreshTokenUseCase o Repository
      // 2. Guardar el nuevo token con ILocalAuthDataSource
      // 3. Clonar la Request original con el nuevo token inyectado
      // 4. Retornar handler.resolve(nuevaRespuesta);

      /* Ejemplo de lógica:
      final isRefreshed = await refreshUseCase();
      if(isRefreshed) {
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $nuevoToken';
        final cloneReq = await dio.fetch(options);
        return handler.resolve(cloneReq);
      }
      */
    }

    // Si no es un 401 o falló el refresh, pasamos el error como siempre
    super.onError(err, handler);
  }
}
```

**Después (archivo completo nuevo):**
```dart
// lib/core/network/interceptors/refresh_token_interceptor.dart
import 'package:dio/dio.dart';
import '../../constants/environment/environment.dart';
import '../../../features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';

/// Interceptor responsable de capturar errores 401 y refrescar el token.
///
/// SOLID (SRP): Aísla toda la coreografía de "token expiró -> refrescar ->
/// reintentar" fuera del resto de la capa de red.
///
/// ⚠️ PROVISIONAL: el contrato exacto del endpoint de refresh de stg/prod
/// todavía no fue confirmado por el equipo de backend. Este interceptor asume
/// `POST /auth/refresh` con body `{ "refreshToken": "..." }` y una respuesta
/// que incluya `token` (o `accessToken`) y opcionalmente `refreshToken`.
/// AJUSTAR ESTE CONTRATO en cuanto exista la definición real de la API.
class RefreshTokenInterceptor extends Interceptor {
  final ILocalAuthDataSource localDataSource;

  /// Provee el Dio "principal" (con todos sus interceptores) para reintentar
  /// la petición original una vez refrescado el token. Se inyecta como
  /// función porque el propio Dio principal es quien registra este
  /// interceptor (evita dependencia circular en el contenedor de DI).
  final Dio Function() mainDioProvider;

  bool _isRefreshing = false;

  RefreshTokenInterceptor(this.localDataSource, this.mainDioProvider);

  static const String _refreshPath = '/auth/refresh';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshCallItself = err.requestOptions.path.contains(_refreshPath);

    // Solo actuamos ante 401 de peticiones normales, nunca ante un 401 del
    // propio endpoint de refresh (evita loop infinito), y solo un refresh
    // concurrente a la vez.
    if (!isUnauthorized || isRefreshCallItself || _isRefreshing) {
      return super.onError(err, handler);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return super.onError(err, handler);
      }

      // Cliente Dio "limpio" (sin interceptores) exclusivamente para el
      // refresh: evita recursión si este mismo interceptor volviera a
      // interceptar su propia llamada.
      final refreshDio = Dio(BaseOptions(baseUrl: Environment.urlAuth));
      final refreshResponse = await refreshDio.post(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );

      final data = refreshResponse.data as Map<String, dynamic>;
      final newToken = data['token'] ?? data['accessToken'];
      final newRefreshToken = data['refreshToken'] ?? refreshToken;

      if (newToken == null) {
        return super.onError(err, handler);
      }

      await localDataSource.saveTokens(
        token: newToken as String,
        refreshToken: newRefreshToken as String,
      );

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';

      final response = await mainDioProvider().fetch(retryOptions);
      return handler.resolve(response);
    } catch (_) {
      // Si el refresh también falla, la sesión se considera perdida.
      await localDataSource.clearSession();
      return super.onError(err, handler);
    } finally {
      _isRefreshing = false;
    }
  }
}
```

---

## 4. setup_di.dart (actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**
```dart
  locator.registerLazySingleton<Dio>(() {
    final dio = AuthApiService().dio;

    // Inyectamos nuestros interceptores de Arquitectura Limpia
    dio.interceptors.add(AuthInterceptor(locator<ILocalAuthDataSource>()));
    dio.interceptors.add(RefreshTokenInterceptor());

    return dio;
  });
```

**Después:**
```dart
  locator.registerLazySingleton<Dio>(() {
    final dio = AuthApiService().dio;

    // Inyectamos nuestros interceptores de Arquitectura Limpia
    dio.interceptors.add(AuthInterceptor(locator<ILocalAuthDataSource>()));
    dio.interceptors.add(
      RefreshTokenInterceptor(
        locator<ILocalAuthDataSource>(),
        () => dio, // Closure: para cuando se use ya existe la instancia completa.
      ),
    );

    return dio;
  });
```

*(Nota: `locator<ILocalAuthDataSource>()` ya se resuelve como singleton en este mismo bloque para
`AuthInterceptor`; no introduce dependencia circular porque `RefreshTokenInterceptor` ya no
depende de `INetworkService`/`IRemoteAuthDataSource`, solo de `ILocalAuthDataSource` y de un Dio
"limpio" propio para la llamada de refresh.)*

---

## 5. secure_local_auth_datasource_impl.dart (actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart`

**Antes:**
```dart
  @override
  Future<void> clearSession() async {
    await secureStorage.deleteAll(); // Limpia todas las credenciales
  }
```

**Después:**
```dart
  @override
  Future<void> clearSession() async {
    // Borra únicamente las claves de autenticación. Evita destruir datos
    // seguros de otras features que puedan usar FlutterSecureStorage en el futuro.
    await secureStorage.delete(key: _userKey);
    await secureStorage.delete(key: _tokenKey);
    await secureStorage.delete(key: _refreshTokenKey);
  }
```

---

## Orden de aplicación

1. `lib/features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart` (independiente, sin dependencias nuevas).
2. `lib/core/bootstrap/app_bootstrap.dart` (independiente).
3. `lib/core/network/api/auth_api_service.dart` (agrega import de `Environment`/`EnvType`, ya usado en el mismo archivo).
4. `lib/core/network/interceptors/refresh_token_interceptor.dart` (nuevo contrato del constructor).
5. `lib/core/di/setup_di.dart` (debe actualizarse en conjunto con el paso 4, ya que cambia la firma del constructor de `RefreshTokenInterceptor`).

Tras aplicar, correr `flutter analyze` y `flutter test` (checklist de producción de AGENTS.md), y probar manualmente el flujo de login/expiración de token si hay forma de forzar un 401 en el entorno `dev`.
