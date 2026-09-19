# Propuesta: Bottom sheet de creación de usuario (solo UI)

El círculo amarillo `person_add` del hero de Usuarios hoy muestra el
snackbar "Próximamente". Esta propuesta lo conecta con el **bottom sheet
de creación**: el primer `showModalBottomSheet` de la app, con los 4
campos del contrato `POST /auth/users` (doc `007-post-users.md`):
nombre, email, contraseña temporal y rol.

Sigue siendo **solo UI** — no hay datasource/repository/cubit ni llamada
al backend. Al confirmar con el form válido, el sheet devuelve un
`OrgMember` que la pantalla **inserta al tope del dataset local** (stats
y listado se actualizan solos: el nuevo card se ve y es buscable al
instante) + snackbar de feedback. La propuesta de integración reemplaza
ese insert local por el POST real sin tocar el sheet.

## Wireframe

```
╭──────────────────────────────────╮
│              ────                 │ ← handle 40×4 quesivoBorder
│  Nuevo usuario                    │ ← l10n newUserButton, 20 w800 navy
│  El usuario ingresará con esta    │ ← hint 13 secondary — explica el
│  contraseña temporal, compartila. │   por qué de inventar una password
│  ┌──────────────────────────────┐ │
│  │ 👤  Nombre completo          │ │ ← QuesivoTextField person_outline
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │ ✉   Correo electrónico       │ │ ← keyboardType emailAddress
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │ 🔒  Contraseña temporal      │ │ ← VISIBLE: el admin la dicta
│  └──────────────────────────────┘ │
│  Rol en la organización             ← label 13 w600 navy
│  [🛡 Administrador] [⚙ Operario]  │ ← Wrap de chips seleccionables
│  [🚛 Recolector]  [🚜 Productor]  │   (misma piel que RoleFilterChips)
│  ┌──────────────────────────────┐ │
│  │        Crear usuario         │ │ ← QuesivoPrimaryButton 64px
│  └──────────────────────────────┘ │
│            Cancelar               │ ← TextButton secondary
╰──────────────────────────────────╯
   sheet blanco, esquinas superiores r28 (eco del hero/navbar)
```

- `isScrollControlled: true` + `Padding(viewInsets.bottom)` +
  `SingleChildScrollView` → el sheet sube completo sobre el teclado.
- Validación **manual al submit** (los campos de marca exponen
  `errorText`, no `validator`): nombre no vacío · email regex ·
  password min 8 + mayúscula + minúscula + dígito (espejo del backend)
  · rol elegido (sin default — el rol se elige explícito, un OPERATOR
  preseleccionado generaría altas equivocadas por descuido).
- El email se guarda `trim().toLowerCase()` — misma normalización del
  backend (§055).

## Refactors incluidos (necesarios, no opcionales)

1. **`QuesivoAuthField` → `lib/core/widgets/quesivo_text_field.dart`
   renombrado `QuesivoTextField`.** Es una primitiva de marca (borde
   quesivoBorder r15, prefixIcon navy, ojo de visibilidad), no algo
   específico de auth — mismo criterio que movió `QuesivoPrimaryButton`
   y `UserInitialAvatar` a `core/` en §37. Importarlo desde `features/users`
   sería acoplamiento feature→feature. Solo cambia ubicación y nombre;
   la API queda igual. Los 4 consumidores de auth actualizan su import.
2. **`user_role_ui.dart` — extensión `UserRole.label(l10n)` +
   `UserRole.icon`.** El mapa rol→label→ícono ya existe dos veces
   (`MemberRoleChip._label`/`_icon` y la tabla inline de
   `RoleFilterChips`); el selector del sheet sería la tercera copia. Se
   extrae una sola fuente de verdad y ambos widgets la consumen.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/widgets/quesivo_text_field.dart` | **nuevo** — `QuesivoAuthField` movido y renombrado `QuesivoTextField` |
| `lib/features/auth/presentation/widgets/quesivo_auth_field.dart` | **eliminar** — queda en `core/` |
| `lib/features/users/presentation/widgets/user_role_ui.dart` | **nuevo** — extensión `UserRole.label(l10n)` + `UserRole.icon` |
| `lib/features/users/presentation/widgets/role_selector_chips.dart` | **nuevo** — chips seleccionables de rol para el form |
| `lib/features/users/presentation/widgets/new_user_sheet.dart` | **nuevo** — el bottom sheet |
| `lib/features/users/presentation/widgets/member_role_chip.dart` | consume la extensión (borra `_label`/`_icon` privados) |
| `lib/features/users/presentation/widgets/role_filter_chips.dart` | consume la extensión (borra la tabla inline) |
| `lib/features/users/presentation/screens/users_screen.dart` | el botón `person_add` abre el sheet; inserta el miembro devuelto |
| `lib/features/auth/presentation/widgets/{register_form_fields,login_form_fields,reset_password_form_fields,forgot_password_form}.dart` | import + rename a `QuesivoTextField` |
| `lib/l10n/app_{es,en,pt}.arb` | 8 keys nuevas + `flutter gen-l10n` |
| `test/features/users/presentation/widgets/new_user_sheet_test.dart` | **nuevo** |
| `test/features/users/presentation/widgets/role_selector_chips_test.dart` | **nuevo** |
| `test/features/users/presentation/screens/users_screen_test.dart` | el botón ya abre el sheet (no snackbar) |
| `../Design/quesivo-design-system.yaml` | spec `create_user_sheet` + bump `1.9.0` |

---

## 1. `quesivo_text_field.dart` (archivo nuevo — movido desde auth)

**Ruta:** `lib/core/widgets/quesivo_text_field.dart`

Mismo código que `lib/features/auth/presentation/widgets/quesivo_auth_field.dart`
con dos cambios: la clase pasa a llamarse `QuesivoTextField` y el doc deja
de decir "de autenticación":

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Campo de texto de marca QUESIVO (quesivo-design-system.yaml
/// §register_form / §login_form / §create_user_sheet) — borde
/// quesivoBorder r15, prefixIcon navy, fill blanco.
///
/// SOLID (SRP): solo renderiza la caja con el estilo de marca; no sabe
/// para qué se usa (nombre, email, password). `isPassword` agrega el ojo
/// de visibilidad como estado visual interno.
///
/// Movido a core/widgets en §44 — es una primitiva de marca compartida
/// por auth y los módulos (antes `QuesivoAuthField` en features/auth).
class QuesivoTextField extends StatefulWidget {
  const QuesivoTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.errorText,
    this.onChanged,
  });

  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? errorText;
  final void Function(String)? onChanged;

  @override
  State<QuesivoTextField> createState() => _QuesivoTextFieldState();
}

class _QuesivoTextFieldState extends State<QuesivoTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.quesivoBorder, width: 1.5),
    );

    return TextFormField(
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(
        color: AppColors.quesivoDarkText,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(
          color: AppColors.quesivoPlaceholder,
          fontSize: 16,
        ),
        errorText: widget.errorText,
        filled: true,
        fillColor: AppColors.quesivoWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 18,
        ),
        prefixIcon: Icon(
          widget.prefixIcon,
          color: AppColors.quesivoNavy,
          size: 28,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.quesivoPlaceholder,
                  size: 26,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.quesivoNavy, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
      ),
    );
  }
}
```

**Eliminar:** `lib/features/auth/presentation/widgets/quesivo_auth_field.dart`.

## 2. `user_role_ui.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/user_role_ui.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../domain/entities/user_role.dart';

/// Mapa único rol → label l10n + ícono de dominio (§44) — antes el mismo
/// switch vivía duplicado en `MemberRoleChip` y `RoleFilterChips`, y el
/// selector del sheet de creación sería la tercera copia.
///
/// Íconos queseros (§38): escudo = admin, casco = operario de planta,
/// camión = recolector de ruta, tractor = productor lechero.
extension UserRoleUi on UserRole {
  String label(AppLocalizations l10n) => switch (this) {
    UserRole.admin => l10n.adminRole,
    UserRole.operator => l10n.roleOperator,
    UserRole.collector => l10n.roleCollector,
    UserRole.producer => l10n.roleProducer,
  };

  IconData get icon => switch (this) {
    UserRole.admin => Icons.shield_outlined,
    UserRole.operator => Icons.engineering_outlined,
    UserRole.collector => Icons.local_shipping_outlined,
    UserRole.producer => Icons.agriculture_outlined,
  };
}
```

## 3. `role_selector_chips.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/role_selector_chips.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_role.dart';
import 'user_role_ui.dart';

/// Selector de rol del sheet de creación (§44) — los 4 roles del catálogo
/// como chips seleccionables con la misma piel que `RoleFilterChips`
/// (seleccionado navy/blanco, sin seleccionar iconSurface/navy), en Wrap
/// porque 4 chips no siempre entran en una sola fila dentro del sheet.
///
/// Sin "Todos" ni default: el rol es obligatorio y se elige explícito —
/// preseleccionar uno generaría membresías equivocadas por descuido.
class RoleSelectorChips extends StatelessWidget {
  const RoleSelectorChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final UserRole? selected;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in UserRole.values)
          _RoleSelectorChip(
            label: role.label(l10n),
            icon: role.icon,
            isSelected: role == selected,
            onTap: () => onChanged(role),
          ),
      ],
    );
  }
}

class _RoleSelectorChip extends StatelessWidget {
  const _RoleSelectorChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? AppColors.quesivoWhite : AppColors.quesivoNavy;
    return Material(
      color: isSelected ? AppColors.quesivoNavy : AppColors.quesivoIconSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 4. `new_user_sheet.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/new_user_sheet.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import 'role_selector_chips.dart';

/// Bottom sheet de creación de usuario (§44) — el primero de la app.
/// Solo UI: valida el form y devuelve el `OrgMember` construido vía
/// `Navigator.pop`; la integración de `POST /auth/users` lo reemplaza
/// por la llamada real sin tocar este widget (misma respuesta visual).
///
/// Validación manual al submit — `QuesivoTextField` expone `errorText`
/// (patrón del proyecto: el error llega de afuera, no de un `validator`
/// interno). La política de password espeja `RegisterDto` del backend
/// (min 8, mayúscula, minúscula, dígito — doc 007-post-users.md); la
/// propuesta de integración introduce el VO de dominio correspondiente.
class NewUserSheet extends StatefulWidget {
  const NewUserSheet({super.key});

  /// Abre el sheet y devuelve el miembro creado, o `null` si se canceló.
  static Future<OrgMember?> show(BuildContext context) {
    return showModalBottomSheet<OrgMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.quesivoWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const NewUserSheet(),
    );
  }

  @override
  State<NewUserSheet> createState() => _NewUserSheetState();
}

class _NewUserSheetState extends State<NewUserSheet> {
  // Espejo local de la política del backend — la integración introduce
  // el VO de dominio (misma regla que RegisterPassword de auth).
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  static final _hasLower = RegExp(r'[a-z]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasDigit = RegExp(r'\d');

  String _name = '';
  String _email = '';
  String _password = '';
  UserRole? _role;

  bool _nameError = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _roleError = false;

  bool get _validPassword =>
      _password.length >= 8 &&
      _hasLower.hasMatch(_password) &&
      _hasUpper.hasMatch(_password) &&
      _hasDigit.hasMatch(_password);

  void _submit() {
    final name = _name.trim();
    final email = _email.trim().toLowerCase();
    setState(() {
      _nameError = name.isEmpty;
      _emailError = !_emailRegex.hasMatch(email);
      _passwordError = !_validPassword;
      _roleError = _role == null;
    });
    if (_nameError || _emailError || _passwordError || _roleError) return;

    Navigator.of(context).pop(
      OrgMember(
        // Id sintético — la integración devuelve el uuid del backend.
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        email: email,
        name: name,
        role: _role!,
        status: MemberStatus.active,
        organizationId: 'sample-org',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      // El sheet sube entero sobre el teclado.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            Text(
              l10n.newUserButton,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.quesivoNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.newUserSheetHint,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.quesivoTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            QuesivoTextField(
              hintText: l10n.fullNamePlaceholder,
              prefixIcon: Icons.person_outline,
              keyboardType: TextInputType.name,
              errorText: _nameError ? l10n.invalidMemberNameError : null,
              onChanged: (v) => setState(() {
                _name = v;
                _nameError = false;
              }),
            ),
            const SizedBox(height: 14),
            QuesivoTextField(
              hintText: l10n.registerEmailPlaceholder,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError ? l10n.invalidEmailError : null,
              onChanged: (v) => setState(() {
                _email = v;
                _emailError = false;
              }),
            ),
            const SizedBox(height: 14),
            // Visible a propósito: es una contraseña temporal que el
            // admin inventa y le comparte al usuario a mano — ocultarla
            // solo dificultaría tipearla/dictarla sin typos.
            QuesivoTextField(
              hintText: l10n.tempPasswordPlaceholder,
              prefixIcon: Icons.lock_outline,
              errorText: _passwordError ? l10n.invalidTempPasswordError : null,
              onChanged: (v) => setState(() {
                _password = v;
                _passwordError = false;
              }),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.roleFieldLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.quesivoNavy,
              ),
            ),
            const SizedBox(height: 8),
            RoleSelectorChips(
              selected: _role,
              onChanged: (role) => setState(() {
                _role = role;
                _roleError = false;
              }),
            ),
            if (_roleError) ...[
              const SizedBox(height: 6),
              Text(
                l10n.roleRequiredError,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            QuesivoPrimaryButton(
              label: l10n.createUserButton,
              onPressed: _submit,
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l10n.cancelAction,
                  style: const TextStyle(
                    color: AppColors.quesivoTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 5. `member_role_chip.dart` (existente — consume la extensión)

**Ruta:** `lib/features/users/presentation/widgets/member_role_chip.dart`

**Antes:**

```dart
class MemberRoleChip extends StatelessWidget {
  const MemberRoleChip({super.key, required this.role});

  final UserRole role;

  String _label(AppLocalizations l10n) => switch (role) {
    UserRole.admin => l10n.adminRole,
    UserRole.operator => l10n.roleOperator,
    UserRole.collector => l10n.roleCollector,
    UserRole.producer => l10n.roleProducer,
  };

  /// Ícono de dominio por rol — vocabulario quesero (§38):
  /// escudo = admin, casco = operario de planta, camión = recolector
  /// de ruta, tractor = productor lechero.
  IconData get _icon => switch (role) {
    UserRole.admin => Icons.shield_outlined,
    UserRole.operator => Icons.engineering_outlined,
    UserRole.collector => Icons.local_shipping_outlined,
    UserRole.producer => Icons.agriculture_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      ...
          Icon(_icon, size: 13, color: AppColors.quesivoNavy),
          const SizedBox(width: 5),
          Text(
            _label(l10n),
```

**Después:** el widget consume `role.icon` y `role.label(l10n)` de la
extensión `UserRoleUi` (import `user_role_ui.dart`); se borran `_label`
y `_icon` privados. El build queda:

```dart
class MemberRoleChip extends StatelessWidget {
  const MemberRoleChip({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.quesivoIconSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 13, color: AppColors.quesivoNavy),
          const SizedBox(width: 5),
          Text(
            role.label(l10n),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.quesivoNavy,
            ),
          ),
        ],
      ),
    );
  }
}
```

## 6. `role_filter_chips.dart` (existente — consume la extensión)

**Ruta:** `lib/features/users/presentation/widgets/role_filter_chips.dart`

**Antes:**

```dart
    final l10n = AppLocalizations.of(context)!;
    final options = <(UserRole?, String, IconData?)>[
      (null, l10n.roleFilterAll, null),
      (UserRole.admin, l10n.adminRole, Icons.shield_outlined),
      (UserRole.operator, l10n.roleOperator, Icons.engineering_outlined),
      (UserRole.collector, l10n.roleCollector, Icons.local_shipping_outlined),
      (UserRole.producer, l10n.roleProducer, Icons.agriculture_outlined),
    ];
```

**Después:** la tabla se arma con la extensión (import
`user_role_ui.dart`):

```dart
    final l10n = AppLocalizations.of(context)!;
    final options = <(UserRole?, String, IconData?)>[
      (null, l10n.roleFilterAll, null),
      for (final role in UserRole.values) (role, role.label(l10n), role.icon),
    ];
```

## 7. `users_screen.dart` (existente — el botón abre el sheet)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

**Antes:**

```dart
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.moduleComingSoon)),
                              );
                            },
                            tooltip: l10n.newUserButton,
```

**Después:**

```dart
                          IconButton(
                            onPressed: _openNewUserSheet,
                            tooltip: l10n.newUserButton,
```

Y en `_UsersScreenState`, junto a los otros handlers:

```dart
  /// §44 — abre el sheet de creación; al volver con un miembro lo
  /// inserta al tope del dataset local (stats + listado se actualizan
  /// solos) y muestra feedback. La integración reemplaza el insert por
  /// `POST /auth/users` + refresh de la página.
  Future<void> _openNewUserSheet() async {
    final created = await NewUserSheet.show(context);
    if (created == null || !mounted) return;
    setState(() => _allMembers.insert(0, created));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.memberCreatedFeedback)),
    );
  }
```

Import nuevo: `../widgets/new_user_sheet.dart`. Doc de clase: la línea
de placeholders cambia a "las acciones de fila son placeholders
visuales; el botón de creación abre `NewUserSheet` (§44)".

## 8. Consumidores de auth (4 archivos — import + rename)

En `register_form_fields.dart`, `login_form_fields.dart`,
`reset_password_form_fields.dart` y `forgot_password_form.dart`:

**Antes:**

```dart
import 'quesivo_auth_field.dart';        // (o la ruta relativa equivalente)
...
QuesivoAuthField(
```

**Después:**

```dart
import '../../../../core/widgets/quesivo_text_field.dart';
...
QuesivoTextField(
```

Mismo constructor, misma API — solo cambia nombre e import. Ningún test
referencia `QuesivoAuthField` por tipo (verificado con grep en `test/`).

## 9. l10n — 8 keys nuevas

Agregar en `app_es.arb`, `app_en.arb` y `app_pt.arb` y ejecutar
`flutter gen-l10n` (no editar los generados a mano):

| Key | es | en | pt |
|-----|----|----|----|
| `newUserSheetHint` | El usuario ingresará con esta contraseña temporal — compartila con él. | The user will sign in with this temporary password — share it with them. | O usuário entrará com esta senha temporária — compartilhe-a com ele. |
| `tempPasswordPlaceholder` | Contraseña temporal | Temporary password | Senha temporária |
| `roleFieldLabel` | Rol en la organización | Role in the organization | Função na organização |
| `roleRequiredError` | Elegí un rol | Choose a role | Escolha uma função |
| `invalidMemberNameError` | Ingresá el nombre completo | Enter the full name | Digite o nome completo |
| `invalidTempPasswordError` | Mínimo 8 caracteres, una mayúscula, una minúscula y un número | At least 8 characters, one uppercase, one lowercase and one digit | Mínimo 8 caracteres, uma maiúscula, uma minúscula e um número |
| `createUserButton` | Crear usuario | Create user | Criar usuário |
| `memberCreatedFeedback` | Usuario creado — compartile la contraseña temporal | User created — share the temporary password | Usuário criado — compartilhe a senha temporária |

Reuso (sin keys nuevas): `newUserButton` (título del sheet),
`fullNamePlaceholder`, `registerEmailPlaceholder`, `invalidEmailError`,
`cancelAction`, labels de rol.

## 10. Tests

### `test/features/users/presentation/widgets/new_user_sheet_test.dart` (nuevo)

Harness: `MaterialApp(locale: es, delegates)` con un botón que invoque
`NewUserSheet.show(context)` y capture el resultado en una variable.
Casos:

1. **Renderiza campos y opciones**: título "Nuevo usuario", 3
   `QuesivoTextField` (hint "Nombre completo" / "Correo electrónico" /
   "Contraseña temporal"), los 4 chips de rol, "Crear usuario" y
   "Cancelar".
2. **Submit vacío muestra errores**: tap "Crear usuario" sin tocar nada
   → aparecen "Ingresá el nombre completo", "Ingresa un correo con
   formato válido", "Mínimo 8 caracteres…" y "Elegí un rol"; el sheet
   sigue abierto (no pop).
3. **Rol requerido**: con los 3 campos válidos pero sin rol → solo
   "Elegí un rol".
4. **Submit válido hace pop con el OrgMember**: completar nombre/email/
   password válidos + tocar chip "Operario" → `Crear usuario` → el
   future resuelve un `OrgMember` con `role == UserRole.operator`,
   `status == active` y el email normalizado (escribir
   `'Nuevo@Mail.com '` → `email == 'nuevo@mail.com'`).
5. **Cancelar cierra sin resultado** → future resuelve `null`.

### `test/features/users/presentation/widgets/role_selector_chips_test.dart` (nuevo)

- Renderiza los 4 roles con sus labels.
- Tap en un chip invoca `onChanged` con ese `UserRole`.
- El chip seleccionado pinta navy (verificar `Material.color`).

### `users_screen_test.dart` (actualización)

El test "muestra título, tooltip de acción y stats" se mantiene (el
botón sigue siendo el mismo `IconButton`). Agregar:

- **"el botón abre el sheet de creación"**: tap en
  `find.byIcon(Icons.person_add_outlined)` → `pumpAndSettle` →
  `find.text('Crear usuario')` visible.
- **"crear desde el sheet agrega el miembro al tope"**: abrir el sheet,
  completar el form válido, tap "Crear usuario" → `pumpAndSettle` → el
  sheet cerró, `find.text('Usuario creado — compartile la contraseña
  temporal')` en el snackbar, stats pasan a `55 miembros` y el card del
  nuevo usuario es el primero del listado.

## 11. Design system — `Design/quesivo-design-system.yaml`

- `version`: `1.8.0` → `1.9.0` (componente nuevo → minor).
- Bajo `pages.users_screen` agregar sección **`create_user_sheet`**:

```yaml
      create_user_sheet:
        purpose: "Propuesta §44 — alta de usuario vía bottom sheet (primer showModalBottomSheet de la app). Solo UI: devuelve el OrgMember por Navigator.pop y la pantalla lo inserta al tope del dataset local; POST /auth/users lo reemplaza al integrar."
        container: "isScrollControlled + padding viewInsets (sube sobre el teclado), fondo quesivoWhite, esquinas superiores r28 (eco del hero/navbar), handle 40×4 quesivoBorder centrado"
        title: "l10n newUserButton — 20px w800 navy; hint 13px secondary debajo (newUserSheetHint explica la contraseña temporal)"
        fields: "3 QuesivoTextField de marca (movido a core/widgets §44, ex QuesivoAuthField): nombre person_outline / email mail_outline + keyboardType emailAddress / contraseña temporal lock_outline SIN obscure — el admin la inventa y la dicta, ocultarla solo generaría typos; gaps 14px"
        role_selector: "label l10n roleFieldLabel 13px w600 navy + RoleSelectorChips (Wrap spacing 8 — 4 chips no siempre entran en fila dentro del sheet): misma piel que RoleFilterChips, seleccionado navy/blanco; sin default ni opción 'Todos' — el rol se elige explícito"
        validation: "manual al submit (QuesivoTextField usa errorText, no validator): nombre no vacío (invalidMemberNameError) · email regex (invalidEmailError) · password min 8 + mayúscula + minúscula + dígito espejo del RegisterDto backend (invalidTempPasswordError) · rol elegido (roleRequiredError bajo los chips, colorScheme.error 12px)"
        actions: "QuesivoPrimaryButton 'Crear usuario' (l10n createUserButton) 64px full-width + TextButton 'Cancelar' centrado secondary — cierra con pop(null)"
        result: "pop(OrgMember local-id timestamp, status active) → pantalla inserta en índice 0, scrollea al tope y muestra SnackBar l10n memberCreatedFeedback"
```

- Entrada de changelog `1.9.0` (page `users_screen`, status
  `completed`): "Bottom sheet de creación de usuario (propuesta 44):
  primer showModalBottomSheet de la app — handle + título + 3
  QuesivoTextField + RoleSelectorChips + CTA; validación manual al
  submit contra la misma política del backend. Mueve `QuesivoAuthField`
  a `core/widgets/QuesivoTextField` (primitiva de marca, no de auth) y
  extrae la extensión `UserRoleUi` (label+ícono) que consumen
  MemberRoleChip, RoleFilterChips y RoleSelectorChips. Solo UI — el
  submit inserta el miembro en el dataset local hasta integrar POST
  /auth/users."

---

## Orden de aplicación

1. Mover `quesivo_auth_field.dart` → `lib/core/widgets/quesivo_text_field.dart`
   con el rename a `QuesivoTextField`; actualizar los 4 consumidores de
   auth (import + nombre). Verificar que compile antes de seguir.
2. `user_role_ui.dart` (extensión) → actualizar `member_role_chip.dart`
   y `role_filter_chips.dart` para consumirla.
3. `role_selector_chips.dart`.
4. Keys l10n en los 3 arb + `flutter gen-l10n`.
5. `new_user_sheet.dart` (necesita el campo, los chips y las keys).
6. `users_screen.dart` — `_openNewUserSheet` + import + doc de clase.
7. Tests: los dos archivos nuevos + los dos casos nuevos del screen test.
8. `dart format`, `flutter analyze`, `flutter test`.
9. Spec + bump `1.9.0` en `Design/quesivo-design-system.yaml`.
