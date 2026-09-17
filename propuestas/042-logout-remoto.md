# Propuesta: `logout()` revoca la sesión en el backend (best-effort)

Hoy `logout()` solo hace `localDataSource.clearSession()` — el refresh token
queda **vivo 7 días** en `user_sessions`. Con la propuesta backend 047
(`/auth/logout` público) la app puede revocarlo de verdad:

```
leer refreshToken → POST /auth/logout (best-effort) → clearSession siempre
```

El logout local **nunca** depende del remoto: offline, 5xx o 401 ("token ya
muerto" — el objetivo ya se cumplió) cierran sesión igual. Un usuario no debe
quedar atrapado dentro de la app por un error de red.

Además hay que excluir `/auth/logout` del flujo de refresh del interceptor:
si el endpoint responde 401 (token ya inexistente/revocado), hoy el
interceptor intentaría refrescar → rotaría el refresh token → crearía una
sesión nueva huérfana en el servidor justo cuando el usuario se está yendo.

Depende de: `propuestas/047-logout-publico.md` (backend) desplegada.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart` | Método nuevo `logout` |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | `POST /auth/logout` |
| `lib/core/network/interceptors/refresh_token_interceptor.dart` | `/auth/logout` exento del flujo de refresh |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | `logout()` revoca remoto + limpia local |
| `test/features/auth/data/repositories/auth_repository_impl_test.dart` | `group('logout')` reescrito: 5 casos |
| `test/core/network/interceptors/refresh_token_interceptor_test.dart` | +1 caso: 401 de logout no refresca |

Sin cambios de i18n, rutas, cubit ni UI — `LogoutUseCase` y `AuthCubit.logout`
quedan igual (la firma del repo no cambia). Sin cambios de DI:
`remoteDataSource` ya está inyectado en el repo.

---

## 1. `i_remote_auth_datasource.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart`

**Antes:**

```dart
  /// Perfil fresco del usuario autenticado desde `GET /auth/me`
  /// (`documentacion/api/auth/005-get-me.md`). Incluye `status` leído de
  /// BD. El Bearer lo inyecta AuthInterceptor; un 401 dispara el refresh
  /// automático del RefreshTokenInterceptor antes de llegar acá.
  Future<UserModel> getMe();
}
```

**Después:**

```dart
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
}
```

## 2. `remote_auth_datasource_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

**Antes:**

```dart
  @override
  Future<UserModel> getMe() async {
    // Contrato real (documentacion/api/auth/005-get-me.md): identidad
    // resuelta del JWT — sin body ni params. Real en todos los entornos
    // (en dev apunta al backend local/Render igual que login).
    final responseData = await networkService.get<Map<String, dynamic>>(
      '/auth/me',
    );
    return UserModel.fromJson(responseData);
  }
}
```

**Después:**

```dart
  @override
  Future<UserModel> getMe() async {
    // Contrato real (documentacion/api/auth/005-get-me.md): identidad
    // resuelta del JWT — sin body ni params. Real en todos los entornos
    // (en dev apunta al backend local/Render igual que login).
    final responseData = await networkService.get<Map<String, dynamic>>(
      '/auth/me',
    );
    return UserModel.fromJson(responseData);
  }

  @override
  Future<void> logout(String refreshToken) async {
    // Real en todos los entornos (propuesta 42) — endpoint público desde
    // la propuesta backend 047: el body es la credencial a revocar.
    await networkService.post<void>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }
}
```

## 3. `refresh_token_interceptor.dart` (archivo existente — actualización)

**Ruta:** `lib/core/network/interceptors/refresh_token_interceptor.dart`

**Antes:**

```dart
  static const String _refreshPath = '/auth/refresh';
```

**Después:**

```dart
  static const String _refreshPath = '/auth/refresh';

  /// Endpoints exentos del flujo de refresh ante un 401:
  /// - `/auth/refresh`: un 401 es "sesión irrecuperable" — no hay nada
  ///   que refrescar.
  /// - `/auth/logout`: un 401 es "el token ya estaba muerto" — justo el
  ///   objetivo del logout. Refrescar acá rotaría el refresh token y
  ///   crearía una sesión nueva huérfana en el servidor mientras el
  ///   usuario se está yendo (propuesta 42).
  static const Set<String> _refreshExemptPaths = {
    _refreshPath,
    '/auth/logout',
  };
```

**Antes:**

```dart
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshCallItself = err.requestOptions.path == _refreshPath;
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    final hadAuthHeader = err.requestOptions.headers['Authorization'] != null;

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

**Después:**

```dart
    final isUnauthorized = err.response?.statusCode == 401;
    final isExemptPath = _refreshExemptPaths.contains(
      err.requestOptions.path,
    );
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    final hadAuthHeader = err.requestOptions.headers['Authorization'] != null;

    // Solo entra al flujo de refresh un 401 de petición autenticada aún no
    // reintentada. Un 401 sin Authorization (ej. login con credenciales
    // inválidas) no tiene sesión que refrescar; el 401 de una ruta exenta
    // o de un retry se propaga tal cual (sin loops ni rotaciones falsas).
    if (!isUnauthorized ||
        isExemptPath ||
        alreadyRetried ||
        !hadAuthHeader) {
      return super.onError(err, handler);
    }
```

## 4. `auth_repository_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Antes:**

```dart
  @override
  Future<Either<AuthFailure, void>> logout() async {
    try {
      await localDataSource.clearSession();
      return const Right(null);
    } catch (e, stackTrace) {
      logger.error(
        'Error al cerrar la sesión local',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(CacheFailure('No se pudo cerrar la sesión.'));
    }
  }
```

**Después:**

```dart
  @override
  Future<Either<AuthFailure, void>> logout() async {
    // 1. Best-effort: revocar la sesión server-side ANTES de borrar el
    //    refresh token local. Cualquier fallo acá (offline, 5xx, 401 =
    //    "token ya muerto", storage ilegible) se loguea y se sigue —
    //    el usuario no debe quedar atrapado en la app por un error de red.
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken != null &&
          refreshToken.isNotEmpty &&
          await networkInfo.isConnected) {
        await remoteDataSource.logout(refreshToken);
      }
    } catch (e, stackTrace) {
      logger.warning(
        'Logout remoto falló; se cierra la sesión local igual',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 2. El cierre local es lo único obligatorio.
    try {
      await localDataSource.clearSession();
      return const Right(null);
    } catch (e, stackTrace) {
      logger.error(
        'Error al cerrar la sesión local',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(CacheFailure('No se pudo cerrar la sesión.'));
    }
  }
```

## 5. `auth_repository_impl_test.dart` (archivo existente — actualización)

**Ruta:** `test/features/auth/data/repositories/auth_repository_impl_test.dart`

Reemplazar el `group('logout')` completo:

```dart
  group('logout', () {
    test('revoca la sesión remota y limpia la local', () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'refresh');
      mockConnected(true);
      when(
        () => mockRemoteDataSource.logout('refresh'),
      ).thenAnswer((_) async {});
      when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right(null));
      verify(() => mockRemoteDataSource.logout('refresh')).called(1);
      verify(() => mockLocalDataSource.clearSession()).called(1);
    });

    test('si falla el logout remoto igual limpia local y retorna Right',
        () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'refresh');
      mockConnected(true);
      when(
        () => mockRemoteDataSource.logout('refresh'),
      ).thenThrow(Exception('500 del servidor'));
      when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right(null));
      verify(() => mockLocalDataSource.clearSession()).called(1);
    });

    test('sin refresh token local omite la llamada remota', () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => null);
      when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right(null));
      verifyNever(() => mockRemoteDataSource.logout(any()));
      verify(() => mockLocalDataSource.clearSession()).called(1);
    });

    test('sin conexión omite la llamada remota pero cierra sesión', () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'refresh');
      mockConnected(false);
      when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right(null));
      verifyNever(() => mockRemoteDataSource.logout(any()));
      verify(() => mockLocalDataSource.clearSession()).called(1);
    });

    test('retorna CacheFailure si falla el borrado de sesión', () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => null);
      when(
        () => mockLocalDataSource.clearSession(),
      ).thenThrow(Exception('storage bloqueado'));

      final result = await repository.logout();

      expect(result, const Left(CacheFailure('No se pudo cerrar la sesión.')));
    });
  });
```

## 6. `refresh_token_interceptor_test.dart` (archivo existente — actualización)

**Ruta:** `test/core/network/interceptors/refresh_token_interceptor_test.dart`

Agregar al describe existente, reutilizando los helpers del archivo
(`_makeDioException`/harness propio):

```dart
    test(
      'un 401 de /auth/logout se propaga sin intentar refresh ni limpiar',
      () async {
        // El 401 de logout significa "token ya muerto" — refrescar acá
        // rotaría el refresh token y dejaría una sesión huérfana.
        final err = makeDioException(
          path: '/auth/logout',
          statusCode: 401,
          headers: {'Authorization': 'Bearer token'},
        );

        await interceptor.onError(err, handler);

        verifyNever(() => mockRefreshDio.post(any(), data: any(named: 'data')));
        verifyNever(() => mockLocalDataSource.clearSession());
        verifyNever(() => mockNotifier.notifySessionExpired());
        // El error se propaga tal cual al handler.
      },
    );
```

(Ajustar nombres de helpers/mocks a los que el archivo ya usa.)

---

## Orden de aplicación recomendado

1. `i_remote_auth_datasource.dart` — firma nueva.
2. `remote_auth_datasource_impl.dart` — `POST /auth/logout`.
3. `refresh_token_interceptor.dart` — `_refreshExemptPaths`.
4. `auth_repository_impl.dart` — `logout()` reescrito.
5. `auth_repository_impl_test.dart` — grupo reescrito.
6. `refresh_token_interceptor_test.dart` — caso nuevo.

## Verificación

- `flutter analyze` + `flutter test`.
- Manual (con backend 047 desplegado): login → `SELECT` de `user_sessions`
  (fila activa) → logout en la app → `SELECT` de nuevo → `revoked=true`.
- Offline: modo avión → logout → cierra sesión local sin colgar la UI.
