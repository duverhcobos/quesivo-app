# Propuesta: Integrar `GET /auth/me` real en `checkAuthStatus`

Hoy `checkAuthStatus` solo lee el storage local — restaura sesión sin
validarla contra el backend. Con el refresh ya cableado (038/039), llamar
a `/auth/me` al restaurar sesión es el punto natural donde:

- Se **ejercita el refresh de verdad** (access token expirado → 401 →
  refresh transparente → retry → 200, sin que el usuario note nada).
- Se detecta **cuenta suspendida** a tiempo (`status: "suspended"` llega
  con 200 — la app debe desloguear según `005-get-me.md`).
- Se **refresca el perfil cacheado** (nombre, `organizationName`, roles)
  si cambió del lado del servidor.

Contrato (`documentacion/api/auth/005-get-me.md`): `GET /auth/me` con
Bearer → `{id, email, name, roles, organizationId, organizationName,
status, lastLoginAt}`. 401 → JWT inválido/expirado o usuario eliminado.
El `AuthInterceptor` ya inyecta el Bearer; el `RefreshTokenInterceptor`
ya maneja el 401 → refresh → retry transparente.

Decisiones de degradación (offline-first razonable para el MVP):

- **Sin conectividad** → se devuelve la sesión cacheada (la app sigue
  entrando; el próximo request autenticado ejercita refresh o expira).
- **401 tras refresh fallido** → `NoSessionFailure` (el interceptor ya
  limpió storage y notificó al cubit).
- **5xx / rate limit / error inesperado** → se devuelve la sesión
  cacheada (transitorio, no matar la sesión).
- **`status: "suspended"`** → `clearSession()` + `AccountSuspendedFailure`
  (la cuenta murió del lado del servidor aunque los tokens vivan).
- Cubit: sin cambios — cualquier failure ya mapea a `AuthInitial` en
  `checkSession` (redirect a welcome silencioso; mensaje "cuenta
  suspendida" queda como mejora futura).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/entities/user.dart` | Campo `status` + props |
| `lib/features/auth/data/models/user_model.dart` | `status` en ctor/fromJson/toJson |
| `lib/features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart` | `status` en profileOnly y rebuild de getUserSession |
| `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart` | Método `getMe()` |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | `getMe()` real via networkService.get |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | `checkAuthStatus` con validación remota + degradación |
| `test/features/auth/data/repositories/auth_repository_impl_test.dart` | Actualizar grupo checkAuthStatus + casos nuevos |

Sin cambios de DI (método nuevo sobre datasource ya registrado), sin i18n,
sin dependencias nuevas.

---

## 1. user.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/domain/entities/user.dart`

**Antes:**

```dart
  /// Roles del usuario en su organización (`ADMIN`/`OPERADOR` en F0).
  final List<String> roles;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.token,
    this.refreshToken,
    this.organizationId,
    this.organizationName,
    this.roles = const [],
  });
```

**Después:**

```dart
  /// Roles del usuario en su organización (`ADMIN`/`OPERADOR` en F0).
  final List<String> roles;

  /// Estado de la cuenta según `GET /auth/me`: `active`,
  /// `pending_verification` o `suspended`. Null en respuestas que no lo
  /// traen (login/register no lo incluyen) — nunca asumirlo "active".
  final String? status;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.token,
    this.refreshToken,
    this.organizationId,
    this.organizationName,
    this.roles = const [],
    this.status,
  });
```

**Antes:**

```dart
  List<Object?> get props => [
    id,
    email,
    name,
    token,
    refreshToken,
    organizationId,
    organizationName,
    roles,
  ];
```

**Después:**

```dart
  List<Object?> get props => [
    id,
    email,
    name,
    token,
    refreshToken,
    organizationId,
    organizationName,
    roles,
    status,
  ];
```

## 2. user_model.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/models/user_model.dart`

**Antes:**

```dart
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    super.token,
    super.refreshToken,
    super.organizationId,
    super.organizationName,
    super.roles,
  });
```

**Después:**

```dart
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    super.token,
    super.refreshToken,
    super.organizationId,
    super.organizationName,
    super.roles,
    super.status,
  });
```

**Antes** (en `fromJson`):

```dart
      roles:
          (json['roles'] as List?)?.map((e) => e as String).toList() ??
          const [],
    );
```

**Después:**

```dart
      roles:
          (json['roles'] as List?)?.map((e) => e as String).toList() ??
          const [],
      status: json['status'],
    );
```

**Antes** (en `toJson`):

```dart
      'organizationName': organizationName,
      'roles': roles,
    };
```

**Después:**

```dart
      'organizationName': organizationName,
      'roles': roles,
      'status': status,
    };
```

## 3. secure_local_auth_datasource_impl.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart`

**Antes** (en `saveUserSession`):

```dart
    final profileOnly = UserModel(
      id: user.id,
      email: user.email,
      name: user.name,
      organizationId: user.organizationId,
      organizationName: user.organizationName,
      roles: user.roles,
    );
```

**Después:**

```dart
    final profileOnly = UserModel(
      id: user.id,
      email: user.email,
      name: user.name,
      organizationId: user.organizationId,
      organizationName: user.organizationName,
      roles: user.roles,
      status: user.status,
    );
```

**Antes** (en `getUserSession`, el rebuild):

```dart
      return UserModel(
        id: profile.id,
        email: profile.email,
        name: profile.name,
        organizationId: profile.organizationId,
        organizationName: profile.organizationName,
        roles: profile.roles,
        token: token,
        refreshToken: refreshToken,
      );
```

**Después:**

```dart
      return UserModel(
        id: profile.id,
        email: profile.email,
        name: profile.name,
        organizationId: profile.organizationId,
        organizationName: profile.organizationName,
        roles: profile.roles,
        status: profile.status,
        token: token,
        refreshToken: refreshToken,
      );
```

## 4. i_remote_auth_datasource.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart`

**Antes:**

```dart
  /// Envía la nueva contraseña + token a `POST /auth/reset-password`.
  Future<void> resetPassword({required String token, required String password});
}
```

**Después:**

```dart
  /// Envía la nueva contraseña + token a `POST /auth/reset-password`.
  Future<void> resetPassword({required String token, required String password});

  /// Perfil fresco del usuario autenticado desde `GET /auth/me`
  /// (`documentacion/api/auth/005-get-me.md`). Incluye `status` leído de
  /// BD. El Bearer lo inyecta AuthInterceptor; un 401 dispara el refresh
  /// automático del RefreshTokenInterceptor antes de llegar acá.
  Future<UserModel> getMe();
}
```

## 5. remote_auth_datasource_impl.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

**Antes:**

```dart
    await networkService.post<void>(
      '/auth/reset-password',
      data: {'token': token, 'password': password},
    );
  }
}
```

**Después:**

```dart
    await networkService.post<void>(
      '/auth/reset-password',
      data: {'token': token, 'password': password},
    );
  }

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

## 6. auth_repository_impl.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Antes:**

```dart
  @override
  Future<Either<AuthFailure, User>> checkAuthStatus() async {
    try {
      final userModel = await localDataSource.getUserSession();
      if (userModel != null) {
        return Right(userModel);
      } else {
        return const Left(NoSessionFailure()); // No session found
      }
    } catch (e, stackTrace) {
      logger.warning(
        'Error leyendo sesión local de flutter_secure_storage',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure('Error leyendo sesión local'));
    }
  }
```

**Después:**

```dart
  @override
  Future<Either<AuthFailure, User>> checkAuthStatus() async {
    late final UserModel local;
    try {
      final session = await localDataSource.getUserSession();
      if (session == null) {
        return const Left(NoSessionFailure()); // No session found
      }
      local = session;
    } catch (e, stackTrace) {
      logger.warning(
        'Error leyendo sesión local de flutter_secure_storage',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error leyendo sesión local'));
    }

    // Hay sesión local: sin conectividad se degrada a ella (la app entra
    // igual; el próximo request autenticado ejercita refresh o expira).
    if (!await networkInfo.isConnected) {
      return Right(local);
    }

    // Validación remota: perfil fresco + status real de la cuenta
    // (documentacion/api/auth/005-get-me.md).
    try {
      final fresh = await remoteDataSource.getMe();

      // 'suspended' llega con 200: la cuenta murió del lado del servidor
      // aunque los tokens sigan vivos — sesión inválida igual.
      if (fresh.status == 'suspended') {
        await localDataSource.clearSession();
        return const Left(AccountSuspendedFailure());
      }

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
      // 5xx, rate limit, etc.: transitorio — conservar sesión local.
      logger.warning(
        'GET /auth/me falló; se conserva la sesión cacheada',
        error: e,
        stackTrace: stackTrace,
      );
      return Right(local);
    } catch (e, stackTrace) {
      logger.warning(
        'Error inesperado validando sesión; se conserva la cacheada',
        error: e,
        stackTrace: stackTrace,
      );
      return Right(local);
    }
  }
```

*(imports: `UserModel` ya está importado — el método usa `remoteDataSource`
ya inyectado; verificar que `UnauthorizedException` esté cubierto por el
import de `auth_exceptions.dart` que ya existe)*

## 7. auth_repository_impl_test.dart (archivo existente — actualización)

**Ruta:** `test/features/auth/data/repositories/auth_repository_impl_test.dart`

El grupo `checkAuthStatus` pasa a necesitar stubs de `networkInfo` +
`getMe`. Reemplazar el grupo completo:

**Antes:**

```dart
  group('checkAuthStatus', () {
    test('retorna Right(user) si hay una sesión local guardada', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);

      final result = await repository.checkAuthStatus();

      expect(result, const Right(tUserModel));
    });

    test('retorna NoSessionFailure si no hay sesión guardada', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => null);

      final result = await repository.checkAuthStatus();

      expect(result, const Left(NoSessionFailure()));
    });

    test('retorna ServerFailure si falla la lectura local', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenThrow(Exception('storage corrupto'));

      final result = await repository.checkAuthStatus();

      expect(result, const Left(ServerFailure('Error leyendo sesión local')));
    });
  });
```

**Después:**

```dart
  group('checkAuthStatus', () {
    const tFreshModel = UserModel(
      id: '1',
      email: tEmail,
      name: 'John Doe',
      organizationId: 'org-1',
      organizationName: 'Quesera Test',
      roles: ['ADMIN'],
      status: 'active',
    );

    setUp(() {
      when(
        () => mockNetworkInfo.isConnected,
      ).thenAnswer((_) async => true);
      when(
        () => mockRemoteDataSource.getMe(),
      ).thenAnswer((_) async => tFreshModel);
      when(
        () => mockLocalDataSource.saveUserSession(any()),
      ).thenAnswer((_) async {});
    });

    test('retorna perfil fresco y refresca el cache local', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);

      final result = await repository.checkAuthStatus();

      result.fold(
        (_) => fail('debía ser Right'),
        (user) {
          expect(user.name, 'John Doe');
          expect(user.organizationName, 'Quesera Test');
          expect(user.status, 'active');
          expect(user.token, tUserModel.token); // tokens se conservan
        },
      );
      verify(() => mockLocalDataSource.saveUserSession(any())).called(1);
    });

    test('retorna sesión local sin conectividad (sin llamar remoto)',
        () async {
      when(
        () => mockNetworkInfo.isConnected,
      ).thenAnswer((_) async => false);
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);

      final result = await repository.checkAuthStatus();

      expect(result, const Right(tUserModel));
      verifyNever(() => mockRemoteDataSource.getMe());
    });

    test('retorna sesión local si /auth/me da error transitorio (5xx)',
        () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);
      when(() => mockRemoteDataSource.getMe()).thenThrow(
        RestApiException(statusCode: 500, message: 'server error'),
      );

      final result = await repository.checkAuthStatus();

      expect(result, const Right(tUserModel));
    });

    test('retorna NoSessionFailure si /auth/me da 401 (refresh falló)',
        () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockRemoteDataSource.getMe(),
      ).thenThrow(UnauthorizedException());

      final result = await repository.checkAuthStatus();

      expect(result, const Left(NoSessionFailure()));
    });

    test('status suspended limpia sesión y devuelve AccountSuspendedFailure',
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
      ).thenAnswer((_) async {});

      final result = await repository.checkAuthStatus();

      expect(result, const Left(AccountSuspendedFailure()));
      verify(() => mockLocalDataSource.clearSession()).called(1);
      verifyNever(() => mockLocalDataSource.saveUserSession(any()));
    });

    test('retorna NoSessionFailure si no hay sesión guardada', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => null);

      final result = await repository.checkAuthStatus();

      expect(result, const Left(NoSessionFailure()));
      verifyNever(() => mockRemoteDataSource.getMe());
    });

    test('retorna ServerFailure si falla la lectura local', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenThrow(Exception('storage corrupto'));

      final result = await repository.checkAuthStatus();

      expect(result, const Left(ServerFailure('Error leyendo sesión local')));
    });
  });
```

*Nota de implementación:* ajustar imports del test si falta
`UnauthorizedException`/`RestApiException`/`UserModel` (probablemente ya
están — el archivo ya importa exceptions y models). `fail()` viene de
`flutter_test`.

---

## Orden de aplicación

1. `user.dart` (campo `status`)
2. `user_model.dart` (parseo)
3. `secure_local_auth_datasource_impl.dart` (persistir `status` en el perfil cacheado)
4. `i_remote_auth_datasource.dart` (firma `getMe()`)
5. `remote_auth_datasource_impl.dart` (`getMe()` real)
6. `auth_repository_impl.dart` (`checkAuthStatus` con validación remota)
7. `auth_repository_impl_test.dart` (grupo actualizado)
8. `flutter analyze` + `flutter test` limpios.

## Verificación end-to-end posterior (cierra el ciclo con 038/039)

Con la app instalada vía `shorebird preview` apuntando a Render:

- **Sesión viva**: login → cerrar → reabrir → splash → `/auth/me` 200 →
  entra a Home con perfil fresco.
- **Refresh real**: en Render, bajar `JWT_EXPIRES_IN=1m` temporalmente →
  login → esperar 2 min → reabrir → `/auth/me` da 401 → refresh
  transparente → entra normal (esto ejercita el interceptor de verdad).
- **Sesión muerta**: en Supabase `DELETE FROM user_sessions WHERE
  user_id='...'` → reabrir → refresh 401 → app cae a Welcome sola.
- **Suspendida**: `UPDATE users SET status='suspended' WHERE id='...'` →
  reabrir → desloguea a Welcome.
