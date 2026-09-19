# Propuesta: Búsqueda, filtros por rol y scroll paginado en Usuarios

Dos pendientes del módulo:

1. **Falta el rol Productor** en las filas de muestra — `MemberRoleChip` y `UserRole` ya lo soportan (§38), pero `_sampleMembers` solo cubre admin/operario/recolector.
2. **Cómo se maneja una organización con 50+ usuarios** — pregunta directa del usuario. Decisión (confirmada en sesión): **búsqueda + filtros por rol, ambos locales por ahora** (el backend `GET /auth/users` hoy solo pagina — `page`/`limit`, sin query params de texto/rol, doc `008-get-users.md`) **+ scroll paginado real** (se cargan de a tandas mientras se scrollea, no las 54 de una — así se valida la UX de paginación antes de integrar el endpoint real, que ya devuelve `meta.total/totalPages` en esa misma forma).

Sigue siendo **solo UI**: el dataset de 54 miembros es sintético, la carga "paginada" es un `Future.delayed` local — al integrar `GET /auth/users` se reemplaza el generador por el repositorio real y la búsqueda/filtro se decide si migra a query params del servidor, sin tocar la estructura visual.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/users/presentation/screens/sample_org_members.dart` | **nuevo** — generador de 54 `OrgMember` (9×6 nombres, 4 roles, incluye Productor) |
| `lib/features/users/presentation/widgets/users_search_field.dart` | **nuevo** — campo de búsqueda por nombre/correo |
| `lib/features/users/presentation/widgets/role_filter_chips.dart` | **nuevo** — chips horizontales "Todos" + 4 roles |
| `lib/features/users/presentation/widgets/users_list_footer_loader.dart` | **nuevo** — spinner al pie de la lista mientras carga la siguiente tanda |
| `lib/features/users/presentation/screens/users_screen.dart` | `StatelessWidget` → `StatefulWidget`: estado de búsqueda/filtro/paginación local + scroll listener |
| `lib/features/users/presentation/widgets/users_empty_state.dart` | icon/title/hint opcionales — reusa el widget para "sin resultados" de búsqueda |
| `lib/l10n/app_{es,en,pt}.arb` | 4 keys nuevas: `searchUsersHint`, `roleFilterAll`, `noSearchResultsTitle`, `noSearchResultsHint` |
| `test/features/users/presentation/screens/users_screen_test.dart` | casos nuevos: carga inicial paginada, búsqueda, filtro por rol, sin resultados |
| `test/features/users/presentation/widgets/role_filter_chips_test.dart` | **nuevo** |
| `test/features/users/presentation/widgets/users_search_field_test.dart` | **nuevo** |
| `Design/quesivo-design-system.yaml` | spec de búsqueda/filtros/paginación + versión 1.7.5 → **1.8.0** + changelog |

Sin cambios de DI ni rutas (sigue sin Cubit/repositorio real).

---

## 1. `sample_org_members.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/screens/sample_org_members.dart`

```dart
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';

/// Genera 54 miembros sintéticos (9 nombres × 6 apellidos, combinación
/// única cada uno) para validar el listado con volumen real antes de
/// integrar `GET /auth/users` — reemplaza a este generador por el
/// repositorio real en esa propuesta. Cubre los 4 roles del catálogo
/// (incluye Productor, ausente en la muestra original de §37) y un ~15%
/// de suspendidos para que los filtros y el chip de estado tengan algo
/// que mostrar.
List<OrgMember> generateSampleOrgMembers() {
  const firstNames = [
    'Ana',
    'Juan',
    'Pedro',
    'María',
    'Carlos',
    'Lucía',
    'Diego',
    'Valentina',
    'Martín',
  ];
  const lastNames = [
    'Pérez',
    'Gómez',
    'Ruiz',
    'Fernández',
    'Torres',
    'Molina',
  ];
  // Formas ASCII para el correo — evita depender de una función de
  // normalización solo para este generador temporal.
  const firstNamesAscii = [
    'ana',
    'juan',
    'pedro',
    'maria',
    'carlos',
    'lucia',
    'diego',
    'valentina',
    'martin',
  ];
  const lastNamesAscii = [
    'perez',
    'gomez',
    'ruiz',
    'fernandez',
    'torres',
    'molina',
  ];

  final members = <OrgMember>[];
  var index = 0;
  for (var f = 0; f < firstNames.length; f++) {
    for (var l = 0; l < lastNames.length; l++) {
      final role = UserRole.values[index % UserRole.values.length];
      final status = index % 7 == 0
          ? MemberStatus.suspended
          : MemberStatus.active;
      members.add(
        OrgMember(
          id: 'sample-$index',
          email: '${firstNamesAscii[f]}.${lastNamesAscii[l]}@mail.com',
          name: '${firstNames[f]} ${lastNames[l]}',
          role: role,
          status: status,
          organizationId: 'sample-org',
        ),
      );
      index++;
    }
  }
  return members;
}
```

---

## 2. `users_search_field.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/users_search_field.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// Campo de búsqueda del listado de Usuarios — filtra por nombre o
/// correo sobre lo ya cargado (local; server-side query queda para
/// cuando `GET /auth/users` lo soporte). El ícono de limpiar solo
/// aparece con texto cargado (`ValueListenableBuilder` sobre el propio
/// `controller`, sin rebuild del padre).
class UsersSearchField extends StatelessWidget {
  const UsersSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.quesivoBorder),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchUsersHint,
            hintStyle: const TextStyle(color: AppColors.quesivoTextSecondary),
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.quesivoTextSecondary,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.quesivoTextSecondary,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            filled: true,
            fillColor: AppColors.quesivoWhite,
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(
                color: AppColors.quesivoNavy,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
      },
    );
  }
}
```

---

## 3. `role_filter_chips.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/role_filter_chips.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_role.dart';

/// Fila de chips horizontales para filtrar el listado por rol — "Todos"
/// (`selected == null`) + los 4 roles del catálogo, mismos íconos de
/// dominio que `MemberRoleChip` (§38) para que el vocabulario visual sea
/// el mismo en el chip de fila y en el filtro.
class RoleFilterChips extends StatelessWidget {
  const RoleFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// `null` = "Todos".
  final UserRole? selected;
  final ValueChanged<UserRole?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(UserRole?, String, IconData?)>[
      (null, l10n.roleFilterAll, null),
      (UserRole.admin, l10n.adminRole, Icons.shield_outlined),
      (UserRole.operator, l10n.roleOperator, Icons.engineering_outlined),
      (UserRole.collector, l10n.roleCollector, Icons.local_shipping_outlined),
      (UserRole.producer, l10n.roleProducer, Icons.agriculture_outlined),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (role, label, icon) = options[index];
          return _RoleFilterChip(
            label: label,
            icon: icon,
            isSelected: role == selected,
            onTap: () => onChanged(role),
          );
        },
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
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

---

## 4. `users_list_footer_loader.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/widgets/users_list_footer_loader.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Spinner al pie del listado mientras `UsersScreen` "carga" la
/// siguiente tanda (scroll paginado local, §43). Última fila de
/// `ListView.separated` cuando `_isLoadingMore` es true.
class UsersListFooterLoader extends StatelessWidget {
  const UsersListFooterLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.quesivoNavy,
          ),
        ),
      ),
    );
  }
}
```

---

## 5. `users_empty_state.dart` (existente — actualización)

**Ruta:** `lib/features/users/presentation/widgets/users_empty_state.dart`

**Antes:**

```dart
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

**Después:**

```dart
class UsersEmptyState extends StatelessWidget {
  const UsersEmptyState({super.key, this.icon, this.title, this.hint});

  /// Overrides opcionales — §43: la búsqueda/filtro sin resultados reusa
  /// este widget con ícono/textos distintos en vez del vacío real de la
  /// org (`group_outlined` + `emptyUsers*`, que quedan como default).
  final IconData? icon;
  final String? title;
  final String? hint;

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
            child: Icon(
              icon ?? Icons.group_outlined,
              size: 44,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title ?? l10n.emptyUsersTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint ?? l10n.emptyUsersHint,
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

---

## 6. `users_screen.dart` (existente — reescritura)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

**Antes:** el archivo actual (`StatelessWidget`, `_sampleMembers` con 3 filas, `ListView.separated` sin búsqueda/filtro/paginación — ver §41/§42).

**Después:**

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../shell/presentation/widgets/shell_insets.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../widgets/member_stats_row.dart';
import '../widgets/org_member_card.dart';
import '../widgets/role_filter_chips.dart';
import '../widgets/users_empty_state.dart';
import '../widgets/users_list_footer_loader.dart';
import '../widgets/users_search_field.dart';
import 'sample_org_members.dart';

/// Pantalla principal del módulo Usuarios (`/home/usuarios` — hija del
/// branch Inicio). Solo UI: el listado se pinta con
/// `generateSampleOrgMembers()` hasta la propuesta que integre
/// `GET /auth/users`; "Nuevo usuario" y las acciones de fila son
/// placeholders visuales.
///
/// Rediseño §38: cabecera navy del módulo. §39: hero edge-to-edge
/// detrás del ShellHeader. §41/§42: hero mínimo sin back/subtítulo,
/// acción de creación icon-only.
///
/// §43: `StatefulWidget` — búsqueda + filtro por rol (locales sobre el
/// dataset de 54 muestras, `GET /auth/users` hoy no soporta query
/// params de texto/rol) y **scroll paginado**: se muestran de a
/// `_pageSize` filas y se cargan más al acercarse al final de la lista
/// (`Future.delayed` simula la latencia real; se reemplaza por
/// `GET /auth/users?page=` al integrar el endpoint). Sigue sin
/// Cubit/repositorio — todo el estado es de presentación pura.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _pageSize = 15;
  static const _loadMoreThreshold = 200.0;

  final _allMembers = generateSampleOrgMembers();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  UserRole? _roleFilter;
  String _query = '';
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  // Ignora una carga en vuelo si búsqueda/filtro cambiaron mientras
  // esperaba — evita que un Future viejo pise el estado del filtro nuevo.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<OrgMember> get _filteredMembers => _allMembers.where((m) {
    final matchesRole = _roleFilter == null || m.role == _roleFilter;
    final q = _query.trim().toLowerCase();
    final matchesQuery =
        q.isEmpty ||
        m.name.toLowerCase().contains(q) ||
        m.email.toLowerCase().contains(q);
    return matchesRole && matchesQuery;
  }).toList();

  bool _hasMore(List<OrgMember> filtered) => _visibleCount < filtered.length;

  void _onScroll() {
    if (_isLoadingMore) return;
    if (!_hasMore(_filteredMembers)) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final token = ++_loadToken;
    setState(() => _isLoadingMore = true);
    // Simula la latencia de red — reemplazar por
    // `GET /auth/users?page=` al integrar el endpoint.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || token != _loadToken) return;
    setState(() {
      _visibleCount = min(_visibleCount + _pageSize, _filteredMembers.length);
      _isLoadingMore = false;
    });
  }

  void _resetPagination() {
    _loadToken++;
    setState(() {
      _visibleCount = _pageSize;
      _isLoadingMore = false;
    });
  }

  void _onQueryChanged(String value) {
    _query = value;
    _resetPagination();
  }

  void _onRoleChanged(UserRole? role) {
    _roleFilter = role;
    _resetPagination();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filteredMembers;
    final visible = filtered.take(_visibleCount).toList();
    final isFiltering = _query.trim().isNotEmpty || _roleFilter != null;

    return Scaffold(
      backgroundColor: AppColors.quesivoSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabecera navy del módulo (elemento firma §38) ──
          Container(
            decoration: const BoxDecoration(
              color: AppColors.quesivoNavy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: context.shellHeaderHeight),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.orgUsersItem,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.quesivoWhite,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.moduleComingSoon)),
                              );
                            },
                            tooltip: l10n.newUserButton,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.quesivoYellow,
                              foregroundColor: AppColors.quesivoNavy,
                            ),
                            icon: const Icon(
                              Icons.person_add_outlined,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Stats siempre sobre el total de la org — no sobre
                      // lo filtrado/visible (§43).
                      MemberStatsRow(members: _allMembers),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Búsqueda + filtros (§43) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UsersSearchField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                ),
                const SizedBox(height: 12),
                RoleFilterChips(
                  selected: _roleFilter,
                  onChanged: _onRoleChanged,
                ),
              ],
            ),
          ),
          // ── Listado sobre surface ──
          Expanded(
            child: visible.isEmpty
                ? (isFiltering
                      ? UsersEmptyState(
                          icon: Icons.search_off,
                          title: l10n.noSearchResultsTitle,
                          hint: l10n.noSearchResultsHint,
                        )
                      : const UsersEmptyState())
                // Padding en el ListView (no en un wrapper): las cards
                // pueden scrollear bajo el nav navy y el último ítem sube
                // por encima — inset = shellNavBarHeight (§39).
                : ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      context.shellNavBarHeight,
                    ),
                    itemCount: visible.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= visible.length) {
                        return const UsersListFooterLoader();
                      }
                      return OrgMemberCard(member: visible[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

> Nota: el `IconButton` de la acción de creación conserva exactamente el estilo de §41/§42 (compacto 40px, sin cambios).

---

## 7. ARB — 4 keys nuevas

**Ruta:** `lib/l10n/app_es.arb` / `app_en.arb` / `app_pt.arb`

Insertar junto a las keys de usuarios existentes (`newUserButton`, `roleOperator`, ...):

```json
"searchUsersHint": "Buscar por nombre o correo",
"roleFilterAll": "Todos",
"noSearchResultsTitle": "Sin resultados",
"noSearchResultsHint": "Probá con otro nombre, correo o filtro."
```

**en:**

```json
"searchUsersHint": "Search by name or email",
"roleFilterAll": "All",
"noSearchResultsTitle": "No results",
"noSearchResultsHint": "Try another name, email, or filter."
```

**pt:**

```json
"searchUsersHint": "Buscar por nome ou e-mail",
"roleFilterAll": "Todos",
"noSearchResultsTitle": "Sem resultados",
"noSearchResultsHint": "Tente outro nome, e-mail ou filtro."
```

Ejecutar `flutter gen-l10n` después — no editar `app_localizations*.dart` a mano.

---

## 8. Tests

### `test/features/users/presentation/screens/users_screen_test.dart` (reescritura)

Casos:
1. Título + acción "Nuevo usuario" (tooltip) + stats sobre el total (54 miembros, no sobre lo visible).
2. Carga inicial muestra `_pageSize` (15) cards, no las 54 — valida que el scroll paginado arranca acotado.
3. Escribir en el buscador filtra por nombre/correo (`tester.enterText` + `pump`).
4. Búsqueda sin coincidencias muestra `noSearchResultsTitle`/`Icons.search_off`.
5. Tocar un chip de rol filtra por ese rol (cuenta de cards visibles baja).

### `test/features/users/presentation/widgets/role_filter_chips_test.dart` (nuevo)

- Renderiza "Todos" + 4 roles.
- Tap en un chip invoca `onChanged` con el rol correspondiente.

### `test/features/users/presentation/widgets/users_search_field_test.dart` (nuevo)

- `onChanged` se invoca al escribir.
- El ícono de limpiar aparece solo con texto, y al tocarlo limpia el controller e invoca `onChanged('')`.

---

## 9. `Design/quesivo-design-system.yaml`

- `version`: `1.7.5` → `1.8.0` (componentes nuevos — bump minor).
- Bajo `users_screen`, agregar sección `search_and_filters`:
  - `search_field`: `UsersSearchField` — `TextField` con borde `quesivoBorder` r14, ícono `search` navy secundario, clear condicional; filtra local por nombre/correo.
  - `role_filters`: `RoleFilterChips` — fila horizontal scrolleable, "Todos" + 4 roles con mismos íconos de `MemberRoleChip` (§38); seleccionado = fondo navy/texto blanco, no seleccionado = `quesivoIconSurface`/texto navy.
  - `pagination`: scroll paginado — `_pageSize` 15, carga la siguiente tanda a 200px del final (`UsersListFooterLoader`, spinner navy 22px); búsqueda/filtro reinician la paginación. Nota: local por ahora — `GET /auth/users` pagina por `page`/`limit` pero no filtra por texto/rol (doc `008-get-users.md`); la búsqueda/filtro migran a query params si el backend los agrega.
  - `empty_states`: `UsersEmptyState` con ícono/título/hint configurables — vacío real de la org (`group_outlined`) vs. sin resultados de búsqueda/filtro (`search_off`, `noSearchResultsTitle/Hint`).
- `changelog` — nueva entrada:

```yaml
  - version: "1.8.0"
    page: "users_screen"
    status: "completed"
    changes:
      - "Búsqueda + filtros por rol + scroll paginado (propuesta §43): la muestra estática de 3 filas pasa a un dataset sintético de 54 miembros (9×6 nombres) que ahora sí cubre los 4 roles — Productor faltaba desde §37."
      - "UsersSearchField (nuevo): filtra local por nombre/correo. RoleFilterChips (nuevo): 'Todos' + los 4 roles con los mismos íconos de dominio de MemberRoleChip. Ambos locales — GET /auth/users hoy solo pagina, no filtra por texto/rol (doc 008)."
      - "Scroll paginado real: se muestran 15 filas iniciales y se cargan de a 15 más al acercarse al final (UsersListFooterLoader), simulando la latencia de GET /auth/users?page= hasta integrarlo. Búsqueda/filtro reinician la paginación."
      - "UsersScreen pasa de StatelessWidget a StatefulWidget — primer estado de presentación local del módulo (búsqueda/filtro/paginación), todavía sin Cubit ni repositorio."
      - "UsersEmptyState gana icon/title/hint opcionales — reusa el mismo widget para 'sin resultados' de búsqueda (Icons.search_off) en vez de duplicar el estado vacío."
```

---

## Orden de aplicación

1. `sample_org_members.dart` — generador.
2. `users_search_field.dart`, `role_filter_chips.dart`, `users_list_footer_loader.dart` — widgets nuevos.
3. `users_empty_state.dart` — parámetros opcionales.
4. `users_screen.dart` — reescritura a `StatefulWidget`.
5. ARB ×3 → `flutter gen-l10n`.
6. Tests: `users_screen_test.dart` (reescritura) + 2 nuevos.
7. `Design/quesivo-design-system.yaml` — spec + 1.8.0 + changelog.
8. `dart format` → `flutter analyze` (0 issues) → `flutter test` (verde).

## Verificación visual esperada

- Stats del hero: "54 miembros" (no cambia con filtros).
- Body: buscador + fila de chips ("Todos" seleccionado por defecto) + lista con **15 cards** visibles inicialmente.
- Scroll hasta el final → spinner breve → 15 cards más (hasta agotar las 54).
- Escribir "ana" → lista se acota a las Ana/e incluidas en nombre o correo.
- Tocar "Productor" → solo esas filas, chip navy sólido.
- Buscar algo inexistente → estado "Sin resultados" con lupa tachada.
