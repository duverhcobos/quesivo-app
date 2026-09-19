# Propuesta: Diálogos de acciones del miembro (solo UI)

El menú ⋮ de cada card hoy muestra "Próximamente". Esta propuesta lo
conecta con las dos acciones reales del módulo, respaldadas por los
endpoints ya implementados:

- **Suspender / Reactivar** → `PATCH /auth/users/:id/status`
  (doc `009`): es una **confirmación** — `AlertDialog` centrado (primer
  dialog de la app), variante destructiva roja para suspender y neutra
  para reactivar.
- **Restablecer contraseña** → `PATCH /auth/users/:id/password`
  (doc `010`): necesita un **campo de entrada** — bottom sheet con la
  misma piel que `NewUserSheet` (§44): handle, título, campo de
  contraseña temporal visible, CTA. Un `AlertDialog` con campo pelea con
  el teclado; el sheet ya resuelve `viewInsets`.

Sigue siendo **solo UI**: suspender/reactivar **flippea el
`MemberStatus` en el dataset local** (el chip de la card cambia al
instante — el flujo se siente real) y restablecer muestra el snackbar de
feedback. La integración reemplaza la mutación local por el PATCH +
refresh.

## Wireframes

```
     Confirmación (AlertDialog)              Sheet de reset
 ╭───────────────────────────╮      ╭──────────────────────────╮
 │           ( ⊘ )           │      │      ────          (✕)   │
 │                           │      │  Restablecer contraseña   │
 │   ¿Suspender a Pedro R.?  │      │  Nueva contraseña         │
 │                           │      │  temporal para Pedro —    │
 │  Perderá el acceso a esta │      │  ingresará con ella.      │
 │  organización hasta que   │      │  ┌──────────────────────┐ │
 │  lo reactives.            │      │  │ 🔒 Nueva contraseña  │ │
 │                           │      │  └──────────────────────┘ │
 │ [Cancelar]  [Suspender]   │      │  La contraseña debe tener:│
 ╰───────────────────────────╯      │  ○/✓ 4 requisitos vivos   │
   icono en círculo teñido:         │                           │
   rojo suspende / verde reactiva   │ [Cancelar][Actualizar cnt]│
   par 1:1 ghost + CTA de acento    ╰──────────────────────────╯
   (rojo suspender / amarillo       mismo contenedor que §44 +
    reactivar) — misma piel del     convenciones 1.9.x: zona fija
    par del sheet                   handle+✕, checklist, par 1:1,
                                    tope en el hero navy
```

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/users/domain/entities/org_member.dart` | agregar `copyWith` (flip de status) |
| `lib/features/users/presentation/widgets/member_status_dialog.dart` | **nuevo** — confirmación suspender/reactivar |
| `lib/features/users/presentation/widgets/reset_password_sheet.dart` | **nuevo** — sheet de password temporal |
| `lib/features/users/presentation/widgets/member_actions_menu.dart` | recibe `member` + callbacks, abre los diálogos |
| `lib/features/users/presentation/widgets/org_member_card.dart` | pasa `member` completo + callbacks al menú |
| `lib/features/users/presentation/screens/users_screen.dart` | handlers `_setMemberStatus` / `_resetMemberPassword` + getter `_sheetTopInset` |
| `lib/features/users/presentation/widgets/new_user_sheet.dart` | FittedBox scaleDown en el ghost del par (consistencia con el fix del sheet de reset) |
| `lib/core/widgets/quesivo_primary_button.dart` | label envuelto en `FittedBox(scaleDown)`+`maxLines:1` — los pares 1:1 no envuelven a 2 líneas con labels largos |
| `lib/l10n/app_{es,en,pt}.arb` | 8 keys nuevas + `flutter gen-l10n` |
| `test/.../member_status_dialog_test.dart` | **nuevo** |
| `test/.../reset_password_sheet_test.dart` | **nuevo** |
| `test/.../org_member_card_test.dart` | constructor con callbacks requeridos |
| `../Design/quesivo-design-system.yaml` | spec `member_actions` + bump `1.10.0` |

---

## 1. `org_member.dart` — agregar `copyWith`

**Ruta:** `lib/features/users/domain/entities/org_member.dart`

```dart
  /// Copia inmutable con overrides — la UI la usa para flippear
  /// `status` en el dataset local; la integración la usará con el ítem
  /// que devuelve PATCH /auth/users/:id/status.
  OrgMember copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    MemberStatus? status,
    String? organizationId,
  }) => OrgMember(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    role: role ?? this.role,
    status: status ?? this.status,
    organizationId: organizationId ?? this.organizationId,
  );
```

## 2. `member_status_dialog.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/member_status_dialog.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Confirmación de suspender/reactivar la membresía (§45) — primer
/// `AlertDialog` de la app. La variante se deriva de `member.status`:
/// suspender = destructiva (rojo), reactivar = neutra (amarillo).
///
/// Devuelve `true` si se confirmó. Solo UI: la mutación la hace el
/// caller en el dataset local; al integrar `PATCH /auth/users/:id/status`
/// las reglas `SELF_SUSPENSION`/`LAST_ADMIN` del backend se mapean a
/// mensajes acá (doc 009).
class MemberStatusDialog extends StatelessWidget {
  const MemberStatusDialog({super.key, required this.member});

  final OrgMember member;

  static Future<bool> show(BuildContext context, OrgMember member) {
    return showDialog<bool>(
      context: context,
      builder: (_) => MemberStatusDialog(member: member),
    ).then((v) => v ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suspending = member.status == MemberStatus.active;
    final accent = suspending
        ? AppColors.quesivoError
        : AppColors.quesivoSuccess;

    return AlertDialog(
      backgroundColor: AppColors.quesivoWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: CircleAvatar(
        radius: 24,
        backgroundColor: accent.withValues(alpha: 0.12),
        child: Icon(
          suspending ? Icons.block_outlined : Icons.check_circle_outline,
          color: accent,
          size: 24,
        ),
      ),
      title: Text(
        suspending
            ? l10n.suspendMemberTitle(member.name)
            : l10n.reactivateMemberTitle(member.name),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.quesivoNavy,
        ),
      ),
      content: Text(
        suspending
            ? l10n.suspendMemberMessage
            : l10n.reactivateMemberMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppColors.quesivoTextSecondary,
        ),
      ),
      // Botones hug-content centrados: OverflowBar los pone lado a lado
      // cuando entran (la mayoría de teléfonos) y los apila a ancho
      // completo cuando el diálogo es muy angosto — nunca envuelve el
      // label a 2 líneas (un Row+Expanded lo forzaría en ~110dp).
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.quesivoIconSurface,
            foregroundColor: AppColors.quesivoNavy,
            elevation: 0,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(l10n.cancelAction),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: suspending
                ? AppColors.quesivoError
                : AppColors.quesivoYellow,
            foregroundColor: suspending
                ? AppColors.quesivoWhite
                : AppColors.quesivoNavy,
            elevation: 0,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(
            suspending ? l10n.suspendUserAction : l10n.reactivateUserAction,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
```

Nota de diseño (ajustada tras revisión): el diálogo **no** usa el par
`Row`+`Expanded` 1:1 del sheet — un diálogo angosto (~310dp) partiría
cada botón en ~110dp y "Suspender usuario" envolvería a 2 líneas. Los
`actions` de `AlertDialog` van en un `OverflowBar`: dos botones planos
hug-content quedan lado a lado centrados cuando entran y se apilan a
ancho completo cuando no — comportamiento nativo, sin hacks.

## 3. `reset_password_sheet.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/reset_password_sheet.dart`

Mismo contenedor que `NewUserSheet` con todas las convenciones 1.9.x:
zona fija (handle + ✕ `QuesivoCloseButton`), `topInset` topeando en el
hero navy, checklist vivo bajo el campo y par de acciones 1:1.

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/password_requirements_checklist.dart';
import '../../../../core/widgets/quesivo_close_button.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../domain/entities/org_member.dart';

/// Sheet de reset de contraseña por admin (§45) — mini-form con un solo
/// campo, mismo contenedor y convenciones que `NewUserSheet` (§44 +
/// fixes 1.9.x). Devuelve el password ingresado o `null` al cancelar —
/// la integración de `PATCH /auth/users/:id/password` lo manda al
/// backend tal cual (el reset además levanta el lockout del email,
/// doc 010).
///
/// La política espeja el VO del backend (min 8, mayúscula, minúscula,
/// dígito) — igual que en NewUserSheet; la propuesta de integración
/// introduce el VO de dominio compartido.
class ResetPasswordSheet extends StatefulWidget {
  const ResetPasswordSheet({super.key, required this.member});

  final OrgMember member;

  /// Abre el sheet y devuelve la contraseña nueva, o `null` si se
  /// canceló.
  ///
  /// [topInset]: borde inferior del hero navy — tope del sheet con el
  /// teclado abierto (mismo patrón que NewUserSheet.show).
  static Future<String?> show(
    BuildContext context,
    OrgMember member, {
    double topInset = 0,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      // Modal sobre el navigator RAÍZ — cubre el QuesivoNavBar del shell
      // (sin esto la barra queda pintada encima del sheet, bug §44 fix).
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.quesivoWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - topInset,
      ),
      builder: (_) => ResetPasswordSheet(member: member),
    );
  }

  @override
  State<ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<ResetPasswordSheet> {
  static final _hasLower = RegExp(r'[a-z]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasDigit = RegExp(r'\d');

  String _password = '';
  bool _passwordError = false;

  bool get _validPassword =>
      _password.length >= 8 &&
      _hasLower.hasMatch(_password) &&
      _hasUpper.hasMatch(_password) &&
      _hasDigit.hasMatch(_password);

  void _submit() {
    setState(() => _passwordError = !_validPassword);
    if (_passwordError) return;
    Navigator.of(context).pop(_password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      // Zona fija (handle + ✕) + scroll del form — idéntico a
      // NewUserSheet: Flexible, no Expanded, mide al contenido.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
            child: SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.quesivoBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: QuesivoCloseButton(),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.resetPasswordAction,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.resetPasswordSheetHint(widget.member.name),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.quesivoTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Visible a propósito — igual que en la creación: el
                  // admin la inventa y se la dicta al usuario.
                  QuesivoTextField(
                    hintText: l10n.newPasswordPlaceholder,
                    prefixIcon: Icons.lock_outline,
                    errorText: _passwordError
                        ? l10n.invalidTempPasswordError
                        : null,
                    onChanged: (v) => setState(() {
                      _password = v;
                      _passwordError = false;
                    }),
                  ),
                  const SizedBox(height: 12),
                  PasswordRequirementsChecklist(
                    title: l10n.passwordReqTitle,
                    items: [
                      PasswordRequirementItem(
                        met: _password.length >= 8,
                        label: l10n.passwordReqMinLength,
                      ),
                      PasswordRequirementItem(
                        met: _hasUpper.hasMatch(_password),
                        label: l10n.passwordReqUppercase,
                      ),
                      PasswordRequirementItem(
                        met: _hasLower.hasMatch(_password),
                        label: l10n.passwordReqLowercase,
                      ),
                      PasswordRequirementItem(
                        met: _hasDigit.hasMatch(_password),
                        label: l10n.passwordReqDigit,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Par 1:1 — misma piel que NewUserSheet: ghost a la
                  // izquierda, primario amarillo a la derecha. Los
                  // labels van en FittedBox(scaleDown)+maxLines:1 —
                  // "Actualizar contraseña" no entra en la mitad a 18px
                  // y escala en vez de envolver (el FittedBox del
                  // primario vive dentro de QuesivoPrimaryButton).
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.quesivoIconSurface,
                            foregroundColor: AppColors.quesivoNavy,
                            elevation: 0,
                            minimumSize: const Size(0, 64),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l10n.cancelAction, maxLines: 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: QuesivoPrimaryButton(
                          label: l10n.updatePasswordButton,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 4. `member_actions_menu.dart` (existente — abre los diálogos)

**Ruta:** `lib/features/users/presentation/widgets/member_actions_menu.dart`

El widget deja de recibir solo `status`: necesita el `member` completo
(nombre para el diálogo) y dos callbacks que la pantalla implementa.

**Antes:**

```dart
class MemberActionsMenu extends StatelessWidget {
  const MemberActionsMenu({super.key, required this.status});

  final MemberStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suspended = status == MemberStatus.suspended;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.quesivoTextSecondary),
      tooltip: l10n.memberActionsTooltip,
      onSelected: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.moduleComingSoon))),
      itemBuilder: (context) => [
```

**Después:**

```dart
/// Menú ⋮ de acciones por fila (§45): "Suspender/Reactivar" abre
/// `MemberStatusDialog` y "Restablecer contraseña" abre
/// `ResetPasswordSheet`. Los resultados suben por callback — la
/// pantalla decide la mutación local hoy y el PATCH mañana.
class MemberActionsMenu extends StatelessWidget {
  const MemberActionsMenu({
    super.key,
    required this.member,
    required this.onStatusToggle,
    required this.onPasswordReset,
    this.sheetTopInset = 0,
  });

  final OrgMember member;

  /// Recibe el nuevo `MemberStatus` si el admin confirmó el diálogo.
  final ValueChanged<MemberStatus> onStatusToggle;

  /// Recibe el password ingresado si el admin completó el sheet.
  final ValueChanged<String> onPasswordReset;

  /// Tope del `ResetPasswordSheet` (borde inferior del hero navy) —
  /// lo mide la pantalla y viaja por la card hasta acá.
  final double sheetTopInset;

  Future<void> _onSelected(BuildContext context, String value) async {
    switch (value) {
      case 'status':
        final confirmed = await MemberStatusDialog.show(context, member);
        if (!confirmed || !context.mounted) return;
        onStatusToggle(
          member.status == MemberStatus.active
              ? MemberStatus.suspended
              : MemberStatus.active,
        );
      case 'password':
        final password = await ResetPasswordSheet.show(
          context,
          member,
          topInset: sheetTopInset,
        );
        if (password == null || !context.mounted) return;
        onPasswordReset(password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suspended = member.status == MemberStatus.suspended;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.quesivoTextSecondary),
      tooltip: l10n.memberActionsTooltip,
      onSelected: (value) => _onSelected(context, value),
      itemBuilder: (context) => [
```

(El `itemBuilder` queda igual — solo cambia `status` → `member.status`.)
Imports nuevos: `member_status_dialog.dart`, `reset_password_sheet.dart`.

## 5. `org_member_card.dart` (existente — pasa member + callbacks)

**Ruta:** `lib/features/users/presentation/widgets/org_member_card.dart`

**Antes:**

```dart
class OrgMemberCard extends StatelessWidget {
  const OrgMemberCard({super.key, required this.member});

  final OrgMember member;
```

y en el Row: `MemberActionsMenu(status: member.status),`

**Después:**

```dart
class OrgMemberCard extends StatelessWidget {
  const OrgMemberCard({
    super.key,
    required this.member,
    required this.onStatusToggle,
    required this.onPasswordReset,
    this.sheetTopInset = 0,
  });

  final OrgMember member;
  final ValueChanged<MemberStatus> onStatusToggle;
  final ValueChanged<String> onPasswordReset;

  /// Tope del `ResetPasswordSheet` — lo mide la pantalla sobre el hero.
  final double sheetTopInset;
```

y en el Row:

```dart
          MemberActionsMenu(
            member: member,
            onStatusToggle: onStatusToggle,
            onPasswordReset: onPasswordReset,
            sheetTopInset: sheetTopInset,
          ),
```

## 6. `users_screen.dart` (existente — handlers)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

En `_UsersScreenState`: la medición del hero que hoy está inline en
`_openNewUserSheet` se extrae a un getter compartido — el mismo tope lo
usan el sheet de creación y el de reset:

```dart
  /// Borde inferior del hero navy medido en vivo — tope de los sheets
  /// modales (creación §44, reset §45) con el teclado abierto.
  double get _sheetTopInset {
    final heroContext = _heroKey.currentContext;
    if (heroContext == null) return 0;
    final box = heroContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;
    return box.localToGlobal(Offset.zero).dy + box.size.height;
  }
```

`_openNewUserSheet` queda en una línea de medición:

```dart
  void _openNewUserSheet() => NewUserSheet.show(
        context,
        topInset: _sheetTopInset,
      );
```

Y junto a él los handlers de §45:

```dart
  /// §45 — flip de estado en el dataset local tras confirmar el
  /// diálogo. La integración lo reemplaza por
  /// `PATCH /auth/users/:id/status` + merge del ítem devuelto.
  void _setMemberStatus(OrgMember member, MemberStatus status) {
    final index = _allMembers.indexWhere((m) => m.id == member.id);
    if (index == -1) return;
    setState(() => _allMembers[index] = member.copyWith(status: status));
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == MemberStatus.suspended
              ? l10n.memberSuspendedFeedback
              : l10n.memberReactivatedFeedback,
        ),
      ),
    );
  }

  /// §45 — feedback del reset. La integración manda el password a
  /// `PATCH /auth/users/:id/password` (que además levanta el lockout).
  void _resetMemberPassword(OrgMember member, String password) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.passwordResetFeedback(member.name))),
    );
  }
```

Y en el `itemBuilder` del `ListView.separated`:

**Antes:** `return OrgMemberCard(member: visible[index]);`

**Después:**

```dart
                      final member = visible[index];
                      return OrgMemberCard(
                        member: member,
                        onStatusToggle: (s) => _setMemberStatus(member, s),
                        onPasswordReset: (pw) =>
                            _resetMemberPassword(member, pw),
                        sheetTopInset: _sheetTopInset,
                      );
```

## 7. l10n — 8 keys nuevas (3 con placeholder `{name}`)

| Key | es | en | pt |
|-----|----|----|----|
| `suspendMemberTitle` | ¿Suspender a {name}? | Suspend {name}? | Suspender {name}? |
| `suspendMemberMessage` | Perderá el acceso a esta organización hasta que lo reactives. | They will lose access to this organization until you reactivate them. | Perderá o acesso a esta organização até que você o reative. |
| `reactivateMemberTitle` | ¿Reactivar a {name}? | Reactivate {name}? | Reativar {name}? |
| `reactivateMemberMessage` | Recuperará el acceso a esta organización. | They will regain access to this organization. | Recuperará o acesso a esta organização. |
| `memberSuspendedFeedback` | Membresía suspendida | Membership suspended | Associação suspensa |
| `memberReactivatedFeedback` | Membresía reactivada | Membership reactivated | Associação reativada |
| `resetPasswordSheetHint` | Nueva contraseña temporal para {name} — ingresará con ella. | New temporary password for {name} — they will sign in with it. | Nova senha temporária para {name} — entrará com ela. |
| `passwordResetFeedback` | Contraseña restablecida — compartila con {name} | Password reset — share it with {name} | Senha redefinida — compartilhe com {name} |

Las 4 con `{name}` llevan su bloque `@key` con `placeholders`
(`String`), siguiendo el patrón de `appVersion`/`membersCount`. Reuso:
`suspendUserAction`, `reactivateUserAction` (CTAs del diálogo),
`resetPasswordAction` (título del sheet), `newPasswordPlaceholder`,
`updatePasswordButton`, `invalidTempPasswordError`, `cancelAction`.

## 8. Tests

### `member_status_dialog_test.dart` (nuevo)

Harness `MaterialApp` con botón que abra `MemberStatusDialog.show` y
capture el `Future<bool>`:

1. Miembro activo → título "¿Suspender a Ana Pérez?", mensaje de
   pérdida de acceso, CTA "Suspender usuario".
2. Miembro suspendido → título "¿Reactivar a…?", CTA "Reactivar usuario".
3. Tap en CTA → future resuelve `true`; tap en "Cancelar" → `false`.

### `reset_password_sheet_test.dart` (nuevo)

Mismo harness que `new_user_sheet_test` (botón + `late Future<String?>`):

1. Renderiza título "Restablecer contraseña", hint con el nombre y el
   campo.
2. Submit con password débil → error `invalidTempPasswordError`, no pop.
3. Submit válido → future resuelve el password exacto.
4. Cancelar → `null`.

### `org_member_card_test.dart` (actualización)

Agregar los dos callbacks requeridos (`onStatusToggle: (_) {}`,
`onPasswordReset: (_) {}`) a los dos `OrgMemberCard` del harness.

### `users_screen_test.dart` (1 caso nuevo)

- **"suspender desde el menú cambia el chip de la card"**: abrir el ⋮
  de la primera card (con tall surface + ensureVisible), tocar
  "Suspender usuario", confirmar en el diálogo → la primera card pasa a
  chip "Suspendido" y aparece el snackbar "Membresía suspendida".

## 9. Design system — `Design/quesivo-design-system.yaml`

- `version` → `1.10.0` (componentes nuevos → minor).
- Bajo `pages.users_screen`, reemplazar la nota de
  `actions_menu.interaction` ("visual — cada opción muestra SnackBar…")
  por `"abre MemberStatusDialog / ResetPasswordSheet (§45)"` y agregar
  la sección **`member_actions`**:

```yaml
      member_actions:
        purpose: "Propuesta §45 — diálogos reales de las acciones ⋮. Solo UI: el status flippea en el dataset local y el reset solo da feedback; PATCH /auth/users/:id/status y /password los reemplazan al integrar."
        status_dialog:
          widget: "MemberStatusDialog — primer AlertDialog de la app: fondo quesivoWhite r20, icono en CircleAvatar teñido 12% (error/success según la acción), título 18 w800 navy centrado con {name}, mensaje 14 secondary centrado"
          actions: "par 1:1 (misma convención del sheet, 1.9.13): ghost iconSurface/navy 'Cancelar' + CTA de acento — 56px StadiumBorder; OverflowBar los apila en pantallas muy angostas"
          suspend_variant: "icono block_outlined + CircleAvatar quesivoError — CTA fondo quesivoError/texto blanco (destructiva, mismo criterio que el ítem del menú y logout del drawer)"
          reactivate_variant: "icono check_circle_outline + CircleAvatar quesivoSuccess — CTA quesivoYellow/navy"
        reset_password_sheet:
          widget: "ResetPasswordSheet — mismo contenedor y convenciones que NewUserSheet: zona fija handle+✕ QuesivoCloseButton, topInset al hero navy, Flexible+scroll del form, checklist vivo bajo el campo, par 1:1 ghost+primario"
          field: "un QuesivoTextField 'Nueva contraseña' visible (el admin la dicta) con hint resetPasswordSheetHint {name}"
          result: "devuelve el password por Navigator.pop — validación idéntica a la creación (min 8, mayúscula, minúscula, dígito)"
        pending_backend_rules: "SELF_SUSPENSION y LAST_ADMIN (doc 009) se mapean a mensajes en el diálogo al integrar — la UI de muestra no conoce 'yo' ni el conteo de admins"
```

- Changelog `1.10.0` (page `users_screen`, `completed`): "Diálogos de
  acciones del miembro (propuesta 45): MemberStatusDialog (primer
  AlertDialog de la app — par de acciones 1:1, variante destructiva roja
  para suspender, neutra amarilla para reactivar) y ResetPasswordSheet
  (mini-form con todas las convenciones del sheet de creación: zona fija
  handle+✕, tope en hero, checklist vivo, par 1:1). Solo UI:
  suspender/reactivar flippea el chip del card en el dataset local; el
  reset solo da feedback. El menú ⋮ deja de mostrar 'Próximamente'.
  OrgMember gana copyWith."

---

## Orden de aplicación

1. `org_member.dart` — `copyWith`.
2. Keys l10n en los 3 arb (+ `@key` con placeholders donde aplique) +
   `flutter gen-l10n`.
3. `member_status_dialog.dart` y `reset_password_sheet.dart`.
4. `member_actions_menu.dart` (firma nueva + handlers) →
   `org_member_card.dart` (pasa callbacks) → `users_screen.dart`
   (handlers + itemBuilder).
5. Tests: dos archivos nuevos + updates de `org_member_card_test` y
   `users_screen_test`.
6. `dart format`, `flutter analyze`, `flutter test`.
7. Spec + bump `1.10.0` en el yaml (lo hace la sesión principal).
