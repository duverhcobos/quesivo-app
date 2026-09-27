# Propuesta: Nombrar la quesera tras el signup por Google (backend 087)

Hoy `POST /auth/google` crea la org con el nombre de la cuenta Google
(verificado en BD: `cobosduver6@gmail.com` → org `Duver Cobos`) porque el
signup no tiene formulario de nombre. El backend 087 agrega:

- `isNewSignup: true` en la respuesta de `/auth/google` solo cuando fue
  **signup** (ausente en login/linked).
- `PATCH /organizations/me { name }` — renombra la org del JWT org-scoped
  (solo ADMIN).

Esta propuesta consume ambos: tras entrar a la org recién creada, la app
lleva a una pantalla **"¿Cómo se llama tu quesera?"** antes de soltar al
home.

## Flujo

```
POST /auth/google (isNewSignup: true)
  → UserModel.isNewSignup (persiste en sesión — sobrevive a restart)
  → selector → select-organization → enterOrganizationWithSession
  → AuthGuard.evaluate ve enteredOrg && user.isNewSignup
  → redirect a /organizacion/nombrar (top-level, fuera del shell)
  → formulario (pre-llenado con el nombre generado) → PATCH
  → éxito: cubit limpia el flag + actualiza organizationName en sesión
  → re-eval del guard → /home
```

**Skip**: botón "Por ahora no" que limpia el flag sin llamar el PATCH —
la org queda con el nombre generado; el mismo endpoint sirve para un
renombrado futuro desde ajustes.

**Por qué el flag en `User`**: `refreshSession()` emite `AuthSuccess`
con el user de `/auth/me` (que no trae el flag) — se preserva con
`copyWith` igual que `enteredOrg`. Persistirlo en `toJson` cubre el caso
"app cerrada entre signup y nombrado": al reabrir y entrar a la org, la
pantalla vuelve a aparecer hasta que se complete o se omita.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/entities/user.dart` | `isNewSignup` + `copyWith` |
| `lib/features/auth/data/models/user_model.dart` | parse + `toJson` |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | preservar flag en refresh + `applyOrganizationRenamed`/`skipOrgNameSetup` |
| `lib/features/organization/domain/repositories/i_organization_repository.dart` | **nuevo** |
| `lib/features/organization/domain/failures/organization_failure.dart` | **nuevo** |
| `lib/features/organization/domain/use_cases/update_organization_name_use_case.dart` | **nuevo** |
| `lib/features/organization/data/datasources/interfaces/i_remote_organization_datasource.dart` | **nuevo** |
| `lib/features/organization/data/datasources/implementations/remote_organization_datasource_impl.dart` | **nuevo** — `PATCH /organizations/me` |
| `lib/features/organization/data/repositories/organization_repository_impl.dart` | **nuevo** — PATCH + actualizar sesión cacheada |
| `lib/features/organization/presentation/cubit/org_name_setup_cubit.dart` (+ `_state.dart`) | **nuevo** |
| `lib/features/organization/presentation/screens/org_name_setup_screen.dart` | **nuevo** |
| `lib/core/routes/auth_guard.dart` | ruta + intercept en `evaluate` |
| `lib/core/routes/app_router.dart` | `GoRoute` top-level |
| `lib/core/di/setup_di.dart` | registrar datasource/repository/use-case/cubit |
| `lib/l10n/**` | strings nuevos (i18n-workflow) |
| `Design/quesivo-design-system.yaml` | pantalla nueva (design-system-docs) |
| tests | cubit / repository / datasource / guard / widget |

Feature nuevo → orden de archivos según `new-feature-checklist`.

---

## 1. `user.dart` (existente — campo)

**Ruta:** `lib/features/auth/domain/entities/user.dart`

```dart
// Agregar a la entidad User (default false) + al copyWith:
/// `true` solo en la respuesta de POST /auth/google cuando fue signup
/// (backend 087): la org recién creada lleva el nombre de la cuenta
/// Google y la app muestra la pantalla de nombrado tras entrar a ella.
final bool isNewSignup;
```

En `copyWith` incluir `isNewSignup` (preservar el actual si no se pasa —
igual que `roles`/`status`).

## 2. `user_model.dart` (existente — parse + serializar)

**Ruta:** `lib/features/auth/data/models/user_model.dart`

```dart
// En fromJson:
isNewSignup: json['isNewSignup'] == true,

// En toJson() — se persiste para que el flag sobreviva a un restart
// entre el signup y el nombrado:
'isNewSignup': isNewSignup,
```

## 3. `auth_cubit.dart` (existente — preservar + mutadores)

**Ruta:** `lib/features/auth/presentation/cubit/auth_cubit.dart`

El flag se pierde si un emit reemplaza `user` con el de `/auth/me` —
preservarlo como se hace con `enteredOrg`:

```dart
// En refreshSession() y refreshSessionSilently(), donde hoy:
//   emit(AuthSuccess(user, enteredOrg: current.enteredOrg));
emit(
  AuthSuccess(
    user.copyWith(isNewSignup: current.user.isNewSignup),
    enteredOrg: current.enteredOrg,
  ),
);
```

Y agregar:

```dart
/// PATCH /organizations/me exitoso (propuesta 71): actualiza el nombre
/// de la org en el user (selector + header) y limpia el flag — el guard
/// suelta al home en la próxima evaluación.
void applyOrganizationRenamed(String newName) {
  final current = state;
  if (current is! AuthSuccess) return;
  emit(
    AuthSuccess(
      current.user.copyWith(
        organizationName: newName,
        isNewSignup: false,
        organizations: [
          for (final o in current.user.organizations)
            o.id == current.user.organizationId
                ? OrganizationSummary(
                    id: o.id, name: newName, role: o.role)
                : o,
        ],
      ),
      enteredOrg: current.enteredOrg,
    ),
  );
}

/// "Por ahora no" en la pantalla de nombrado: limpia el flag sin PATCH —
/// la org conserva el nombre generado (renombrable después con el mismo
/// endpoint). También debe persistir el user actualizado en sesión local.
void skipOrgNameSetup() {
  final current = state;
  if (current is! AuthSuccess) return;
  emit(
    AuthSuccess(
      current.user.copyWith(isNewSignup: false),
      enteredOrg: current.enteredOrg,
    ),
  );
}
```

> `enterOrganizationWithSession` ya hace `copyWith` sobre el user actual
> → el flag se preserva solo (verificar que el `copyWith` nuevo lo cubra).

## 4. `i_remote_organization_datasource.dart` (archivo nuevo)

**Ruta:** `lib/features/organization/data/datasources/interfaces/i_remote_organization_datasource.dart`

```dart
/// PATCH /organizations/me — backend 087, doc api/organizations/001.
abstract class IRemoteOrganizationDataSource {
  /// Renombra la org del JWT org-scoped. Devuelve el nombre confirmado.
  /// Lanza UnauthorizedException / ForbiddenException / RestApiException.
  Future<String> updateCurrentName(String name);
}
```

## 5. `remote_organization_datasource_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/organization/data/datasources/implementations/remote_organization_datasource_impl.dart`

```dart
class RemoteOrganizationDataSourceImpl
    implements IRemoteOrganizationDataSource {
  RemoteOrganizationDataSourceImpl(this._network);

  final INetworkService _network;

  @override
  Future<String> updateCurrentName(String name) async {
    final response = await _network.patch(
      '/organizations/me',
      body: {'name': name},
    );
    return response['name'] as String;
  }
}
```

> Verificar la firma real de `INetworkService.patch` (vs `put`) contra
> `i_network_service.dart` y ajustar — el endpoint es `PATCH`.

## 6. `i_organization_repository.dart` (archivo nuevo)

**Ruta:** `lib/features/organization/domain/repositories/i_organization_repository.dart`

```dart
abstract class IOrganizationRepository {
  /// Renombra la org activa: PATCH + actualiza la sesión cacheada
  /// (organizationName + la entrada en `organizations` + limpia
  /// `isNewSignup`). Devuelve el nombre confirmado.
  Future<Either<OrganizationFailure, String>> updateCurrentName(
    String name,
  );
}
```

## 7. `organization_failure.dart` (archivo nuevo)

**Ruta:** `lib/features/organization/domain/failures/organization_failure.dart`

Misma familia que `AuthFailure` (sealed/variants según patrón del
proyecto): `OrganizationUpdateFailure` genérica con `message`; mapear
401/403 → "sin permiso" (un OPERATOR no debería ver esta pantalla de
todas formas — cubierto por el guard de ADMIN en backend).

## 8. `organization_repository_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/organization/data/repositories/organization_repository_impl.dart`

```dart
class OrganizationRepositoryImpl implements IOrganizationRepository {
  OrganizationRepositoryImpl(this._remote, this._localAuth);

  final IRemoteOrganizationDataSource _remote;
  final ILocalAuthDataSource _localAuth;

  @override
  Future<Either<OrganizationFailure, String>> updateCurrentName(
    String name,
  ) async {
    try {
      final newName = await _remote.updateCurrentName(name.trim());
      final session = await _localAuth.getUserSession();
      if (session != null) {
        await _localAuth.saveUserSession(
          session.copyWith(
            organizationName: newName,
            isNewSignup: false,
            organizations: [
              for (final o in session.organizations)
                o.id == session.organizationId
                    ? OrganizationSummary(
                        id: o.id, name: newName, role: o.role)
                    : o,
            ],
          ),
        );
      }
      return Right(newName);
    } on UnauthorizedException catch (e) {
      return Left(OrganizationUpdateFailure(e.message));
    } on ForbiddenException catch (e) {
      return Left(OrganizationUpdateFailure(e.message));
    } on RestApiException catch (e) {
      return Left(OrganizationUpdateFailure(e.message));
    } on NetworkException {
      return const Left(OrganizationUpdateFailure(/* i18n key offline */));
    }
  }
}
```

> `UserModel.copyWith` hereda de `User` — verificar que devuelva
> `UserModel` o castear (ver cómo lo resuelve `auth_repository_impl`).

## 9. `update_organization_name_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/organization/domain/use_cases/update_organization_name_use_case.dart`

Wrapper del repository — mismo patrón one-method que
`select_organization_use_case.dart`.

## 10. `org_name_setup_cubit.dart` + `_state.dart` (archivos nuevos)

**Rutas:** `lib/features/organization/presentation/cubit/`

```dart
class OrgNameSetupState {
  final bool isSubmitting;
  final String? errorMessage;
  const OrgNameSetupState({this.isSubmitting = false, this.errorMessage});
  OrgNameSetupState copyWith({...});
}

class OrgNameSetupCubit extends Cubit<OrgNameSetupState> {
  OrgNameSetupCubit(this._updateName, this._authCubit)
    : super(const OrgNameSetupState());

  /// PATCH → éxito: el AuthCubit aplica el nombre nuevo y limpia el
  /// flag → el guard redirige a /home solo (no navegación manual acá).
  Future<void> submit(String name) async { ... }

  /// Limpia el flag sin PATCH — la org conserva el nombre generado.
  void skip() => _authCubit.skipOrgNameSetup();
}
```

## 11. `org_name_setup_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/organization/presentation/screens/org_name_setup_screen.dart`

- `BlocProvider<OrgNameSetupCubit>` local (o via DI en la route).
- Título i18n "¿Cómo se llama tu quesera?", `TextField` **pre-llenado**
  con `state.user.organizationName` (el nombre generado) para editar
  sobre él, botón Guardar (disabled si vacío/igual), botón texto "Por
  ahora no" → `skip()`.
- Errores vía `BlocListener` → snackbar (patrón existente).
- UI según `ui-design-standard` + `frontend-design`; textos por
  `i18n-workflow`; si el archivo crece, extraer widgets por
  `file-size-refactoring`.

## 12. `auth_guard.dart` + `app_router.dart` (existentes — ruta + intercept)

**`auth_guard.dart`:**

```dart
static const String orgNameSetupRoute = '/organizacion/nombrar';
```

En `evaluate`, dentro del bloque `authState is AuthSuccess`, **después**
de establecer `hasOrgContext` y **antes** del chequeo de rutas públicas:

```dart
// Propuesta 71 — signup por Google: la org nació con el nombre de la
// cuenta; forzar el nombrado una vez entrado a la org (persistente:
// reaparece tras restart hasta completar u omitir).
if (hasOrgContext && authState.user.isNewSignup) {
  if (location != orgNameSetupRoute) return orgNameSetupRoute;
  return null;
}
```

**`app_router.dart`:** `GoRoute` **top-level** (fuera del
StatefulShellRoute — pantalla de setup sin chrome del shell):

```dart
GoRoute(
  path: AuthGuard.orgNameSetupRoute,
  builder: (context, state) => BlocProvider(
    create: (_) => getIt<OrgNameSetupCubit>(),
    child: const OrgNameSetupScreen(),
  ),
),
```

NO va en `publicRoutes` — protegida por defecto.

## 13. `setup_di.dart` (existente — registrar)

`IRemoteOrganizationDataSource` → impl (LazySingleton), 
`IOrganizationRepository` → impl (LazySingleton),
`UpdateOrganizationNameUseCase` (factory), `OrgNameSetupCubit` (factory —
recibe `AuthCubit`).

## 14. i18n + design system

- `i18n-workflow`: claves `orgNameSetup.title`, `.fieldLabel`,
  `.submit`, `.skip`, `.errorGeneric`, `.errorOffline` (es/en).
- `design-system-docs`: registrar la pantalla en
  `Design/quesivo-design-system.yaml` (version bump + changelog).

## 15. Tests (testing-workflow)

- **cubit**: `submit` éxito → `applyOrganizationRenamed` llamado;
  failure → `errorMessage`; `skip` → flag limpio.
- **repository**: PATCH ok → sesión cacheada actualizada
  (`organizationName` + entrada en `organizations` + `isNewSignup:false`);
  errores 401/403/network mapeados.
- **datasource**: `PATCH /organizations/me` con `{name}` y parse del
  response.
- **AuthGuard**: `enteredOrg && isNewSignup` → redirect al route;
  `isNewSignup` false → null; parado ya en el route → null.
- **widget**: pantalla renderiza pre-llenado, botón disabled vacío.

---

## Orden de aplicación recomendado

1. `user.dart` + `user_model.dart` (campo + parse + persist)
2. `auth_cubit.dart` (preservar flag + mutadores)
3. datasource interface + impl
4. failure + repository interface + impl
5. use-case
6. cubit + state
7. pantalla + strings i18n
8. `auth_guard` + `app_router` + `setup_di`
9. design-system yaml
10. tests
11. `flutter analyze && flutter test`

## Dependencia backend

Requiere **propuesta backend 087 aplicada** (`isNewSignup` +
`PATCH /organizations/me`). Sin el flag el flujo nunca se dispara
(compatible con backend viejo: `isNewSignup` ausente → false → nada
cambia).
