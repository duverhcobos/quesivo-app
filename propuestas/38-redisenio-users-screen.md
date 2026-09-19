# Propuesta 38 — Rediseño `users_screen`: cabecera navy del módulo

La UI de la propuesta 37 quedó **genérica**: fondo blanco + backdrop
decorativo + lista estándar = "cualquier app Material". Este rediseño
aplica la skill `frontend-design`:

- **Se elimina el `QuesivoBackdrop` completo** (círculo queso + arco
  navy): decoración sin significado — el usuario lo pidió fuera.
- **El elemento firma es la cabecera navy del módulo**: bloque
  `quesivoNavy` con esquinas inferiores redondeadas (r28 — eco del pill
  del `QuesivoNavBar`) que contiene título, subtítulo, **stats de
  dominio** y el botón primario amarillo. El navy es el color que la app
  ya usa con intención (ShellHeader, NavBar, Drawer) — el módulo pasa a
  ser un sándwich de marca coherente.
- **Stats reales** en la cabecera: "N miembros · N activos" calculados de
  la lista (hoy los `_sampleMembers`, mañana el `GET`) — números del
  dominio, no texto de relleno.
- **El rol gana ícono de dominio quesero** en su chip: 🛡 admin,
  ⚙ operario, 🚛 recolector, 🚜 productor.
- Body pasa a `quesivoSurface` (#F7F9FC) — las cards blancas separan sin
  necesidad de decoración.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `features/users/presentation/screens/users_screen.dart` | reescrito — hero navy + body surface, sin backdrop |
| `features/users/presentation/widgets/member_stats_row.dart` | **nuevo** — stats miembros/activos |
| `features/users/presentation/widgets/member_role_chip.dart` | + ícono por rol |
| `lib/l10n/app_{es,en,pt}.arb` | 2 keys plurales nuevas + `flutter gen-l10n` |
| `test/features/users/presentation/screens/users_screen_test.dart` | + asserts de stats |
| `Design/quesivo-design-system.yaml` | spec actualizada + changelog 1.7.1 |

## Visual

```
┌─────────────────────────────────┐
│ ● Xiomi                    ☰    │ ← ShellHeader (sin cambios)
│   Tienda 6 de enero             │
│←                                │
│ Usuarios                        │ ← NAVY: título blanco 28/w800
│ El equipo de tu quesera         │   subtítulo blanco 65%
│ ● 3 miembros    ● 2 activos     │   dots amarillo + success
│ ┌─────────────────────────────┐ │
│ │        Nuevo usuario        │ │ ← pill amarillo sobre navy
│ └─────────────────────────────┘ │
╰─────────────────────────────────╯ ← esquinas inferiores r28
│ ┌─────────────────────────────┐ │   body surface #F7F9FC
│ │ ○AP Ana Pérez            ⋮  │ │
│ │     ana.perez@mail.com      │ │
│ │     🛡Administrador ●Activo │ │
│ └─────────────────────────────┘ │
│              ⋮                  │
├─────────────────────────────────┤
│  🏠    🥛    🏭    💰           │
└─────────────────────────────────┘
```

---

## 1. `users_screen.dart` (archivo existente — reescritura completa)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../widgets/member_stats_row.dart';
import '../widgets/org_member_card.dart';
import '../widgets/users_empty_state.dart';

/// Pantalla principal del módulo Usuarios (`/home/usuarios` — hija del
/// branch Inicio). Solo UI: el listado se pinta con `_sampleMembers`
/// estáticos hasta la propuesta que integre `GET /auth/users`; "Nuevo
/// usuario" y las acciones de fila son placeholders visuales.
///
/// Rediseño §38: la identidad la carga la **cabecera navy del módulo**
/// (bloque navy r28 con título + stats + botón primario amarillo —
/// sándwich de marca entre ShellHeader y NavBar) sobre body
/// `quesivoSurface`; el backdrop decorativo de la §37 se eliminó.
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

    return Scaffold(
      backgroundColor: AppColors.quesivoSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabecera navy del módulo (elemento firma §38) ──
            Container(
              decoration: const BoxDecoration(
                color: AppColors.quesivoNavy,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
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
                          color: AppColors.quesivoWhite,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.orgUsersItem,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.quesivoWhite,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.usersSubtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.quesivoWhite.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        MemberStatsRow(members: _sampleMembers),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Listado sobre surface ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _sampleMembers.isEmpty
                    ? const UsersEmptyState()
                    : ListView.separated(
                        itemCount: _sampleMembers.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            OrgMemberCard(member: _sampleMembers[index]),
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

## 2. `member_stats_row.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/member_stats_row.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Fila de stats del listado de Usuarios dentro de la cabecera navy —
/// "N miembros · N activos" calculados de la lista real (dot amarillo =
/// total, dot success = activos). Números de dominio, no decoración.
class MemberStatsRow extends StatelessWidget {
  const MemberStatsRow({super.key, required this.members});

  final List<OrgMember> members;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = members
        .where((m) => m.status == MemberStatus.active)
        .length;

    return Row(
      children: [
        _StatDot(
          color: AppColors.quesivoYellow,
          label: l10n.membersCount(members.length),
        ),
        const SizedBox(width: 16),
        _StatDot(
          color: AppColors.quesivoSuccess,
          label: l10n.activeMembersCount(active),
        ),
      ],
    );
  }
}

/// Punto de color + label blanco — unidad visual de un stat.
class _StatDot extends StatelessWidget {
  const _StatDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.quesivoWhite,
          ),
        ),
      ],
    );
  }
}
```

## 3. `member_role_chip.dart` (archivo existente — actualización)

**Ruta:** `lib/features/users/presentation/widgets/member_role_chip.dart`

**Antes:**

```dart
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
```

**Después:**

```dart
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.quesivoIconSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: AppColors.quesivoNavy),
          const SizedBox(width: 5),
          Text(
            _label(l10n),
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
```

> Si `engineering_outlined`/`agriculture_outlined` no existieran en la
> versión de Material Icons del proyecto, usar el ícono base
> (`Icons.engineering` / `Icons.agriculture`) — a 13px la diferencia de
> trazo es imperceptible.

## 4. l10n — 2 keys plurales nuevas

**Rutas:** `lib/l10n/app_{es,en,pt}.arb` → después `flutter gen-l10n`.

**app_es.arb:**

```json
  "membersCount": "{count, plural, =1{# miembro} other{# miembros}}",
  "@membersCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "activeMembersCount": "{count, plural, =1{# activo} other{# activos}}",
  "@activeMembersCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

**app_en.arb:**

```json
  "membersCount": "{count, plural, =1{# member} other{# members}}",
  "@membersCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "activeMembersCount": "{count, plural, =1{# active} other{# active}}",
  "@activeMembersCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

**app_pt.arb:**

```json
  "membersCount": "{count, plural, =1{# membro} other{# membros}}",
  "@membersCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "activeMembersCount": "{count, plural, =1{# ativo} other{# ativos}}",
  "@activeMembersCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

## 5. `users_screen_test.dart` (archivo existente — actualización)

**Ruta:** `test/features/users/presentation/screens/users_screen_test.dart`

**Antes:**

```dart
    expect(find.text('Usuarios'), findsOneWidget);
    expect(find.text('Nuevo usuario'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Juan Gómez'), findsOneWidget);
    expect(find.text('Pedro Ruiz'), findsOneWidget);
```

**Después:**

```dart
    expect(find.text('Usuarios'), findsOneWidget);
    expect(find.text('Nuevo usuario'), findsOneWidget);
    // Stats de la cabecera navy: 3 muestras, 2 activas (§38).
    expect(find.text('3 miembros'), findsOneWidget);
    expect(find.text('2 activos'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Juan Gómez'), findsOneWidget);
    expect(find.text('Pedro Ruiz'), findsOneWidget);
```

## 6. Design system (`Design/quesivo-design-system.yaml`)

- `version`: `1.7.0` → `1.7.1`.
- `pages.users_screen`: actualizar la spec — **sin backdrop**; cabecera
  navy r28 (título 28/w800/blanco, subtítulo 14 blanco 65%, stats
  `member_stats_row` = dot 8px + label 13/w500/blanco, botón
  `QuesivoPrimaryButton` dentro del bloque navy); body `quesivoSurface`;
  `member_role_chip` + ícono de dominio 13px (shield/engineering/
  local_shipping/agriculture).
- Changelog: "1.7.1 — Rediseño users_screen (propuesta 38): se elimina
  el backdrop decorativo; la identidad la carga la cabecera navy r28 del
  módulo con stats de dominio (miembros/activos) y el botón primario
  amarillo embebido; el chip de rol gana ícono quesero por rol".

## Orden de aplicación

1. Keys l10n plurales → `flutter gen-l10n`.
2. `member_stats_row.dart` nuevo.
3. `member_role_chip.dart` — ícono por rol.
4. `users_screen.dart` — reescritura (hero navy + body surface).
5. Actualizar `users_screen_test.dart`.
6. Spec + changelog 1.7.1 en el yaml.
7. Verificación: `flutter analyze`, `flutter test`, `dart format`.

## Notas

- `users_empty_state.dart` y el resto de widgets no cambian — el empty
  state sigue funcionando sobre el fondo surface.
- La cabecera navy va `SafeArea`-adentro del body del shell: el
  `MainLayout` ya removió el inset superior, así que el bloque arranca
  pegado al ShellHeader — continuidad visual navy→navy.
- Los íconos de rol son una decisión de diseño deliberada (vocabulario
  quesero); si alguno no convence se ajusta en `_icon` sin tocar
  estructura.
