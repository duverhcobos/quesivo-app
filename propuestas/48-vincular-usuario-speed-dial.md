# Propuesta 48 — Vincular usuario existente: speed dial FAB + LinkUserSheet

**Estado:** Propuesta — pendiente de implementación
**Fecha:** 2026-09-20
**Depende de:** propuesta backend 058 (`POST /auth/users` rechaza email
existente; `POST /auth/users/link` nuevo)

## Contexto

Backend 058 separa las dos intenciones que `POST /auth/users` fusionaba:

- **`POST /auth/users`** — solo crea. Email existente → `409
  EMAIL_ALREADY_EXISTS`.
- **`POST /auth/users/link`** — `{email, role}` → solo membresía.
  Errores: `404 USER_NOT_FOUND` / `409 USER_SUSPENDED` /
  `409 MEMBERSHIP_ALREADY_EXISTS` / `409 USER_IS_OWNER` / `403` / `429`.

El frontend gana una segunda acción explícita. UX aprobada por el
usuario: **speed dial** — el FAB amarillo se expande en dos acciones.

## Diseño

### Speed dial (reemplaza el FAB simple)

```
        ┌─────────────────────────────┐
        │ Vincular existente   (🔗)   │  ← pill blanca + círculo navy
        │ Crear usuario        (👤+) │  ← pill blanca + círculo navy
        └─────────────────────────────┘
                     (✕)             ← FAB principal amarillo, morph
                                       person_add → close
```

- Tap en el FAB → las dos acciones suben con fade+slide (~200ms) sobre
  un scrim transparente (tap afuera cierra).
- Icono del FAB morfa `person_add_outlined` → `close` cuando está
  abierto.
- Cada acción: label en pill blanca a la izquierda + mini botón
  circular navy con ícono blanco — paleta de marca.
- Misma posición que hoy (`right:24, bottom:nav+16`), sobre el overlay
  para tapar el nav igual que el FAB actual.

### `LinkUserSheet` (nuevo)

Espejo de `NewUserSheet` menos nombre/password/checklist:

- Título: "Vincular usuario" + hint explicativo.
- Campo email — `Email.allowedChars` formatter + validación en vivo
  (mismo patrón §47 — reusa `MemberEmail`).
- `RoleSelectorChips` (los 4 roles).
- Submit "Vincular" — mismo ciclo: spinner → check navy ~500ms → pop →
  toast. `PopScope` anti-cierre en vuelo, campos congelados.
- Errores del backend → `QuesivoToast.error` (igual que create).
- `LinkUserSheet.show(context, {topInset}) → Future<OrgMember?>` — la
  screen inserta el miembro al tope + toast "vinculado".

### Cadena de capas (espejo de §46)

```
LinkUserSheet → LinkUserCubit → LinkUserUseCase
  → IUsersRepository.linkUser → UsersRepositoryImpl
  → IRemoteUsersDataSource.linkUser → POST /auth/users/link
```

## Cambios por archivo

### Nuevos

**`lib/features/users/domain/failures/users_failure.dart`** — 3 clases
nuevas (mismo patrón):

```dart
/// `409 + EMAIL_ALREADY_EXISTS` (create) — el email ya tiene cuenta
/// global; la vinculación es otra acción (doc 007 post-058).
class EmailAlreadyExistsFailure extends UsersFailure {
  const EmailAlreadyExistsFailure()
    : super('Ese correo ya tiene cuenta — vinculalo como existente.');
}

/// `404 + USER_NOT_FOUND` (link) — el email no tiene cuenta global;
/// crear es la otra acción.
class UserNotFoundFailure extends UsersFailure {
  const UserNotFoundFailure()
    : super('Ese correo no tiene cuenta — crealo desde "Crear usuario".');
}

/// `409 + USER_IS_OWNER` (link) — dueño de otra org no es vinculable
/// (propuesta backend 056).
class UserIsOwnerFailure extends UsersFailure {
  const UserIsOwnerFailure()
    : super('Ese correo es dueño de otra quesera — no puede vincularse.');
}
```

**`lib/features/users/domain/use_cases/link_user_use_case.dart`** —
espejo de `CreateUserUseCase`: valida `MemberEmail` + rol elegido →
`repo.linkUser`. Sin `MemberName`/`TempPassword` (no aplican — el user
ya existe).

**`lib/features/users/presentation/cubit/link_user_cubit.dart`** +
`link_user_state.dart` — espejo de `CreateUserCubit`
(initial/inProgress/success/failure + `resetStatus`, guard `isClosed`).

**`lib/features/users/presentation/widgets/link_user_sheet.dart`** —
espejo estructural de `NewUserSheet`: mismo container/handle/✕/PopScope/
`_successDismissDelay`/fields disabled on busy; campos: email + rol;
`errorText` vivo en email.

**`lib/features/users/presentation/widgets/users_speed_dial.dart`** —
widget extraído (file-size rule): el FAB + las dos acciones animadas +
scrim. Recibe `onCreate`/`onLink` callbacks — no conoce los sheets.

### Modificados

**`i_remote_users_datasource.dart`**:
```dart
/// `POST /auth/users/link` — vincula un user global existente a la org
/// del JWT (propuesta backend 058).
Future<OrgMemberModel> linkUser({
  required String email,
  required UserRole role,
});
```

**`remote_users_datasource_impl.dart`** — implementación: `POST
$base/auth/users/link` con `{email, role}` → `OrgMemberModel.fromJson`.

**`i_users_repository.dart`** — `linkUser({email, role})` +
actualizar el doc de `createUser` ("solo crea — email existente da
`EmailAlreadyExistsFailure`; la vinculación vive en `linkUser`").

**`users_repository_impl.dart`**:
- `linkUser` — mismo try/catch de `createUser`; el switch de
  `errorCode` gana `'USER_NOT_FOUND' => UserNotFoundFailure()` y
  `'USER_IS_OWNER' => UserIsOwnerFailure()` (los 409 existentes se
  reusan).
- `createUser` — agregar `'EMAIL_ALREADY_EXISTS' =>
  EmailAlreadyExistsFailure()` al switch.

**`users_screen.dart`**:
- El `Positioned` FAB → `UsersSpeedDial(onCreate: _openNewUserSheet,
  onLink: _openLinkUserSheet)`.
- `_openLinkUserSheet()` — espejo de `_openNewUserSheet`: pop con el
  `OrgMember` → inserta al tope → scroll → `QuesivoToast.info`
  (`memberLinkedFeedback(name)` — se reusa la key de "vinculado").
- `_openNewUserSheet` — la rama `created.linked` queda muerta (create
  ya no vincula): simplificar a toast success siempre (conservar
  `OrgMember.linked` — link sí lo trae true).

**`new_user_sheet.dart`** — el mapeo failure→mensaje gana el caso
`EmailAlreadyExistsFailure` → `l10n.emailAlreadyExistsError`.

**`lib/core/di/setup_di.dart`** — registrar `LinkUserUseCase` +
`LinkUserCubit` (factory, espejo de create).

**ARBs** (`app_es/en/pt.arb`) — keys nuevas:

```json
// es
"fabCreateUser": "Crear usuario",
"fabLinkUser": "Vincular existente",
"linkUserSheetTitle": "Vincular usuario",
"linkUserSheetHint": "El correo ya tiene cuenta en Quesivo — se vincula a tu quesera y conserva su contraseña actual",
"linkUserSubmit": "Vincular",
"emailAlreadyExistsError": "Ese correo ya tiene cuenta — vinculalo desde \"Vincular existente\"",
"userNotFoundError": "Ese correo no tiene cuenta — crealo desde \"Crear usuario\"",
"userIsOwnerError": "Ese correo es dueño de otra quesera — no puede vincularse",
```
```json
// en
"fabCreateUser": "Create user",
"fabLinkUser": "Link existing",
"linkUserSheetTitle": "Link user",
"linkUserSheetHint": "The email already has a Quesivo account — it links to your organization keeping its current password",
"linkUserSubmit": "Link",
"emailAlreadyExistsError": "That email already has an account — link it from \"Link existing\"",
"userNotFoundError": "That email has no account — create it from \"Create user\"",
"userIsOwnerError": "That email owns another organization — it cannot be linked",
```
```json
// pt
"fabCreateUser": "Criar usuário",
"fabLinkUser": "Vincular existente",
"linkUserSheetTitle": "Vincular usuário",
"linkUserSheetHint": "O e-mail já tem conta no Quesivo — será vinculado à sua queijaria mantendo a senha atual",
"linkUserSubmit": "Vincular",
"emailAlreadyExistsError": "Esse e-mail já tem conta — vincule-o em \"Vincular existente\"",
"userNotFoundError": "Esse e-mail não tem conta — crie-o em \"Criar usuário\"",
"userIsOwnerError": "Esse e-mail é dono de outra queijaria — não pode ser vinculado",
```

`memberLinkedFeedback(name)` ya existe ("vinculado") — se reusa.

**`Design/quesivo-design-system.yaml`** — `users_screen` gana
`speed_dial` spec + `link_user_sheet` spec (forma menor del create
sheet) + bump `1.10.8` + changelog.

### Tests

- `link_user_sheet_test.dart` (**nuevo**) — espejo del de create:
  formatter de email, validación en vivo, error → toast, éxito → check
  ~500ms → pop con miembro, PopScope bloquea en vuelo.
- `link_user_cubit_test.dart` (**nuevo**) — success / failure /
  resetStatus.
- `users_repository_impl_test.dart` — `linkUser` happy + los 4
  errorCodes; `createUser` con `EMAIL_ALREADY_EXISTS`.
- `link_user_use_case_test.dart` (**nuevo**) — espejo del de create.
- `users_screen_test.dart` — FAB tap → las dos acciones visibles; tap
  "Vincular" → sheet abre; resultado inserta miembro + toast info.

## Orden de implementación

1. Failures → datasource → repository → use case → cubit (+DI).
2. `link_user_sheet.dart` → `users_speed_dial.dart` → screen wiring.
3. ARBs → `flutter pub get`.
4. Tests.
5. yaml → `flutter analyze` + `flutter test`.
