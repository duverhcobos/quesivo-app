# Propuesta: Fixes de la 2da auditoría (rotación de tokens + bordes de checkAuthStatus)

La auditoría del delta 039/040 encontró un **bloqueante** y varios bordes
relacionados con la interacción refresh↔`checkAuthStatus`:

## El bloqueante

`checkAuthStatus` lee la sesión local (tokens T1/RT1) **antes** de llamar
`getMe()`. Si el access token estaba vencido, el `RefreshTokenInterceptor`
refresca transparente y persiste T2/RT2 — pero `merged` se construye con
`local.token`/`local.refreshToken` (snapshot pre-refresh) y
`saveUserSession(merged)` ejecuta `saveTokens(T1, RT1)`, **pisando los
tokens frescos con los revocados**. El próximo request autenticado lleva
RT1 rotado → 401 del endpoint → sesión expirada; peor, la detección de
reuso del backend (`003-post-refresh.md`) puede revocar **todas** las
sesiones del usuario.

**Fix**: tras `getMe()` exitoso, **re-leer** `getToken()`/`getRefreshToken()`
— esas claves ya tienen el valor correcto (rotado si hubo refresh, el mismo
si no). `merged` usa los valores en vivo.

## Bordes que se arreglan en la misma pasada

- `_expireSession()` que lanza (fallo nativo de storage) puede impedir que
  el error original se propague al caller → envolver en `try/catch` propio
  dentro de los catch del flujo de refresh.
- Refresh transitorio fallido → el 401 original llega a `getMe` como
  `UnauthorizedException` → `checkAuthStatus` devolvía `NoSessionFailure`
  aunque la sesión siga viva en storage. **Fix**: ante `UnauthorizedException`,
  re-leer `getUserSession()` — null → sesión muerta de verdad (el
  interceptor limpió); non-null → transitorio → `Right(local)`. El caso
  "retry 401 con sesión muerta en storage" se auto-cura en el próximo
  request (su refresh dará 401 → expira bien).
- Rama `suspended`: si `clearSession()` lanza cae al catch genérico →
  `Right(local)` → usuario suspendido queda logueado. **Fix**: `try/catch`
  local y devolver `AccountSuspendedFailure` siempre.
- Nit: `() => AuthApiService().dio` crea una instancia nueva por refresh →
  hoistear a una sola instancia en `setup_di`.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Re-leer tokens post-getMe; `UnauthorizedException` re-lee sesión; suspended con try/catch |
| `lib/core/network/interceptors/refresh_token_interceptor.dart` | `_expireSession` envuelto en try/catch en los call sites |
| `lib/core/di/setup_di.dart` | Instancia única de refresh Dio |
| `test/features/auth/data/repositories/auth_repository_impl_test.dart` | Stubs de getToken/getRefreshToken + test de rotación + casos Unauthorized + clearSession lanza en suspended |
| `test/core/network/interceptors/refresh_token_interceptor_test.dart` | Test: clearSession lanza → notifier igual dispara y error propaga |

---

## 1. auth_repository_impl.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Antes:**

```dart
      // Merge: perfil fresco del servidor + tokens del storage (el
      // endpoint no los devuelve). saveUserSession refresca el cache.
      final merged = UserModel(
        id: fresh.id,
        email: fresh.email,
        name: fresh.name,
        token: local.token,
        refreshToken: local.refreshToken,
        organizationId: fresh.organizationId,
        organizationName: fresh.organizationName,
        roles: fresh.roles,
        status: fresh.status,
      );
      await localDataSource.saveUserSession(merged);
      return Right(merged);
    } on UnauthorizedException {
      // El RefreshTokenInterceptor ya intentó refrescar y falló: storage
      // limpio + notifier disparado. Sesión irrecuperable.
      return const Left(NoSessionFailure());
    } on RestApiException catch (e, stackTrace) {
```

**Después:**

```dart
      // Merge: perfil fresco del servidor + tokens EN VIVO del storage.
      // CRÍTICO: re-leerlos DESPUÉS de getMe — si el access token venía
      // vencido, el RefreshTokenInterceptor ya rotó y persistió tokens
      // nuevos; usar local.token/local.refreshToken acá pisaría esos
      // valores con los revocados (y reusar un refresh token rotado hace
      // que el backend revoque TODAS las sesiones — ver doc 003).
      final liveToken = await localDataSource.getToken();
      final liveRefreshToken = await localDataSource.getRefreshToken();
      final merged = UserModel(
        id: fresh.id,
        email: fresh.email,
        name: fresh.name,
        token: liveToken,
        refreshToken: liveRefreshToken,
        organizationId: fresh.organizationId,
        organizationName: fresh.organizationName,
        roles: fresh.roles,
        status: fresh.status,
      );
      await localDataSource.saveUserSession(merged);
      return Right(merged);
    } on UnauthorizedException {
      // Puede ser sesión muerta de verdad (refresh 401 → interceptor
      // limpió storage + notificó) O un refresh transitorio fallido que
      // propagó el 401 original con la sesión intacta. Se distingue
      // re-leyendo el storage:
      final stillThere = await localDataSource.getUserSession();
      if (stillThere == null) {
        return const Left(NoSessionFailure());
      }
      return Right(local); // transitorio — conservar sesión
    } on RestApiException catch (e, stackTrace) {
```

**Antes** (rama suspended):

```dart
      if (fresh.status == 'suspended') {
        await localDataSource.clearSession();
        return const Left(AccountSuspendedFailure());
      }
```

**Después:**

```dart
      if (fresh.status == 'suspended') {
        // La cuenta murió del lado del servidor: reportar suspensión
        // aunque el borrado local falle (si lanza, igual hay que
        // desloguear — peor caso queda un cache huérfano que se limpia
        // en el próximo 401).
        try {
          await localDataSource.clearSession();
        } catch (_) {}
        return const Left(AccountSuspendedFailure());
      }
```

## 2. refresh_token_interceptor.dart (archivo existente — actualización)

**Ruta:** `lib/core/network/interceptors/refresh_token_interceptor.dart`

**Antes:**

```dart
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
```

**Después:**

```dart
    } on DioException catch (e) {
      _refreshCompleter!.completeError(StateError('refresh failed'));
      // Solo un 401 del endpoint de refresh prueba sesión irrecuperable
      // (token inválido, expirado, o reuso detectado que revocó todas
      // las sesiones). Un timeout, un 5xx o red caída son transitorios:
      // se conserva la sesión y el próximo request reintentará.
      if (e.response?.statusCode == 401) {
        await _tryExpireSession();
      }
      return super.onError(err, handler);
    } on _SessionDeadException {
      _refreshCompleter!.completeError(StateError('refresh failed'));
      await _tryExpireSession();
      return super.onError(err, handler);
    } catch (_) {
```

**Antes:**

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

**Después:**

```dart
  /// Wrapper que garantiza que un fallo de storage nunca impida propagar
  /// el error original del request — un throw acá puede dejar el
  /// handler sin resolver y colgar la petición del usuario.
  Future<void> _tryExpireSession() async {
    try {
      await _expireSession();
    } catch (_) {}
  }

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

## 3. setup_di.dart (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**

```dart
    dio.interceptors.add(AuthInterceptor(locator<ILocalAuthDataSource>()));
    dio.interceptors.add(
      RefreshTokenInterceptor(
        locator<ILocalAuthDataSource>(),
        locator<SessionExpiredNotifier>(),
        () =>
            dio, // Closure: para cuando se use ya existe la instancia completa.
        // Dio "limpio" de refresh: misma config que el principal
        // (timeouts 30s, cert auto-firmado solo en dev LAN, logging dev)
        // pero SIN AuthInterceptor/RefreshTokenInterceptor — esos se
        // agregan solo sobre `dio` acá, así que no hay recursión.
        () => AuthApiService().dio,
      ),
    );
```

**Después:**

```dart
    dio.interceptors.add(AuthInterceptor(locator<ILocalAuthDataSource>()));
    // Dio "limpio" de refresh: misma config que el principal (timeouts
    // 30s, cert auto-firmado solo en dev LAN, logging dev) pero SIN
    // AuthInterceptor/RefreshTokenInterceptor — esos se agregan solo
    // sobre `dio` acá, así que no hay recursión. Instancia única: una
    // por app alcanza, no una por refresh.
    final refreshDio = AuthApiService().dio;
    dio.interceptors.add(
      RefreshTokenInterceptor(
        locator<ILocalAuthDataSource>(),
        locator<SessionExpiredNotifier>(),
        () =>
            dio, // Closure: para cuando se use ya existe la instancia completa.
        () => refreshDio,
      ),
    );
```

## 4. auth_repository_impl_test.dart (archivo existente — actualización)

**Ruta:** `test/features/auth/data/repositories/auth_repository_impl_test.dart`

En el `setUp` del grupo `checkAuthStatus`, agregar stubs de tokens en vivo:

```dart
      when(
        () => mockLocalDataSource.getToken(),
      ).thenAnswer((_) async => 'token');
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'refresh');
```

Ajustar el test existente y agregar los casos nuevos:

```dart
    test('usa los tokens EN VIVO post-getMe (rotación transparente)', () async {
      // Simula: access token vencido → el interceptor refrescó y guardó
      // T2/RT2 durante getMe. getToken/getRefreshToken devuelven los nuevos.
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel); // snapshot con 'token'/'refresh' viejos
      when(() => mockRemoteDataSource.getMe()).thenAnswer((_) async {
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'token-ROTATED');
        when(
          () => mockLocalDataSource.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-ROTATED');
        return tFreshModel;
      });

      final result = await repository.checkAuthStatus();

      result.fold((_) => fail('debía ser Right'), (user) {
        expect(user.token, 'token-ROTATED');
        expect(user.refreshToken, 'refresh-ROTATED');
      });
      // saveUserSession persiste perfil + tokens: deben ser los rotados,
      // nunca el snapshot pre-refresh.
      final saved = verify(
        () => mockLocalDataSource.saveUserSession(captureAny()),
      ).captured.single as UserModel;
      expect(saved.refreshToken, 'refresh-ROTATED');
    });

    test('401 de /auth/me con sesión aún en storage = transitorio', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockRemoteDataSource.getMe(),
      ).thenThrow(UnauthorizedException());

      final result = await repository.checkAuthStatus();

      expect(result, const Right(tUserModel));
    });

    test('401 de /auth/me con storage ya limpio = sesión muerta', () async {
      var cleared = false;
      when(() => mockLocalDataSource.getUserSession()).thenAnswer(
        (_) async => cleared ? null : tUserModel,
      );
      when(() => mockRemoteDataSource.getMe()).thenAnswer((_) async {
        cleared = true; // el interceptor limpió durante el 401
        throw UnauthorizedException();
      });

      final result = await repository.checkAuthStatus();

      expect(result, const Left(NoSessionFailure()));
    });

    test('suspended devuelve AccountSuspendedFailure aunque clearSession falle',
        () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);
      when(() => mockRemoteDataSource.getMe()).thenAnswer(
        (_) async => const UserModel(
          id: '1',
          email: tEmail,
          name: 'John Doe',
          status: 'suspended',
        ),
      );
      when(
        () => mockLocalDataSource.clearSession(),
      ).thenThrow(Exception('storage roto'));

      final result = await repository.checkAuthStatus();

      expect(result, const Left(AccountSuspendedFailure()));
    });
```

*Nota:* el test existente "retorna perfil fresco y refresca el cache local"
sigue válido — con los stubs del setUp (`getToken`→'token') el merged sale
con los mismos valores que `tUserModel`. Si el `expect(user.token,
tUserModel.token)` choca con el nuevo re-read, ajustar al valor del stub.

## 5. refresh_token_interceptor_test.dart (archivo existente — agregar test)

**Ruta:** `test/core/network/interceptors/refresh_token_interceptor_test.dart`

```dart
  test('clearSession que lanza igual notifica y propaga el error', () async {
    when(() => local.getRefreshToken())
        .thenAnswer((_) async => 'dead-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenThrow(_err401(path: '/auth/refresh'));
    when(() => local.clearSession()).thenThrow(Exception('storage roto'));

    var notified = false;
    notifier.stream.listen((_) => notified = true);

    interceptor.onError(_err401(), handler);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(notified, isTrue);
    verify(() => handler.next(any())).called(1); // el error original propaga
  });
```

---

## Orden de aplicación

1. `auth_repository_impl.dart` (re-read tokens + UnauthorizedException + suspended try/catch)
2. `refresh_token_interceptor.dart` (`_tryExpireSession` wrapper)
3. `setup_di.dart` (instancia única de refreshDio)
4. `auth_repository_impl_test.dart` (stubs + 4 tests)
5. `refresh_token_interceptor_test.dart` (1 test)
6. `flutter analyze` + `flutter test` limpios.
