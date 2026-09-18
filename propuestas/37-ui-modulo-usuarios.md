# Propuesta 37 — UI del módulo Usuarios: pantalla principal (sin integración)

Primera propuesta del módulo **Usuarios** (`/home/usuarios`). Alcance:
**solo UI** — la pantalla principal con su estructura final (título, botón
"Nuevo usuario", listado de miembros con cards) pintada con **2-3 filas de
muestra estáticas**. No hay datasource, repository, cubit, use-case ni
llamadas al backend: la integración de los 4 endpoints
(`POST/GET /auth/users`, `PATCH .../status`, `PATCH .../password`) se hace
después, endpoint por endpoint, sobre esta UI ya aprobada.

Se crean las dos entidades de dominio mínimas (`UserRole`, `OrgMember` +
`MemberStatus`) para que la card y los chips trabajen tipados desde el día
uno — son las mismas entidades que reusará la integración.

**Fuera de alcance**: bottom sheet de creación, diálogos de
suspender/reactivar y restablecer contraseña, empty state conectado (el
widget queda listo pero la lista de muestra nunca está vacía), cualquier
código de capa data/domain más allá de las entidades.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/widgets/quesivo_primary_button.dart` | **movido** desde `features/auth/presentation/widgets/` — es componente de marca (§primary_button), no de auth |
| `lib/core/widgets/user_initials_avatar.dart` | **movido** desde `features/shell/presentation/widgets/` — mismo motivo |
| 4 archivos auth + 2 shell | solo cambia la línea de import por el nuevo path |
| `features/users/domain/entities/user_role.dart` | nuevo — enum de roles del contrato |
| `features/users/domain/entities/org_member.dart` | nuevo — entidad miembro + `MemberStatus` |
| `features/users/presentation/screens/users_screen.dart` | nuevo — pantalla principal |
| `features/users/presentation/widgets/org_member_card.dart` | nuevo — card de miembro |
| `features/users/presentation/widgets/member_role_chip.dart` | nuevo — chip de rol |
| `features/users/presentation/widgets/member_status_chip.dart` | nuevo — chip de estado |
| `features/users/presentation/widgets/member_actions_menu.dart` | nuevo — menú ⋮ (visual) |
| `features/users/presentation/widgets/users_empty_state.dart` | nuevo — estado vacío |
| `lib/core/routes/app_router.dart` | la ruta `usuarios` pinta `UsersScreen` |
| `lib/l10n/app_{es,en,pt}.arb` | 12 keys nuevas + `flutter gen-l10n` |
| `Design/quesivo-design-system.yaml` | spec `users_screen` + changelog, bump 1.7.0 |
| `test/features/users/...` | 2 tests de widgets |

## Visual — qué ve el admin al entrar por el drawer

El tap en "Usuarios" (drawer → Configuración) cambia el cuerpo dentro del
shell: la banda navy del header y la nav bar quedan igual.

```
┌─────────────────────────────────┐
│ ● Ana Pérez                ☰    │ ← ShellHeader (shell, sin cambios)
│   Quesera La Pradera            │
├─────────────────────────────────┤
│ ←                               │
│ Usuarios                        │
│ Gestiona quiénes acceden a tu   │
│ quesera.                        │
│ ┌─────────────────────────────┐ │
│ │        Nuevo usuario        │ │ ← pill amarillo 64px de marca
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ ○AP Ana Pérez            ⋮  │ │
│ │     ana.perez@mail.com      │ │
│ │     [Administrador] ●Activo │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ ○JG Juan Gómez           ⋮  │ │
│ │     juan.gomez@mail.com     │ │
│ │     [Operario]   ●Activo    │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ ○PR Pedro Ruiz           ⋮  │ │
│ │     pedro.ruiz@mail.com     │ │
│ │     [Recolector] ●Suspendido│ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│   🏠      🥛      🏭      💰    │ ← NavBar (shell, sin cambios)
└─────────────────────────────────┘
```

- Misma envoltura visual que el placeholder actual: `QuesivoBackdrop`
  estático (círculo amarillo 0.5 arriba) + arco navy abajo-derecha.
- Back arrow arriba-izquierda solo si `context.canPop()` (paridad con el
  placeholder — la ruta entra por `push` desde el drawer).
- "Nuevo usuario" → SnackBar `moduleComingSoon` (el sheet llega después).
- ⋮ abre el `PopupMenu` con las 2 acciones (Suspender/Reactivar según
  estado + Restablecer contraseña) → cada una muestra `moduleComingSoon`.

---

## 1. `quesivo_primary_button.dart` → `lib/core/widgets/` (movido)

**Ruta nueva:** `lib/core/widgets/quesivo_primary_button.dart`

El contenido no cambia — solo se mueve el archivo (es el pill amarillo
64px de marca §primary_button; los módulos también lo necesitan, no es
exclusivo de auth). Se borra el archivo viejo.

**Imports a actualizar** (mismo cambio en los 4):

```dart
// Antes (en login_actions.dart, register_actions.dart,
// forgot_password_actions.dart, reset_password_actions.dart):
import 'quesivo_primary_button.dart';

// Después:
import '../../../../core/widgets/quesivo_primary_button.dart';
```

## 2. `user_initials_avatar.dart` → `lib/core/widgets/` (movido)

**Ruta nueva:** `lib/core/widgets/user_initials_avatar.dart`

Contenido sin cambios — el avatar de iniciales (círculo amarillo, letras
navy) lo comparten header, drawer y ahora las cards de miembro.

**Imports a actualizar:**

```dart
// shell_header.dart — antes:
import 'user_initials_avatar.dart';
// después:
import '../../../../core/widgets/user_initials_avatar.dart';

// drawer_identity.dart — antes:
import '../user_initials_avatar.dart';
// después:
import '../../../../core/widgets/user_initials_avatar.dart';
```

## 3. `user_role.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/entities/user_role.dart`

```dart
/// Rol de una membresía dentro de la organización — catálogo fijo del
/// backend (`role` en `/auth/users`, §docs api/auth/007-008).
/// El label visible se resuelve en presentation vía l10n; `apiValue` se
/// usa al serializar hacia el API.
enum UserRole {
  admin('ADMIN'),
  operator('OPERATOR'),
  collector('COLLECTOR'),
  producer('PRODUCER');

  const UserRole(this.apiValue);

  /// Valor del contrato del backend.
  final String apiValue;

  /// Parse del string del API; `operator` como fallback defensivo — el
  /// catálogo es cerrado y lo controla el backend.
  static UserRole fromApi(String? value) => UserRole.values.firstWhere(
    (r) => r.apiValue == value,
    orElse: () => UserRole.operator,
  );
}
```

## 4. `org_member.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/entities/org_member.dart`

```dart
import 'package:equatable/equatable.dart';

import 'user_role.dart';

/// Estado de la membresía en la organización (`status` del contrato).
enum MemberStatus { active, suspended }

/// Miembro de la organización activa — una fila del listado de usuarios
/// (`UserListItem` del backend). La organización nunca viaja en el body:
/// la infiere el JWT del admin.
class OrgMember extends Equatable {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final MemberStatus status;
  final String organizationId;

  const OrgMember({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.organizationId,
  });

  @override
  List<Object?> get props => [id, email, name, role, status, organizationId];
}
```

## 5. `users_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../widgets/org_member_card.dart';
import '../widgets/users_empty_state.dart';

/// Pantalla principal del módulo Usuarios (`/home/usuarios` — hija del
/// branch Inicio, propuesta 37). Solo UI: el listado se pinta con
/// `_sampleMembers` estáticos hasta la propuesta que integre
/// `GET /auth/users`; "Nuevo usuario" y las acciones de fila son
/// placeholders visuales (el sheet de creación y los diálogos llegan
/// con sus propias propuestas).
///
/// Misma envoltura visual que `ModulePlaceholderScreen`: backdrop de
/// marca + arco navy abajo-derecha, dentro del `MainLayout` (header y
/// nav bar quedan del shell).
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  /// Filas de muestra para validar el diseño de la card y los chips —
  /// se eliminan al integrar `GET /auth/users`. `final` (no `const`)
  /// para que el check `isEmpty` no quede evaluado en compile-time.
  static final _sampleMembers = <OrgMember>[
    const OrgMember(
      id: 'sample-1',
      email: 'ana.perez@mail.com',
      name: 'Ana Pérez',
      role: UserRole.admin,
      status: MemberStatus.active,
      organizationId: 'sample-org',
    ),
    const OrgMember(
      id: 'sample-2',
      email: 'juan.gomez@mail.com',
      name: 'Juan Gómez',
      role: UserRole.operator,
      status: MemberStatus.active,
      organizationId: 'sample-org',
    ),
    const OrgMember(
      id: 'sample-3',
      email: 'pedro.ruiz@mail.com',
      name: 'Pedro Ruiz',
      role: UserRole.collector,
      status: MemberStatus.suspended,
      organizationId: 'sample-org',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        topCircleFraction: 0.5,
        bottomCircleFraction: 0,
        animate: false,
        child: Stack(
          children: [
            // Arco navy abajo-derecha — misma decoración que el
            // placeholder del módulo (Positioned negativo + ClipOval).
            Positioned(
              bottom: -screenWidth * 0.275,
              right: -screenWidth * 0.275,
              child: ClipOval(
                child: ColoredBox(
                  color: AppColors.quesivoNavy,
                  child: SizedBox(
                    width: screenWidth * 0.55,
                    height: screenWidth * 0.55,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (context.canPop())
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.quesivoNavy,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.orgUsersItem,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.quesivoNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.usersSubtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.quesivoTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          QuesivoPrimaryButton(
                            label: l10n.newUserButton,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.moduleComingSoon),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _sampleMembers.isEmpty
                                ? const UsersEmptyState()
                                : ListView.separated(
                                    itemCount: _sampleMembers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) =>
                                        OrgMemberCard(
                                          member: _sampleMembers[index],
                                        ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 6. `org_member_card.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/org_member_card.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_initials_avatar.dart';
import '../../domain/entities/org_member.dart';
import 'member_actions_menu.dart';
import 'member_role_chip.dart';
import 'member_status_chip.dart';

/// Card de un miembro de la organización en el listado de Usuarios:
/// avatar de iniciales + nombre + email + chips de rol/estado + menú de
/// acciones ⋮ (visual — los diálogos llegan con su propuesta).
class OrgMemberCard extends StatelessWidget {
  const OrgMemberCard({super.key, required this.member});

  final OrgMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.quesivoWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.quesivoBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.quesivoShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserInitialsAvatar(
            displayName: member.name,
            size: 46,
            fontSize: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quesivoDarkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.quesivoTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    MemberRoleChip(role: member.role),
                    MemberStatusChip(status: member.status),
                  ],
                ),
              ],
            ),
          ),
          MemberActionsMenu(status: member.status),
        ],
      ),
    );
  }
}
```

## 7. `member_role_chip.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/member_role_chip.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_role.dart';

/// Chip del rol de la membresía — pill `quesivoIconSurface` con label
/// navy. El label se resuelve vía l10n (el rol nunca se muestra crudo
/// del contrato).
class MemberRoleChip extends StatelessWidget {
  const MemberRoleChip({super.key, required this.role});

  final UserRole role;

  String _label(AppLocalizations l10n) => switch (role) {
    UserRole.admin => l10n.adminRole,
    UserRole.operator => l10n.roleOperator,
    UserRole.collector => l10n.roleCollector,
    UserRole.producer => l10n.roleProducer,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.quesivoIconSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(l10n),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.quesivoNavy,
        ),
      ),
    );
  }
}
```

## 8. `member_status_chip.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/member_status_chip.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Chip del estado de la membresía — pill con punto + label:
/// `active` en `quesivoSuccess`, `suspended` en `quesivoError`.
class MemberStatusChip extends StatelessWidget {
  const MemberStatusChip({super.key, required this.status});

  final MemberStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (color, label) = switch (status) {
      MemberStatus.active => (
        AppColors.quesivoSuccess,
        l10n.memberStatusActive,
      ),
      MemberStatus.suspended => (
        AppColors.quesivoError,
        l10n.memberStatusSuspended,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
```

## 9. `member_actions_menu.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/member_actions_menu.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Menú ⋮ de acciones por fila del listado de Usuarios — visual por
/// ahora: cada opción muestra `moduleComingSoon`. Los diálogos de
/// suspender/reactivar y restablecer contraseña llegan con su propuesta.
/// "Suspender usuario" se tiñe `quesivoError` (acción destructiva —
/// mismo criterio que logout en el drawer).
class MemberActionsMenu extends StatelessWidget {
  const MemberActionsMenu({super.key, required this.status});

  final MemberStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suspended = status == MemberStatus.suspended;

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: AppColors.quesivoTextSecondary,
      ),
      tooltip: l10n.memberActionsTooltip,
      onSelected: (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.moduleComingSoon)),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'status',
          child: Row(
            children: [
              Icon(
                suspended
                    ? Icons.check_circle_outline
                    : Icons.block_outlined,
                size: 20,
                color: suspended
                    ? AppColors.quesivoDarkText
                    : AppColors.quesivoError,
              ),
              const SizedBox(width: 12),
              Text(
                suspended
                    ? l10n.reactivateUserAction
                    : l10n.suspendUserAction,
                style: TextStyle(
                  color: suspended
                      ? AppColors.quesivoDarkText
                      : AppColors.quesivoError,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'password',
          child: Row(
            children: [
              const Icon(
                Icons.lock_reset,
                size: 20,
                color: AppColors.quesivoDarkText,
              ),
              const SizedBox(width: 12),
              Text(l10n.resetPasswordAction),
            ],
          ),
        ),
      ],
    );
  }
}
```

## 10. `users_empty_state.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/users_empty_state.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// Estado vacío del listado de Usuarios — mismo lenguaje visual que
/// `ModulePlaceholderScreen` (círculo iconSurface + título + hint).
class UsersEmptyState extends StatelessWidget {
  const UsersEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.quesivoIconSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.group_outlined,
              size: 44,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.emptyUsersTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emptyUsersHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
```

## 11. `app_router.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Import nuevo** (junto a los imports de screens existentes):

```dart
import '../../features/users/presentation/screens/users_screen.dart';
```

**Antes:**

```dart
                  GoRoute(
                    path: 'usuarios',
                    pageBuilder: (context, state) => CustomTransitions.fade(
                      context: context,
                      state: state,
                      child: ModulePlaceholderScreen(
                        icon: Icons.group_outlined,
                        label: AppLocalizations.of(context)!.orgUsersItem,
                      ),
                    ),
                  ),
```

**Después:**

```dart
                  GoRoute(
                    path: 'usuarios',
                    pageBuilder: (context, state) => CustomTransitions.fade(
                      context: context,
                      state: state,
                      child: const UsersScreen(),
                    ),
                  ),
```

> `ModulePlaceholderScreen` se sigue usando en `organizacion` — su
> import no se toca. La ruta, el drawer y el `selected` no cambian.

## 12. l10n — keys nuevas

**Rutas:** `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_pt.arb`
(alfabéticamente donde corresponda; después `flutter gen-l10n`).

**app_es.arb:**

```json
  "usersSubtitle": "Gestiona quiénes acceden a tu quesera.",
  "newUserButton": "Nuevo usuario",
  "roleOperator": "Operario",
  "roleCollector": "Recolector",
  "roleProducer": "Productor",
  "memberStatusActive": "Activo",
  "memberStatusSuspended": "Suspendido",
  "memberActionsTooltip": "Opciones del usuario",
  "suspendUserAction": "Suspender usuario",
  "reactivateUserAction": "Reactivar usuario",
  "resetPasswordAction": "Restablecer contraseña",
  "emptyUsersTitle": "Todavía no hay usuarios",
  "emptyUsersHint": "Los usuarios que crees para tu quesera aparecerán acá.",
```

**app_en.arb:**

```json
  "usersSubtitle": "Manage who can access your cheese factory.",
  "newUserButton": "New user",
  "roleOperator": "Operator",
  "roleCollector": "Collector",
  "roleProducer": "Producer",
  "memberStatusActive": "Active",
  "memberStatusSuspended": "Suspended",
  "memberActionsTooltip": "User options",
  "suspendUserAction": "Suspend user",
  "reactivateUserAction": "Reactivate user",
  "resetPasswordAction": "Reset password",
  "emptyUsersTitle": "No users yet",
  "emptyUsersHint": "Users you create for your cheese factory will appear here.",
```

**app_pt.arb:**

```json
  "usersSubtitle": "Gerencie quem pode acessar sua queijaria.",
  "newUserButton": "Novo usuário",
  "roleOperator": "Operador",
  "roleCollector": "Coletor",
  "roleProducer": "Produtor",
  "memberStatusActive": "Ativo",
  "memberStatusSuspended": "Suspenso",
  "memberActionsTooltip": "Opções do usuário",
  "suspendUserAction": "Suspender usuário",
  "reactivateUserAction": "Reativar usuário",
  "resetPasswordAction": "Redefinir senha",
  "emptyUsersTitle": "Ainda não há usuários",
  "emptyUsersHint": "Os usuários que você criar para sua queijaria aparecerão aqui.",
```

**Reusadas** (ya existen): `orgUsersItem` (título), `adminRole`
("Administrador" — chip de rol admin), `moduleComingSoon` (snackbar de
los placeholders).

## 13. Tests (archivos nuevos)

**`test/features/users/presentation/widgets/org_member_card_test.dart`** —
pump de la card con un `OrgMember` de cada tipo:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/widgets/org_member_card.dart';
import 'package:quesivo/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  const member = OrgMember(
    id: '1',
    email: 'ana@mail.com',
    name: 'Ana Pérez',
    role: UserRole.admin,
    status: MemberStatus.active,
    organizationId: 'org',
  );

  testWidgets('renderiza nombre, email y chips de rol/estado', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const OrgMemberCard(member: member)));
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@mail.com'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
  });

  testWidgets('miembro suspendido muestra chip Suspendido', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OrgMemberCard(
          member: OrgMember(
            id: '2',
            email: 'p@mail.com',
            name: 'Pedro',
            role: UserRole.collector,
            status: MemberStatus.suspended,
            organizationId: 'org',
          ),
        ),
      ),
    );
    expect(find.text('Suspendido'), findsOneWidget);
    expect(find.text('Recolector'), findsOneWidget);
  });
}
```

**`test/features/users/presentation/screens/users_screen_test.dart`** —
la pantalla renderiza título, botón y las filas de muestra:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/presentation/screens/users_screen.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  testWidgets('muestra título, botón Nuevo usuario y filas de muestra', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UsersScreen(),
      ),
    );

    expect(find.text('Usuarios'), findsOneWidget);
    expect(find.text('Nuevo usuario'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Juan Gómez'), findsOneWidget);
    expect(find.text('Pedro Ruiz'), findsOneWidget);
  });
}
```

> Si el proyecto tiene un helper de pump con l10n (revisar
> `drawer_menu_item_row_test.dart` al aplicar), usarlo en vez del
> `MaterialApp` inline.

## 14. Design system (`Design/quesivo-design-system.yaml`)

- `version`: `1.6.1` → `1.7.0`.
- Nueva spec `users_screen` bajo la sección de pantallas del shell:
  envoltura (backdrop + arco navy como `module_placeholder`), header de
  módulo (título 28/w800/navy + subtítulo 14/secondary), botón primario
  `QuesivoPrimaryButton` (pill amarillo 64px), y `org_member_card`
  (card blanca r16, borde `quesivoBorder`, sombra `quesivoShadow`
  12px/0,4; avatar `UserInitialsAvatar` 46px; nombre 15/w700/darkText;
  email 13/secondary; chips: rol = pill `quesivoIconSurface` label navy
  12/w600, estado = pill alpha 0.12 + punto 6px + label en
  success/error; menú ⋮ `more_vert` secondary con acciones).
- Changelog: "1.7.0 — UI del módulo Usuarios (pantalla principal con
  cards de miembro + chips rol/estado + menú ⋮ visual; `QuesivoPrimaryButton`
  y `UserInitialsAvatar` promovidos a `core/widgets`)".

## Orden de aplicación

1. Mover `quesivo_primary_button.dart` y `user_initials_avatar.dart` a
   `lib/core/widgets/` y actualizar los 6 imports (auth ×4, shell ×2).
2. Entidades: `user_role.dart`, `org_member.dart`.
3. Keys l10n en los 3 ARB → `flutter gen-l10n`.
4. Widgets: `member_role_chip`, `member_status_chip`,
   `member_actions_menu`, `org_member_card`, `users_empty_state`.
5. `users_screen.dart` + cambio en `app_router.dart`.
6. Tests de widgets.
7. Spec + changelog en `Design/quesivo-design-system.yaml`.
8. Verificación: `flutter analyze`, `flutter test`, `dart format` en los
   archivos tocados.

## Notas / decisiones

- **Por qué se mueven 2 widgets a `core/`**: `QuesivoPrimaryButton` y
  `UserInitialsAvatar` son primitivas de marca compartidas — importarlas
  desde `features/auth`/`features/shell` hacia `features/users` crearía
  acoplamiento feature→feature. `core/widgets` ya es la casa de
  `QuesivoBackdrop`.
- **Los datos de muestra** viven en `_sampleMembers` (screen) y están
  marcados para eliminarse en la integración del `GET`.
- **Estados cubiertos por la muestra**: 3 roles (admin/operator/
  collector) + ambos estados (active/suspended) — suficiente para
  aprobar el diseño. `producer` queda visible cuando llegue la data real.
- **La pantalla no lleva Cubit** — no hay estado que orquestar todavía;
  el patrón `Screen → BlocProvider → _View` se introduce cuando el sheet
  de creación o la integración lo necesiten.
- **i18n de failures**: los mensajes de error del futuro `UsersFailure`
  irán embebidos en las clases de failure (convención `AuthFailure`), no
  en ARB — queda para las propuestas de integración.
