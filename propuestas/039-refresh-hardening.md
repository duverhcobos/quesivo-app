# Propuesta: Hardening del RefreshTokenInterceptor (fixes post-auditoría)

La auditoría de la propuesta 038 encontró un problema de comportamiento
real: el `catch (_)` del flujo de refresh trata **todo** error como sesión
irrecuperable y desloguea al usuario. Solo un **401 del endpoint de
refresh** (o la ausencia de refresh token) prueba que la sesión murió —
un timeout, un 5xx de Render en cold start, o una caída de red son
transitorios y deben propagar el error original conservando la sesión.

Fixes incluidos (todos sobre código de la 038):

1. Discriminar error de refresh: `_expireSession()` solo ante 401 del
   endpoint o ausencia de refresh token. Lo demás → `completeError` +
   propagar, sin limpiar storage ni notificar.
2. `_expireSession()` con `try/finally`: si `clearSession()` lanza
   (fallo del canal nativo), la notificación a `AuthCubit` igual se
   emite — sino la UI queda zombie igual que antes del fix.
3. `refreshDioProvider` pasa a ser `() => AuthApiService().dio`:
   hereda timeouts (30s), `badCertificateCallback` de dev y el logging
   de dev — un `Dio(BaseOptions(...))` pelado podía colgar el completer
   para siempre ante un refresh sin timeout (cuelgue en cascada de los
   401 que esperan).
4. Guard: si el request que dio 401 **no llevaba header Authorization**
   (ej. login con credenciales malas), no hay sesión que refrescar —
   propagar directo sin tocar storage.
5. `path.contains(_refreshPath)` → `path == _refreshPath` (más estricto).
6. `emit` del cubit con guard `!isClosed` (evento durante `close()`).
7. `dispose:` del notifier en el registro de DI.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/network/interceptors/refresh_token_interceptor.dart` | Discriminar 401-vs-transitorio, guard Authorization, `==` en path, `finally` en `_expireSession` |
| `lib/core/di/setup_di.dart` | `refreshDioProvider` usa `AuthApiService().dio`; `dispose` en registro del notifier |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | Guard `!isClosed` en el listener |
| `test/core/network/interceptors/refresh_token_interceptor_test.dart` | Tests nuevos: error transitorio conserva sesión, 200 malformado conserva sesión, 401 sin header Authorization no toca storage |

Sin cambios de i18n ni dependencias.

---

## 1. refresh_token_interceptor.dart (archivo existente — actualización)

**Ruta:** `lib/core/network/interceptors/refresh_token_interceptor.dart`

**Antes:**

```dart
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshCallItself = err.requestOptions.path.contains(
      _refreshPath,
    );
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;

    // Solo entra al flujo de refresh un 401 de petición normal aún no
    // reintentada. El 401 del propio /auth/refresh o de un retry se
    // propaga tal cual (sin loops).
    if (!isUnauthorized || isRefreshCallItself || alreadyRetried) {
      return super.onError(err, handler);
    }
```

**Después:**

```dart
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshCallItself = err.requestOptions.path == _refreshPath;
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    final hadAuthHeader =
        err.requestOptions.headers['Authorization'] != null;

    // Solo entra al flujo de refresh un 401 de petición autenticada aún no
    // reintentada. Un 401 sin Authorization (ej. login con credenciales
    // inválidas) no tiene sesión que refrescar; el 401 del propio
    // /auth/refresh o de un retry se propaga tal cual (sin loops).
    if (!isUnauthorized ||
        isRefreshCallItself ||
        alreadyRetried ||
        !hadAuthHeader) {
      return super.onError(err, handler);
    }
```

**Antes:**

```dart
    _refreshCompleter = Completer<void>();
    // Si el refresh falla sin que ningún request concurrente haya llegado
    // a esperar este completer, su error no tendría listeners y Dart lo
    // reportaría como async no manejado. ignore() solo silencia ese
    // reporte: quien sí haga await de inFlight.future recibe el error
    // normalmente.
    _refreshCompleter!.future.ignore();
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw StateError('no refresh token');
      }

      final refreshResponse = await refreshDioProvider().post(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );

      final data = refreshResponse.data as Map<String, dynamic>;
      final newToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newToken == null || newRefreshToken == null) {
        throw StateError('refresh response incompleta');
      }

      await localDataSource.saveTokens(
        token: newToken,
        refreshToken: newRefreshToken,
      );

      _refreshCompleter!.complete();
    } catch (_) {
      // Refresh falló (401 del endpoint, token reusado, red caída o
      // ausencia de refresh token): sesión irrecuperable. Limpiar y
      // avisar para que la UI salga a welcome.
      _refreshCompleter!.completeError(StateError('refresh failed'));
      await _expireSession();
      return super.onError(err, handler);
    } finally {
      _refreshCompleter = null;
    }
```

**Después:**

```dart
    _refreshCompleter = Completer<void>();
    // Si el refresh falla sin que ningún request concurrente haya llegado
    // a esperar este completer, su error no tendría listeners y Dart lo
    // reportaría como async no manejado. ignore() solo silencia ese
    // reporte: quien sí haga await de inFlight.future recibe el error
    // normalmente.
    _refreshCompleter!.future.ignore();
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const _SessionDeadException();
      }

      final refreshResponse = await refreshDioProvider().post(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );

      final data = refreshResponse.data as Map<String, dynamic>;
      final newToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newToken == null || newRefreshToken == null) {
        // 200 sin los campos esperados: respuesta malformada del
        // servidor, no prueba de sesión muerta — transitorio.
        throw StateError('refresh response incompleta');
      }

      await localDataSource.saveTokens(
        token: newToken,
        refreshToken: newRefreshToken,
      );

      _refreshCompleter!.complete();
    } on DioException catch (e) {
      _refreshCompleter!.completeError(StateError('refresh failed'));
      // Solo un 401 del endpoint de refresh prueba sesión irrecuperable
      // (token inválido, expirado, o reuso detectado que revocó todas
      // las sesiones). Un timeout, un 5xx o red caída son transitorios:
      // se conserva la sesión y el próximo request reintentará.
      if (e.response?.statusCode == 401) {
        await _expireSession();
      }
      return super.onError(err, handler);
    } on _SessionDeadException {
      _refreshCompleter!.completeError(StateError('refresh failed'));
      await _expireSession();
      return super.onError(err, handler);
    } catch (_) {
      // Errores de storage, cast de la respuesta, etc.: transitorios,
      // la sesión se conserva.
      _refreshCompleter!.completeError(StateError('refresh failed'));
      return super.onError(err, handler);
    } finally {
      _refreshCompleter = null;
    }
```

Y al final del archivo:

```dart
/// Marcador interno: el refresh token ni siquiera existe en storage —
/// sesión irrecuperable sin necesidad de pegarle a la API.
class _SessionDeadException implements Exception {
  const _SessionDeadException();
}
```

**Antes:**

```dart
  Future<void> _expireSession() async {
    await localDataSource.clearSession();
    sessionExpiredNotifier.notifySessionExpired();
  }
```

**Después:**

```dart
  Future<void> _expireSession() async {
    // Si clearSession lanza (fallo del canal nativo de secure storage)
    // la notificación igual tiene que salir: es lo único que saca a la
    // UI del estado "logueado zombie".
    try {
      await localDataSource.clearSession();
    } finally {
      sessionExpiredNotifier.notifySessionExpired();
    }
  }
```

## 2. setup_di.dart (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**

```dart
        () => Dio(
          BaseOptions(baseUrl: Environment.urlAuth),
        ), // Dio "limpio" sin interceptores, solo para /auth/refresh.
      ),
    );
```

**Después:**

```dart
        // Dio "limpio" de refresh: misma config que el principal
        // (timeouts 30s, cert auto-firmado solo en dev LAN, logging dev)
        // pero SIN AuthInterceptor/RefreshTokenInterceptor — esos se
        // agregan solo sobre `dio` acá, así que no hay recursión.
        () => AuthApiService().dio,
      ),
    );
```

**Antes:**

```dart
  // Evento "sesión irrecuperable": emitido por RefreshTokenInterceptor,
  // consumido por AuthCubit.
  locator.registerLazySingleton<SessionExpiredNotifier>(
    () => SessionExpiredNotifier(),
  );
```

**Después:**

```dart
  // Evento "sesión irrecuperable": emitido por RefreshTokenInterceptor,
  // consumido por AuthCubit.
  locator.registerLazySingleton<SessionExpiredNotifier>(
    () => SessionExpiredNotifier(),
    dispose: (notifier) => notifier.dispose(),
  );
```

*(si queda algún import de `Environment` sin uso tras el cambio, quitarlo)*

## 3. auth_cubit.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/presentation/cubit/auth_cubit.dart`

**Antes:**

```dart
    _sessionExpiredSub = _sessionExpiredNotifier.stream.listen((_) {
      if (state is AuthSuccess) emit(const AuthInitial());
    });
```

**Después:**

```dart
    _sessionExpiredSub = _sessionExpiredNotifier.stream.listen((_) {
      // isClosed: un evento puede llegar entre close() y la cancelación
      // efectiva de la suscripción — emitir ahí lanzaría StateError.
      if (!isClosed && state is AuthSuccess) emit(const AuthInitial());
    });
```

## 4. refresh_token_interceptor_test.dart (archivo existente — agregar tests)

**Ruta:** `test/core/network/interceptors/refresh_token_interceptor_test.dart`

Agregar al final del `main()`:

```dart
  test('error transitorio del refresh (5xx) conserva la sesión', () async {
    when(() => local.getRefreshToken())
        .thenAnswer((_) async => 'old-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenThrow(
      DioException(
        requestOptions: _opts(path: '/auth/refresh'),
        response: Response(
          requestOptions: _opts(path: '/auth/refresh'),
          statusCode: 502,
        ),
      ),
    );

    interceptor.onError(_err401(), handler);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verifyNever(() => local.clearSession());
    verifyNever(() => local.saveTokens(
        token: any(named: 'token'), refreshToken: any(named: 'refreshToken')));
  });

  test('refresh 200 sin campos esperados conserva la sesión', () async {
    when(() => local.getRefreshToken())
        .thenAnswer((_) async => 'old-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: _opts(path: '/auth/refresh'),
        statusCode: 200,
        data: <String, dynamic>{},
      ),
    );

    interceptor.onError(_err401(), handler);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verifyNever(() => local.clearSession());
  });

  test('401 sin header Authorization no entra al flujo de refresh',
      () async {
    final err = DioException(
      requestOptions: _opts(), // sin Authorization en headers
      response: Response(requestOptions: _opts(), statusCode: 401),
    );

    interceptor.onError(err, handler);
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => local.getRefreshToken());
    verifyNever(() => local.clearSession());
  });
```

*Nota:* `_opts()` ya devuelve `headers: {}` vacío — el test de 401-sin-header
usa un request sin `Authorization` tal cual. Los tests existentes siguen
pasando igual (sus requests usan `_opts()` que no setea Authorization...
**ajustar `_opts` para que incluya `headers: {'Authorization': 'Bearer x'}`
por defecto** y que el test nuevo pase headers vacío explícito — de lo
contrario los tests viejos caerían en el nuevo guard).

```dart
// _opts actualizado: autenticado por defecto
RequestOptions _opts({String path = '/data', bool withAuth = true}) =>
    RequestOptions(
      path: path,
      headers: withAuth ? {'Authorization': 'Bearer token'} : <String, String>{},
      extra: {},
    );
```

(y el test nuevo usa `_opts(withAuth: false)`)

---

## Orden de aplicación

1. `refresh_token_interceptor.dart` (guards + discriminación de error + `_SessionDeadException` + `finally` en `_expireSession`)
2. `setup_di.dart` (`AuthApiService().dio` + `dispose`)
3. `auth_cubit.dart` (guard `!isClosed`)
4. `refresh_token_interceptor_test.dart` (`_opts` con `withAuth` + 3 tests nuevos)
5. `flutter analyze` + `flutter test` limpios.
