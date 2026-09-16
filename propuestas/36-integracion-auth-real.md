# Propuesta 36 — Integración auth real: `register` contra `quesivo-api`

Primera integración backend↔frontend. El contrato real es
`documentacion/api/auth/001-post-register.md`.

**Side effect inevitable (y deseado)**: la URL base del env `dev` es
compartida — al apuntarla al backend local, `login` deja de funcionar contra
DummyJSON. Esta propuesta lo cubre: `login` pasa a real en el mismo cambio
(mismo endpoint contract `002-post-login.md` — es gratis, comparten model).

`refresh`/`logout`/`me` reales van en la propuesta siguiente (el interceptor
de refresh ya existe en `core/network/interceptors/`).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `core/constants/environment/environment.dart` | `dev` → backend local via `API_URL` dart-define |
| `features/auth/domain/entities/user.dart` | + `organizationId`, `organizationName`, `roles` |
| `features/auth/data/models/user_model.dart` | `fromJson` al contrato real; `toJson` alineado |
| `features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | Register/login siempre reales; mocks dev fuera |
| `features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart` | Persistir org en el perfil cacheado |
| Tests afectados | `user_model` / `auth_repository_impl` / cubits |

## 1. `environment.dart` — dev apunta al backend real

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000', // emulador Android → localhost del host
);
```

`urlAuth` dev: `apiBaseUrl`. stg/prod quedan como placeholders (sin URL real
todavía — se llenan cuando exista deploy). Documentar en `ENVIRONMENTS.md`:
`flutter run --dart-define=API_URL=http://192.168.x.x:3000` para dispositivo
físico en LAN.

## 2. `user.dart` (entity) — campos de tenant

```dart
class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? token;
  final String? refreshToken;
  final String? organizationId;
  final String? organizationName;
  final List<String> roles;
  // constructor + props actualizados
}
```

El header del shell (`shell_header.dart`) muestra el subtítulo de la org —
ya tiene la fuente en la entity.

## 3. `user_model.dart` — contrato real (001/002)

```dart
factory UserModel.fromJson(Map<String, dynamic> json) {
  return UserModel(
    id: json['id']?.toString() ?? '',
    email: json['email'] ?? '',
    name: json['name'] ?? '',
    token: json['accessToken'],
    refreshToken: json['refreshToken'],
    organizationId: json['organizationId'],
    organizationName: json['organizationName'],
    roles:
        (json['roles'] as List?)?.map((e) => e as String).toList() ?? const [],
  );
}
```

`toJson` con las mismas claves (sirve para el cache de sesión).
El parsing DummyJSON (`firstName`/`lastName`/`token`) se **elimina** — un
solo contrato.

## 4. `remote_auth_datasource_impl.dart` — sin mocks en register/login

- `register`: eliminar la rama dev-mock — siempre `POST /auth/register` con
  `{organizationName, name, email, password}` (ya estaba escrito, queda el
  único camino).
- `loginWithEmailPassword`: eliminar el hack `username` de DummyJSON —
  siempre `{email, password}`.
- `loginWithGoogle`/`forgotPassword`/`resetPassword`: mocks dev se quedan
  (esos endpoints aún no existen en el backend).

## 5. `secure_local_auth_datasource_impl.dart` — cachear la org

`saveUserSession` persiste `organizationId`/`organizationName`/`roles`
además de id/email/name — así el header del shell muestra la org al reabrir
la app sin esperar a `/me`.

## 6. Sin cambios (verificado)

- `register_screen` / `register_cubit` — el flujo success →
  `AuthCubit.checkSession()` → `AuthGuard` → `/home` ya está cableado.
- DI — `DioNetworkServiceImpl` + `AuthApiService` ya inyectan
  `Environment.urlAuth`.
- Navegación — `router.go` ya resuelve la rama del shell.

## 7. Tests a actualizar

- `user_model` — `fromJson`/`toJson` con el shape real (incl. roles vacíos
  y org ausentes en respuestas sin org).
- `auth_repository_impl_test` — el mock del datasource devuelve UserModel
  con org/roles; caso 409 → `EmailAlreadyInUseFailure` ya cubierto.
- `register_cubit_test` / `auth_cubit_test` — ajustar el UserModel esperado
  si construyen uno inline.

## Verificación

1. Backend corriendo (`npm run start:dev`, migraciones en `app_db`).
2. `flutter run --dart-define=ENV=dev` (default `API_URL=http://10.0.2.2:3000`).
3. Registro real desde el emulador → queda autenticado en `/home` con el
   subtítulo de la org en el header → verificar fila en `organization` +
   `user` + `user_profile` + `user_role` en la BD.
4. `flutter analyze` + `flutter test` verdes.

## Follow-ups (propuesta siguiente)

- `refresh`/`logout`/`me` reales: interceptor 401→refresh contra
  `user_session`, logout llamando al endpoint, `/me` en `checkAuthStatus`
  para detectar suspensión.
- `ENVIRONMENTS.md` + skill `environments-secrets`: documentar `API_URL`.
