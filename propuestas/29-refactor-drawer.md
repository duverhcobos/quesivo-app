# Propuesta: Refactor del QuesivoDrawer — partir en widgets extraídos

**Estado: aplicada y auditada** — `flutter analyze` 0 issues, `flutter test`
77/77, `dart format` sin cambios. Revisor: sin hallazgos, refactor mecánico
limpio (handlers de navegación, `selected`, estilos e imports verificados
línea a línea). `quesivo_drawer.dart`: 722 → 167 líneas. yaml en 1.2.0.

**Ampliación posterior (pedido del usuario):** las piezas específicas del
diseño se empaquetan en subcarpeta — los 7 archivos `drawer_*` viven en
`widgets/drawer/` y `quesivo_drawer.dart` los importa como
`drawer/drawer_*.dart`. La regla quedó documentada en la skill
`file-size-refactoring`.

Pedido directo del usuario: el archivo quedó muy grande (~690 líneas, 7
widgets mezclados) y cuesta leerlo. Refactor **puramente mecánico**: mover
cada widget privado a su propio archivo en el mismo `widgets/`, sin tocar
comportamiento, estilos ni lógica. Sigue la nueva skill
`file-size-refactoring`.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `widgets/quesivo_drawer.dart` | Queda solo `QuesivoDrawer` (composición) |
| `widgets/drawer_brand_decoration.dart` | Nuevo — `_BrandDecoration` + `_CheeseHole` |
| `widgets/drawer_close_button.dart` | Nuevo — `_CloseButton` |
| `widgets/drawer_identity.dart` | Nuevo — bloque identidad extraído del build |
| `widgets/drawer_home_tile.dart` | Nuevo — `_HomeTile` |
| `widgets/drawer_section_label.dart` | Nuevo — `_SectionLabel` |
| `widgets/drawer_menu_item_row.dart` | Nuevo — `_MenuItemRow` + `_isModuleActive` |
| `widgets/drawer_menu_list.dart` | Nuevo — la ListView de ítems completa |
| `../Design/quesivo-design-system.yaml` | Changelog 1.2.0 (reorganización, sin cambios visuales) |

**Regla de renombre:** al pasar a archivo propio la clase deja de ser
privada y se prefija `Drawer` (`_MenuItemRow` → `DrawerMenuItemRow`), el
helper top-level se vuelve público (`_isModuleActive` →
`isDrawerModuleRouteActive`). Los doc comments se mueven con su widget.

---

## 1. drawer_brand_decoration.dart (nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer_brand_decoration.dart`

Mover textual las clases `_BrandDecoration` y `_CheeseHole` (fin del
archivo actual), renombradas a `DrawerBrandDecoration` y `_CheeseHole`
(privada, solo la usa la decoración). Imports: `material.dart` +
`app_colors.dart`. El doc comment de la clase se conserva.

## 2. drawer_close_button.dart (nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer_close_button.dart`

Mover `_CloseButton` → `DrawerCloseButton`. Imports: `material.dart` +
`app_colors.dart`.

## 3. drawer_identity.dart (nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer_identity.dart`

Extraer el bloque `// Identidad: avatar + nombre / quesera / rol.` del
`_buildContent` (el `Padding` con el `Row` avatar 56 + Column de 3 `Text`)
a un widget `DrawerIdentity` con parámetros `displayName` (String) — lee
`l10n` internamente para orgName/adminRole. Imports: `material.dart`,
`app_localizations.dart`, `app_colors.dart`.

```dart
/// Bloque de identidad del `QuesivoDrawer` — avatar amarillo 56px con
/// `Icons.person` navy + columna nombre / quesera / rol (los 3 con
/// ellipsis). `displayName` ya viene resuelto por el drawer (nombre real
/// o fallback localizado).
class DrawerIdentity extends StatelessWidget {
  const DrawerIdentity({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row( /* ... mismo contenido actual ... */ ),
    );
  }
}
```

## 4. drawer_home_tile.dart (nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer_home_tile.dart`

Mover `_HomeTile` → `DrawerHomeTile` (campos `label`, `onTap`, `selected`).
Imports: `material.dart` + `app_colors.dart`.

## 5. drawer_section_label.dart (nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer_section_label.dart`

Mover `_SectionLabel` → `DrawerSectionLabel`. Imports: `material.dart` +
`app_colors.dart`.

## 6. drawer_menu_item_row.dart (nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer_menu_item_row.dart`

Mover `_MenuItemRow` → `DrawerMenuItemRow` y el helper `_isModuleActive` →
`isDrawerModuleRouteActive` (top-level, mismo archivo — solo lo usa el
menú). Imports: `material.dart`, `go_router.dart`, `app_colors.dart`.

## 7. drawer_menu_list.dart (nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer_menu_list.dart`

Extraer el `Expanded` + `ListView` completo (home tile + 4 `_SectionLabel`
+ 17 `_MenuItemRow` + logout) a `DrawerMenuList` con parámetro
`currentLocation` (String). Lee `l10n` internamente; mantiene exactamente
los mismos `route:`/`selected:`/`onTap` (incluido el patrón
`GoRouter.of(context)` + `Navigator.of(context).pop()` de Inicio y logout,
y `context.read<AuthCubit>()` del logout). Imports: `material.dart`,
`flutter_bloc.dart`, `go_router.dart`, `app_localizations.dart`,
`auth_guard.dart`, `app_colors.dart`, `auth_cubit.dart`, `auth_state.dart`?
(no — auth_state no hace falta acá), + los 4 archivos de widgets extraídos.

```dart
/// Lista de ítems del `QuesivoDrawer` — Inicio, los 17 módulos agrupados
/// en 4 categorías y Cerrar sesión al final del scroll. Recibe la ruta
/// activa para marcar el ítem seleccionado (pastilla surface + ícono
/// amarillo, propuesta §28).
class DrawerMenuList extends StatelessWidget {
  const DrawerMenuList({required this.currentLocation});

  final String currentLocation;
  // ... Expanded + ListView idénticos a los actuales, usando los nombres
  // nuevos (DrawerHomeTile, DrawerSectionLabel, DrawerMenuItemRow,
  // isDrawerModuleRouteActive).
}
```

## 8. quesivo_drawer.dart (modificado)

**Ruta:** `lib/features/home/presentation/widgets/quesivo_drawer.dart`

Queda como **composición pura** (~170 líneas):

- `QuesivoDrawer.build`: `select` de `userName`, `displayName`, y el
  `Drawer` → `LayoutBuilder` → `ListenableBuilder` sobre
  `GoRouter.of(context).routerDelegate` (fuente de verdad de la ruta
  activa — NO mover esta lectura a un hijo, el `ListenableBuilder` debe
  envolver todo el contenido para repintarlo).
- `_buildContent(context, {width, displayName, currentLocation})`: el
  `Stack` con 2 `Positioned(DrawerBrandDecoration)` + `SafeArea` →
  `Column[header logo+DrawerCloseButton, DrawerIdentity, DrawerMenuList]`.
- Imports solo los que esa composición usa + los archivos `drawer_*`.

## 9. quesivo-design-system.yaml

- `version` 1.1.9 → `1.2.0`.
- Changelog 1.2.0: reorganización del drawer en archivos `drawer_*` por la
  skill `file-size-refactoring` (propuesta 29) — misma UI, solo estructura.

---

## Orden de aplicación

1. Crear los 7 archivos `drawer_*` nuevos (código movido + renombres).
2. Reescribir `quesivo_drawer.dart` como composición.
3. `flutter analyze` + `flutter test` + `dart format --set-exit-if-changed`.
4. yaml (spec/changelog).
