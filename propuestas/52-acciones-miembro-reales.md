# Propuesta 52 — Acciones de miembro reales (PATCH status + password)

Conectar las acciones de fila del ⋮ con el backend real: `PATCH /auth/users/:id/status` (suspender/reactivar — doc 009, backend 052) y `PATCH /auth/users/:id/password` (reset manual — doc 010, backend 053). Mueren los flips locales optimistas de §45.

Además:

- `INetworkService` gana `patch<T>` (no existía — los dos primeros PATCH del proyecto).
- `UsersListBody` se extrae de `users_screen.dart` por la regla de tamaño de archivo (la screen quedó en ~440 líneas).
- La card propia del admin (`isSelf`) pierde el ⋮: suspenderse es `SELF_SUSPENSION` garantizado y resetearse revocaría la sesión propia.
- Mientras un PATCH de fila está en vuelo (`isBusy`), el ⋮ cede a un `QuesivoLoader` chico navy — segunda acción sobre la misma card es no-op.
- `ResetPasswordSheet` pasa a cubit real (`ResetPasswordCubit`, registerFactory) con `PopScope` durante el submit y la pausa de éxito, y `AnimationStyle.reverseDuration` 450ms para una salida más suave.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/network/interfaces/i_network_service.dart` | `patch<T>` nuevo |
| `lib/core/network/implementations/dio_network_service_impl.dart` | impl Dio del `patch` |
| `lib/core/network/implementations/http_network_service_impl.dart` | impl http del `patch` |
| `lib/features/users/domain/failures/users_failure.dart` | 5 failures nuevos (SELF_SUSPENSION, OWNER_SUSPENSION, LAST_ADMIN, OWNER_PASSWORD_RESET, MEMBERSHIP_NOT_FOUND) |
| `lib/features/users/domain/repositories/i_users_repository.dart` | `updateUserStatus` + `updateUserPassword` |
| `lib/features/users/domain/use_cases/update_user_status_use_case.dart` | **nuevo** |
| `lib/features/users/domain/use_cases/update_user_password_use_case.dart` | **nuevo** (re-valida `TempPassword`) |
| `lib/features/users/data/datasources/interfaces/i_remote_users_datasource.dart` | 2 métodos nuevos |
| `lib/features/users/data/datasources/implementations/remote_users_datasource_impl.dart` | PATCH `/status` + `/password` |
| `lib/features/users/data/repositories/users_repository_impl.dart` | impl + mapeo 400 errorCodes |
| `lib/features/users/presentation/cubit/reset_password_cubit.dart` | **nuevo** |
| `lib/features/users/presentation/cubit/reset_password_state.dart` | **nuevo** |
| `lib/features/users/presentation/cubit/users_list_cubit.dart` | `setMemberStatus` + dep `UpdateUserStatusUseCase` |
| `lib/features/users/presentation/cubit/users_list_state.dart` | `busyMemberIds` |
| `lib/features/users/presentation/widgets/users_list_body.dart` | **nuevo** (extraído del screen) |
| `lib/features/users/presentation/widgets/org_member_card.dart` | `isSelf`/`isBusy` + loader en vez de ⋮ |
| `lib/features/users/presentation/widgets/member_actions_menu.dart` | `onPasswordReset` → `ValueChanged<OrgMember>` |
| `lib/features/users/presentation/widgets/reset_password_sheet.dart` | cubit real + PopScope + salida 450ms |
| `lib/features/users/presentation/screens/users_screen.dart` | `_setMemberStatus` async real + `_memberActionErrorText` + `dartz hide State` |
| `lib/core/di/setup_di.dart` | 2 use cases + `ResetPasswordCubit` + `UsersListCubit` con 2 deps |
| `lib/l10n/app_{es,en,pt}.arb` | 5 keys nuevas de errores de regla |
| `test/.../users_list_cubit_test.dart` | mock del segundo use case |
| `test/.../users_screen_test.dart` | `MockAuthCubit` + reescrito el test de suspender + test de failure |
| `test/.../reset_password_sheet_test.dart` | reescrito contra `MockCubit` (devuelve `OrgMember?`) |

---

## 1. `update_user_status_use_case.dart` (nuevo)

**Ruta:** `lib/features/users/domain/use_cases/update_user_status_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Caso de Uso: activar/suspender la membresía de un miembro
/// (`PATCH /auth/users/:id/status`, doc 009 — propuesta backend 052).
/// Las reglas SELF_SUSPENSION/OWNER_SUSPENSION/LAST_ADMIN son del
/// backend — el dominio solo transporta; la UI ya no ofrece el ⋮ al
/// dueño ni a la card propia.
class UpdateUserStatusUseCase {
  final IUsersRepository repository;

  const UpdateUserStatusUseCase(this.repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String userId,
    required MemberStatus status,
  }) {
    return repository.updateUserStatus(userId: userId, status: status);
  }
}
```

## 2. `update_user_password_use_case.dart` (nuevo)

**Ruta:** `lib/features/users/domain/use_cases/update_user_password_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';
import '../value_objects/temp_password.dart';

/// Caso de Uso: reset manual de la contraseña de un miembro por el
/// admin (`PATCH /auth/users/:id/password`, doc 010 — propuesta backend
/// 053). Re-valida con el VO como única fuente de verdad — la sheet ya
/// valida, pero el dominio no confía en la UI (mismo patrón que
/// `CreateUserUseCase` con `TempPassword.dirty`).
class UpdateUserPasswordUseCase {
  final IUsersRepository repository;

  const UpdateUserPasswordUseCase(this.repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String userId,
    required String password,
  }) {
    if (TempPassword.dirty(password).isNotValid) {
      return Future.value(const Left(InvalidMemberDataFailure()));
    }
    return repository.updateUserPassword(userId: userId, password: password);
  }
}
```

## 3. `reset_password_cubit.dart` + `reset_password_state.dart` (nuevos)

**Rutas:** `lib/features/users/presentation/cubit/reset_password_{cubit,state}.dart`

Mismo molde que `LinkUserCubit`/`LinkUserState` (§48): `FormzSubmissionStatus`, anti doble-tap por `isInProgress`, guard `isClosed`, `resetStatus()` para limpiar el failure al editar el campo, y `resetMember` con el `OrgMember` del 200.

```dart
// state
class ResetPasswordState extends Equatable {
  final FormzSubmissionStatus status;
  final OrgMember? resetMember;
  final UsersFailure? failure;
  const ResetPasswordState({
    this.status = FormzSubmissionStatus.initial,
    this.resetMember,
    this.failure,
  });
  @override
  List<Object?> get props => [status, resetMember, failure];
}

// cubit
class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final UpdateUserPasswordUseCase _updateUserPassword;
  ResetPasswordCubit(this._updateUserPassword)
    : super(const ResetPasswordState());

  Future<void> submit({required String userId, required String password}) async {
    if (state.status.isInProgress) return;
    emit(const ResetPasswordState(status: FormzSubmissionStatus.inProgress));
    final result = await _updateUserPassword(userId: userId, password: password);
    if (isClosed) return;
    result.fold(
      (failure) => emit(ResetPasswordState(
          status: FormzSubmissionStatus.failure, failure: failure)),
      (member) => emit(ResetPasswordState(
          status: FormzSubmissionStatus.success, resetMember: member)),
    );
  }

  void resetStatus() {
    if (state.status.isFailure) emit(const ResetPasswordState());
  }
}
```

## 4. `users_list_body.dart` (nuevo — extracción)

**Ruta:** `lib/features/users/presentation/widgets/users_list_body.dart`

Todo el `_buildBody` del screen sale a un widget propio (regla de tamaño). Recibe `state`, `scrollController`, `sheetTopInset` y los dos callbacks de fila. Adentro resuelve `selfId` leyendo `AuthCubit` por `context.select` — por eso el test necesita `BlocProvider<AuthCubit>` sobre el árbol.

```dart
final selfId = context.select<AuthCubit, String?>(
  (c) => c.state is AuthSuccess ? (c.state as AuthSuccess).user.id : null,
);
// ...
OrgMemberCard(
  member: member,
  isSelf: member.id == selfId,
  isBusy: state.busyMemberIds.contains(member.id),
  onStatusToggle: (s) => onStatusToggle(member, s),
  onPasswordReset: onPasswordReset,
  sheetTopInset: sheetTopInset,
)
```

## 5. `users_list_state.dart` — `busyMemberIds`

**Ruta:** `lib/features/users/presentation/cubit/users_list_state.dart`

**Después** — campo nuevo + `copyWith` + `props`:

```dart
/// IDs de miembros con una acción de fila en vuelo (PATCH status) —
/// la card muestra un QuesivoLoader chico en vez del ⋮ mientras tanto.
final Set<String> busyMemberIds;
```

## 6. `users_list_cubit.dart` — `setMemberStatus`

**Ruta:** `lib/features/users/presentation/cubit/users_list_cubit.dart`

El cubit gana la dep `UpdateUserStatusUseCase` y el método que marca la card busy, pega el PATCH y mergea el ítem del 200 vía `updateMember`:

```dart
Future<Either<UsersFailure, OrgMember>> setMemberStatus(
  OrgMember member,
  MemberStatus status,
) async {
  if (state.busyMemberIds.contains(member.id)) {
    return const Left(UsersServerFailure());
  }
  emit(state.copyWith(busyMemberIds: {...state.busyMemberIds, member.id}));
  final result = await _updateUserStatus(userId: member.id, status: status);
  if (isClosed) return result;
  emit(state.copyWith(busyMemberIds: {...state.busyMemberIds}..remove(member.id)));
  switch (result) {
    case Right(value: final fresh): updateMember(fresh);
    case Left(): break;
  }
  return result;
}
```

## 7. `users_failure.dart` — 5 reglas nuevas

**Ruta:** `lib/features/users/domain/failures/users_failure.dart`

`SelfSuspensionFailure`, `OwnerSuspensionFailure`, `LastAdminFailure`, `OwnerPasswordResetFailure` (400 + errorCode) y `MemberNotFoundFailure` (404 — distinto de `UserNotFoundFailure` del link).

## 8. Capa data — datasource + repositorio

- `IUsersRepository` / `RemoteUsersDatasourceImpl`: `updateUserStatus` y `updateUserPassword` devuelven el `OrgMemberModel` del 200.
- `_mapError` gana el caso `400` con el switch por `errorCode` (`SELF_SUSPENSION`, `OWNER_SUSPENSION`, `LAST_ADMIN`, `OWNER_PASSWORD_RESET`, `INVALID_PASSWORD` → `InvalidMemberDataFailure`) y `404 + MEMBERSHIP_NOT_FOUND`.

## 9. `INetworkService.patch<T>` (nuevo en core)

**Rutas:** `lib/core/network/interfaces/i_network_service.dart`, `dio_network_service_impl.dart`, `http_network_service_impl.dart`

```dart
Future<T> patch<T>(String path, {Map<String, dynamic>? data});
```

## 10. `org_member_card.dart` — `isSelf` / `isBusy`

El ⋮ solo se renderiza si `!member.isOwner && !isSelf && !isBusy`; con `isBusy` cede a `QuesivoLoader(size: 20, variant: navy)`.

## 11. `reset_password_sheet.dart` — cubit real

`ResetPasswordSheet.show` devuelve `Future<OrgMember?>` (el miembro del 200, no el password) y acepta `cubit:` como seam de tests. Adentro: `BlocConsumer` con toast de error sobre el overlay raíz, `PopScope(canPop: !isBusy)` (submit + pausa de éxito), `QuesivoCloseButton(enabled: !isBusy)`, y `sheetAnimationStyle` con `reverseDuration: 450ms`.

## 12. `users_screen.dart` — screen como composición

- `_setMemberStatus` pasa a `async` y delega al cubit; traduce failures con `_memberActionErrorText` (SELF_SUSPENSION/OWNER_*/LAST_ADMIN/MEMBERSHIP_NOT_FOUND/FORBIDDEN/429/red → keys l10n).
- `_resetMemberPassword(OrgMember)` — el sheet ya hizo el PATCH; acá solo queda el toast `passwordResetFeedback`.
- El body sale a `UsersListBody` (extracción §52).
- **Fix de compilación:** `import 'package:dartz/dartz.dart' hide State;` — dartz exporta su propia mónada `State<S,A>` que choca con `State<T>` de Flutter. Primer archivo del proyecto que combina `StatefulWidget` + `Either`.

## 13. `setup_di.dart`

```dart
locator.registerLazySingleton(() => UpdateUserStatusUseCase(locator<IUsersRepository>()));
locator.registerLazySingleton(() => UpdateUserPasswordUseCase(locator<IUsersRepository>()));
locator.registerFactory(() => users_reset_password.ResetPasswordCubit(
    locator<UpdateUserPasswordUseCase>())); // prefijo: auth ya tiene ResetPasswordCubit
locator.registerFactory(() => UsersListCubit(
    locator<ListUsersUseCase>(), locator<UpdateUserStatusUseCase>()));
```

## 14. i18n — 5 keys nuevas (los 3 `.arb`)

`selfSuspensionError`, `ownerSuspensionError`, `lastAdminError`, `ownerPasswordResetError`, `memberNotFoundError`. Ejecutar `flutter gen-l10n`.

## 15. Tests

- `users_list_cubit_test.dart` — `MockUpdateUserStatusUseCase` como segundo arg.
- `users_screen_test.dart` — `MockAuthCubit` con `BlocProvider.value` en `buildApp` (el body lo lee para `isSelf`); stub default de `setMemberStatus` que responde `Right(member.copyWith(status))`; test de suspender verifica la llamada real + toast; test nuevo de `LastAdminFailure` → toast mapeado sin flip.
- `reset_password_sheet_test.dart` — reescrito contra `MockResetPasswordCubit` (broadcast stream), cubre render, validación débil, submit, inProgress, success→pop con `OrgMember`, failure→toast sin pop, cancelar.

---

## Orden de aplicación

1. `INetworkService.patch` + impls (Dio/http)
2. `users_failure.dart` + `i_users_repository.dart` + use cases
3. `i_remote_users_datasource.dart` + impl + `users_repository_impl.dart`
4. `reset_password_state/cubit`, `users_list_state/cubit`
5. `users_list_body.dart`, `org_member_card.dart`, `member_actions_menu.dart`, `reset_password_sheet.dart`
6. `users_screen.dart`
7. `setup_di.dart` + ARB ×3 + `flutter gen-l10n`
8. Tests
