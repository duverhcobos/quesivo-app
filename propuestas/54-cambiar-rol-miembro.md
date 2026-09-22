# Propuesta 54 — Cambiar rol de un miembro (UI del ⋮ → `PATCH /auth/users/:id/role`)

Cierra el módulo de usuarios: el backend ya expone `PATCH /auth/users/:id/role` (propuesta backend 063, doc `012`) y la spec de funcionalidades (§464) lo pide. La UI es espejo exacto del flujo de `setMemberStatus` (§52): item nuevo en el ⋮ → diálogo con `RoleSelectorChips` → `setMemberRole` del cubit con `busyMemberIds` → merge del `OrgMember` fresco → toast.

**Semántica de UX a comunicar**: el backend revoca las sesiones del miembro en la org al cambiarle el rol (el JWT lleva `roles`) — el diálogo lo advierte: el miembro deberá re-ingresar para operar con su rol nuevo.

## Reglas mapeadas (doc 012)

| Backend | Failure | UI |
|---|---|---|
| `400 SELF_ROLE_CHANGE` | `SelfRoleChangeFailure` (nueva) | toast error — defensivo (`isSelf` ya oculta el ⋮) |
| `400 OWNER_ROLE_CHANGE` | `OwnerRoleChangeFailure` (nueva) | toast error — defensivo (owner sin ⋮) |
| `400 LAST_ADMIN` | `LastAdminFailure` (existe) | toast error |
| `404 MEMBERSHIP_NOT_FOUND` | `MemberNotFoundFailure` (existe) | toast error (card stale) |
| `400` sin código / 403 / 429 / red | existentes | mapeo actual |
| mismo rol | — | el diálogo deshabilita Confirmar (nada que cambiar) |

---

## Resumen de archivos

| Archivo | Acción |
|---------|--------|
| `lib/features/users/data/datasources/interfaces/i_remote_users_datasource.dart` | `updateUserRole` |
| `lib/features/users/data/datasources/implementations/remote_users_datasource_impl.dart` | PATCH real |
| `lib/features/users/domain/repositories/i_users_repository.dart` | `updateUserRole` |
| `lib/features/users/data/repositories/users_repository_impl.dart` | impl + `_mapError` 400 |
| `lib/features/users/domain/failures/users_failure.dart` | `SelfRoleChangeFailure` + `OwnerRoleChangeFailure` |
| `lib/features/users/domain/use_cases/update_user_role_use_case.dart` | **nuevo** — passthrough |
| `lib/features/users/presentation/cubit/users_list_cubit.dart` | `setMemberRole` + ctor 3er dep |
| `lib/features/users/presentation/widgets/change_role_dialog.dart` | **nuevo** — chips + confirmar |
| `lib/features/users/presentation/widgets/member_actions_menu.dart` | item `role` + `onRoleChange` |
| `lib/features/users/presentation/widgets/org_member_card.dart` | pasa `onRoleChange` al menú |
| `lib/features/users/presentation/widgets/users_list_body.dart` | pasa `onRoleChange` a la card |
| `lib/features/users/presentation/screens/users_screen.dart` | `_setMemberRole` + error text |
| `lib/core/di/setup_di.dart` | provider del use case + ctor cubit |
| `lib/l10n/app_{es,en,pt}.arb` | 6 keys nuevas ×3 |
| `lib/l10n/app_localizations*.dart` | `flutter gen-l10n` (generado) |
| tests (5 archivos, ver §Tests) | specs + widget tests |
| `../Design/quesivo-design-system.yaml` | bump `1.13.0` + changelog |

---

## 1. `i_remote_users_datasource.dart` (existente — método nuevo)

```dart
  /// `PATCH /auth/users/:id/role` — cambio de rol de la membresía (doc
  /// 012). Devuelve el `OrgMemberModel` fresco. El backend revoca las
  /// sesiones del target en la org (el JWT lleva `roles` adentro).
  Future<OrgMemberModel> updateUserRole({
    required String userId,
    required UserRole role,
  });
```

## 2. `remote_users_datasource_impl.dart` (existente — impl)

```dart
  /// `PATCH /auth/users/:id/role` real (doc 012) — mismo molde que
  /// `updateUserStatus`: la org la infiere el backend del JWT.
  @override
  Future<OrgMemberModel> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    final data = await networkService.patch<Map<String, dynamic>>(
      '/auth/users/$userId/role',
      data: {'role': role.apiValue},
    );
    return OrgMemberModel.fromJson(data);
  }
```

## 3. `i_users_repository.dart` (existente — método nuevo)

```dart
  /// `PATCH /auth/users/:id/role` — cambia el rol de la membresía (doc
  /// 012). Mismo try/catch + `_mapError` que `updateUserStatus`.
  Future<Either<UsersFailure, OrgMember>> updateUserRole({
    required String userId,
    required UserRole role,
  });
```

## 4. `users_failure.dart` (existente — 2 failures nuevas)

Después de `OwnerPasswordResetFailure`, mismo molde (mensaje inline — convención del feature):

```dart
/// `400 + SELF_ROLE_CHANGE` — el admin intentó cambiar su propio rol
/// (doc 012). Defensivo: la card propia no muestra ⋮.
class SelfRoleChangeFailure extends UsersFailure {
  const SelfRoleChangeFailure() : super('No podés cambiar tu propio rol.');
}

/// `400 + OWNER_ROLE_CHANGE` — el target es dueño de la org: quitarle
/// el rol ADMIN equivale a un takeover (doc 012, propuesta backend 063).
/// Defensivo: la card del dueño no muestra ⋮.
class OwnerRoleChangeFailure extends UsersFailure {
  const OwnerRoleChangeFailure()
    : super('No se puede cambiar el rol del dueño de la organización.');
}
```

## 5. `users_repository_impl.dart` (existente — impl + mapeo)

```dart
  /// `PATCH /auth/users/:id/role` — doc 012. Ídem `updateUserStatus`.
  @override
  Future<Either<UsersFailure, OrgMember>> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }
    try {
      final member = await remoteDataSource.updateUserRole(
        userId: userId,
        role: role,
      );
      return Right(member);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado cambiando rol de membresía',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }
```

En `_mapError`, el switch de `case 400` gana dos entradas:

```dart
          'SELF_ROLE_CHANGE' => const SelfRoleChangeFailure(),
          'OWNER_ROLE_CHANGE' => const OwnerRoleChangeFailure(),
```

## 6. `update_user_role_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/use_cases/update_user_role_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Passthrough a `PATCH /auth/users/:id/role` (doc 012) — las reglas de
/// dominio (SELF/OWNER/LAST_ADMIN) son del backend; el `UserRole` ya es
/// enum válido, no hay VO que verificar acá (mismo molde que
/// `UpdateUserStatusUseCase`).
class UpdateUserRoleUseCase {
  final IUsersRepository _repository;

  UpdateUserRoleUseCase(this._repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String userId,
    required UserRole role,
  }) => _repository.updateUserRole(userId: userId, role: role);
}
```

## 7. `users_list_cubit.dart` (existente — `setMemberRole` + ctor)

El constructor gana el tercer use case:

```dart
class UsersListCubit extends Cubit<UsersListState> {
  final ListUsersUseCase _listUsers;
  final UpdateUserStatusUseCase _updateUserStatus;
  final UpdateUserRoleUseCase _updateUserRole;

  UsersListCubit(
    this._listUsers,
    this._updateUserStatus,
    this._updateUserRole,
  ) : super(const UsersListState());
```

Y el método, espejo de `setMemberStatus` (después de él):

```dart
  /// `PATCH /auth/users/:id/role` real (§54, doc 012): mismo contrato que
  /// `setMemberStatus` — busy mientras vuela, Either crudo a la screen,
  /// merge del `OrgMember` fresco en éxito, no-op defensivo si la card
  /// ya está busy. El backend revoca las sesiones del miembro en la org.
  Future<Either<UsersFailure, OrgMember>> setMemberRole(
    OrgMember member,
    UserRole role,
  ) async {
    if (state.busyMemberIds.contains(member.id)) {
      // Inalcanzable por UI (⋮ cede al loader) — ver setMemberStatus.
      return Right(member);
    }
    emit(state.copyWith(busyMemberIds: {...state.busyMemberIds, member.id}));
    final result = await _updateUserRole(userId: member.id, role: role);
    if (isClosed) return result;
    emit(
      state.copyWith(
        busyMemberIds: {...state.busyMemberIds}..remove(member.id),
      ),
    );
    switch (result) {
      case Right(value: final fresh):
        updateMember(fresh);
      case Left():
        break;
    }
    return result;
  }
```

## 8. `change_role_dialog.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/change_role_dialog.dart`

`AlertDialog` con la piel de `MemberStatusDialog` (blanco, radius 20, avatar-icono navy): preselecciona `member.role`, **Confirmar deshabilitado mientras la selección == rol actual** (nada que cambiar → ni PATCH ni toast), mensaje con el aviso de re-login.

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import 'role_selector_chips.dart';

/// Diálogo "Cambiar rol" (§54) — `RoleSelectorChips` preseleccionado al
/// rol actual del miembro; devuelve el `UserRole` nuevo si se confirmó
/// o `null` al cancelar. Confirmar deshabilitado mientras la selección
/// no cambie (no-op innecesario) y mientras el admin no elija nada.
class ChangeRoleDialog extends StatefulWidget {
  const ChangeRoleDialog({super.key, required this.member});

  final OrgMember member;

  static Future<UserRole?> show(BuildContext context, OrgMember member) {
    return showDialog<UserRole?>(
      context: context,
      builder: (_) => ChangeRoleDialog(member: member),
    );
  }

  @override
  State<ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<ChangeRoleDialog> {
  late UserRole _selected = widget.member.role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final changed = _selected != widget.member.role;

    return AlertDialog(
      backgroundColor: AppColors.quesivoWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.quesivoNavy.withValues(alpha: 0.10),
        child: const Icon(
          Icons.manage_accounts_outlined,
          color: AppColors.quesivoNavy,
          size: 24,
        ),
      ),
      title: Text(
        l10n.changeRoleTitle(widget.member.name),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.quesivoNavy,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.changeRoleMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          RoleSelectorChips(
            selected: _selected,
            onChanged: (role) => setState(() => _selected = role),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        QuesivoPrimaryButton(
          label: l10n.changeRoleConfirm,
          onPressed: changed
              ? () => Navigator.of(context).pop(_selected)
              : null,
        ),
      ],
    );
  }
}
```

> Nota de implementación: si `QuesivoPrimaryButton` no calza en `actions` (ancho), usar `FilledButton` con el estilo navy del dialog de status — revisar cómo `MemberStatusDialog` compone sus acciones y replicar exactamente.

## 9. `member_actions_menu.dart` (existente — item `role` + callback)

Nuevo campo `required this.onRoleChange` (`ValueChanged<UserRole>`), import de `change_role_dialog.dart` + `user_role.dart`, y en `_onSelected`:

```dart
      case 'role':
        // §54 — el diálogo devuelve el rol nuevo o null (canceló o no
        // cambió); la screen dispara el PATCH real.
        final role = await ChangeRoleDialog.show(context, member);
        if (role == null || !context.mounted) return;
        onRoleChange(role);
```

Nuevo item en `itemBuilder` **entre `status` y `password`** (icono `manage_accounts_outlined`, color `quesivoDarkText` — acción neutra, no destructiva):

```dart
        PopupMenuItem<String>(
          value: 'role',
          child: Row(
            children: [
              const Icon(
                Icons.manage_accounts_outlined,
                size: 20,
                color: AppColors.quesivoDarkText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.changeRoleAction,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.quesivoDarkText,
                  ),
                ),
              ),
            ],
          ),
        ),
```

## 10. `org_member_card.dart` (existente — pasa `onRoleChange`)

Nuevo campo `required this.onRoleChange` (`ValueChanged<UserRole>`) — se lo pasa al `MemberActionsMenu` junto a `onStatusToggle`/`onPasswordReset`.

## 11. `users_list_body.dart` (existente — pasa `onRoleChange`)

Nuevo campo `required this.onRoleChange` (`ValueChanged<UserRole>`) — passthrough a `OrgMemberCard`.

## 12. `users_screen.dart` (existente — `_setMemberRole` + error text)

Espejo de `_setMemberStatus`:

```dart
  /// §54 — cambio de rol REAL vía `PATCH /auth/users/:id/role`: el cubit
  /// pone la card en busy y devuelve el Either — éxito mergea el miembro
  /// fresco; error → toast con el mensaje de la regla (doc 012). El
  /// miembro queda deslogueado de la org (el backend revoca sus sesiones).
  Future<void> _setMemberRole(OrgMember member, UserRole role) async {
    final result = await context.read<UsersListCubit>().setMemberRole(
      member,
      role,
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (result) {
      case Left(value: final failure):
        QuesivoToast.error(
          context,
          message: _memberActionErrorText(l10n, failure),
        );
      case Right():
        QuesivoToast.success(
          context,
          message: l10n.memberRoleChangedFeedback(member.name),
        );
    }
  }
```

En `_memberActionErrorText` agregar antes del `_ =>`:

```dart
        SelfRoleChangeFailure() => l10n.selfRoleChangeError,
        OwnerRoleChangeFailure() => l10n.ownerRoleChangeError,
```

Y pasar `onRoleChange: _setMemberRole` al `UsersListBody`.

## 13. `setup_di.dart` (existente — DI)

```dart
  getIt.registerFactory(() => UpdateUserRoleUseCase(getIt()));
```

Y el factory de `UsersListCubit` gana el tercer argumento: `UsersListCubit(getIt(), getIt(), getIt())`.

## 14. l10n — 6 keys nuevas ×3

| Key | es | en | pt |
|---|---|---|---|
| `changeRoleAction` | "Cambiar rol" | "Change role" | "Alterar função" |
| `changeRoleTitle` | "Cambiar rol de {name}" | "Change {name}'s role" | "Alterar função de {name}" |
| `changeRoleMessage` | "El nuevo rol aplica al reingresar: la sesión actual del miembro se cerrará en esta quesería." | "The new role applies on next sign-in: the member's current session in this org will be closed." | "A nova função aplica-se no próximo acesso: a sessão atual do membro nesta organização será encerrada." |
| `changeRoleConfirm` | "Cambiar" | "Change" | "Alterar" |
| `memberRoleChangedFeedback` | "Rol de {name} actualizado" | "{name}'s role updated" | "Função de {name} atualizada" |
| `selfRoleChangeError` | "No podés cambiar tu propio rol" | "You can't change your own role" | "Você não pode alterar a própria função" |
| `ownerRoleChangeError` | "No se puede cambiar el rol del dueño" | "Can't change the owner's role" | "Não é possível alterar a função do proprietário" |

Tras editar los `.arb`: `flutter gen-l10n` (los `app_localizations*.dart` generados se commitean, como en §52).

## 15. Tests

| Archivo | Qué agregar |
|---------|-------------|
| `test/features/users/data/repositories/users_repository_impl_test.dart` | grupo `updateUserRole`: sin conexión, éxito, `400 + SELF_ROLE_CHANGE`, `400 + OWNER_ROLE_CHANGE`, `400 + LAST_ADMIN`, `400` sin código, `404 + MEMBERSHIP_NOT_FOUND`, 403, 429 |
| `test/features/users/domain/use_cases/update_user_role_use_case_test.dart` | **nuevo** — passthrough + propaga failure (molde `update_user_status_use_case_test.dart`) |
| `test/features/users/presentation/cubit/users_list_cubit_test.dart` | grupo `setMemberRole`: éxito (busy→merge→busy off), failure, no-op busy, isClosed — molde `setMemberStatus` |
| `test/features/users/presentation/widgets/change_role_dialog_test.dart` | **nuevo** — preselecciona el rol actual, Confirmar deshabilitado sin cambio / habilitado al elegir otro, devuelve `UserRole` al confirmar, null al cancelar |
| `test/features/users/presentation/widgets/org_member_card_test.dart` | el ⋮ muestra "Cambiar rol" y devuelve el rol elegido |
| `test/features/users/presentation/screens/users_screen_test.dart` | "cambiar rol desde el menú dispara el PATCH real vía setMemberRole" — molde del test de suspender |

`MockUpdateUserRoleUseCase` nuevo en `users_list_cubit_test.dart` + tercer arg del ctor en todos los `UsersListCubit(...)` de tests existentes.

## 16. Design system — `1.12.0 → 1.13.0`

`Design/quesivo-design-system.yaml`:
- `member_actions`: nueva acción "Cambiar rol" → `ChangeRoleDialog` (chips preseleccionado, confirmar deshabilitado sin cambio, aviso de re-login) → `PATCH /auth/users/:id/role` con merge del 200.
- Changelog `1.13.0` con la entrada.

## 17. Orden de aplicación

1. `users_failure.dart` (failures nuevas)
2. `i_remote_users_datasource.dart` → `remote_users_datasource_impl.dart`
3. `i_users_repository.dart` → `users_repository_impl.dart` (impl + `_mapError`)
4. `update_user_role_use_case.dart` (nuevo)
5. `users_list_cubit.dart` (ctor + `setMemberRole`)
6. `change_role_dialog.dart` (nuevo)
7. `member_actions_menu.dart` → `org_member_card.dart` → `users_list_body.dart` → `users_screen.dart` (cadena `onRoleChange`)
8. `setup_di.dart`
9. `.arb` ×3 + `flutter gen-l10n`
10. Tests
11. `dart format` + `flutter analyze` + `flutter test`
12. design-system yaml `1.13.0`
