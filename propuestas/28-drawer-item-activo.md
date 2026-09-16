# Propuesta: Ítem activo en el QuesivoDrawer

**Estado: aplicada, auditada y corregida (1.1.8)** — la primera versión
(1.1.7) no funcionaba en runtime: `currentLocation` se leía con
`GoRouterState.of(context)` una sola vez en el `build` de `QuesivoDrawer`,
pero ese widget cuelga del `Scaffold` del `MainLayout`, que **no se
reconstruye** al hacer `push` dentro de un branch (solo al cambiar de tab)
— la ruta quedaba congelada y ningún ítem se marcaba al navegar.

Fix: se escucha `GoRouter.of(context).routeInformationProvider` (el
`ChangeNotifier` interno de go_router, actualizado en cada navegación
incluida la anidada) con `ListenableBuilder`; `currentLocation` se recalcula
en cada notificación desde `routeInformationProvider.value.uri.path`.

`flutter analyze` 0 issues, `flutter test` 77/77, `dart format` sin cambios
en `quesivo_drawer.dart`. yaml en 1.1.8.

**Fix #2 (1.1.9):** 1.1.8 tampoco resolvía el bug — confirmado con logs en
un dispositivo real: `routeInformationProvider.value` se desincroniza tras
cerrar el drawer (volvía a reportar `/home` aunque la navegación real
seguía en `/operaciones/recepcion`). La fuente correcta y siempre
consistente es `GoRouter.of(context).state.matchedLocation` (el
`GoRouterState` de la configuración ya resuelta), escuchando
`GoRouter.of(context).routerDelegate` como `Listenable` (notifica en
`_setCurrentConfiguration`, tras cada navegación real). Reverificado
`flutter analyze` 0 issues, `flutter test` 77/77. yaml en 1.1.9.

Cuando el usuario está parado en un módulo (ej. `/operaciones/produccion`), el
menú debe indicarlo: la fila correspondiente se pinta "seleccionada" —
fondo `quesivoSurface` radius 14, ícono `quesivoYellow` y label navy w600 —
igual que luce hoy el tile de `Inicio` (que deja de estar pintado siempre:
solo se resalta cuando la ruta activa es exactamente `/home`).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/home/presentation/widgets/quesivo_drawer.dart` | Leer la ruta activa, pasar `selected` a `_HomeTile`/`_MenuItemRow`, estilo seleccionado |
| `../Design/quesivo-design-system.yaml` | Documentar el estado seleccionado (bump 1.1.6 → 1.1.7) |

No requiere l10n ni rutas nuevas.

---

## 1. quesivo_drawer.dart (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/widgets/quesivo_drawer.dart`

### a) Leer la ruta activa en `build`

`GoRouterState.of(context).matchedLocation` devuelve la ruta matcheada
actual (ej. `/operaciones/produccion`); el drawer vive dentro del
`MainLayout` que construye el `StatefulShellRoute`, así que el estado está
disponible en ese contexto.

**Antes:**
```dart
    final trimmedName = userName?.trim() ?? '';
    final displayName = trimmedName.isNotEmpty ? trimmedName : l10n.orgName;
```

**Después:**
```dart
    final trimmedName = userName?.trim() ?? '';
    final displayName = trimmedName.isNotEmpty ? trimmedName : l10n.orgName;

    // Ruta activa — marca en el menú el módulo donde está parado el
    // usuario (ej. /operaciones/produccion → fila Producción seleccionada).
    final currentLocation = GoRouterState.of(context).matchedLocation;
```

### b) Pasar `selected` a `_HomeTile`

`Inicio` solo se resalta en `/home` exacto — los módulos de Configuración
(`/home/organizacion`, `/home/usuarios`) viven bajo ese branch pero tienen
su propia fila, así que ahí el seleccionado es el ítem de Configuración,
no `Inicio`.

**Antes:**
```dart
                          _HomeTile(
                            label: l10n.navHome,
                            onTap: () {
```

**Después:**
```dart
                          _HomeTile(
                            label: l10n.navHome,
                            selected: currentLocation == AuthGuard.homeRoute,
                            onTap: () {
```

### c) Pasar `selected` a cada `_MenuItemRow` con `route`

Match exacto o por prefijo con `/` (una ruta hija futura del módulo —ej.
`/operaciones/produccion/nueva`— sigue marcando `Producción`).

Ejemplo del patrón que se repite en las 17 filas:

**Antes:**
```dart
                          _MenuItemRow(
                            icon: Icons.precision_manufacturing_outlined,
                            label: l10n.moduleProduction,
                            route: AuthGuard.productionRoute,
                          ),
```

**Después:**
```dart
                          _MenuItemRow(
                            icon: Icons.precision_manufacturing_outlined,
                            label: l10n.moduleProduction,
                            route: AuthGuard.productionRoute,
                            selected: _isModuleActive(
                              currentLocation,
                              AuthGuard.productionRoute,
                            ),
                          ),
```

Con el helper (top-level, privado del archivo):

```dart
/// `true` si [currentLocation] es [route] o una ruta hija suya
/// (`route/…`) — marca el módulo activo en el drawer.
bool _isModuleActive(String currentLocation, String route) =>
    currentLocation == route || currentLocation.startsWith('$route/');
```

La fila de logout (la única con `onTap` propio y sin `route`) **no** recibe
`selected`.

### d) `selected` en `_HomeTile`

**Antes:**
```dart
class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.quesivoSurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.home_outlined,
                size: 22,
                color: AppColors.quesivoNavy,
              ),
```

**Después:**
```dart
class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? AppColors.quesivoSurface : AppColors.quesivoWhite,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.home_outlined,
                size: 22,
                color: selected
                    ? AppColors.quesivoYellow
                    : AppColors.quesivoNavy,
              ),
```

### e) `selected` en `_MenuItemRow` — fondo + tinte amarillo

La fila seleccionada envuelve el `Padding` en un `Container` con el fondo
`surface` (el `Material` transparente arriba mantiene el ripple) y tiñe el
ícono de amarillo; el label sube a w600 navy. `[color]` solo aplica cuando
no está seleccionada (logout nunca lo está).

**Antes:**
```dart
class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.icon,
    required this.label,
    this.route,
    this.onTap,
    this.color = AppColors.quesivoNavy,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
```

**Después:**
```dart
class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.icon,
    required this.label,
    this.route,
    this.onTap,
    this.color = AppColors.quesivoNavy,
    this.showChevron = true,
    this.selected = false,
  });

  final IconData icon;
  final String label;
```

**Antes (en `build`):**
```dart
    final row = InkWell(
      onTap: effectiveOnTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (showChevron && effectiveOnTap != null)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.quesivoPlaceholder,
              ),
          ],
        ),
      ),
    );
```

**Después:**
```dart
    final effectiveColor =
        selected ? AppColors.quesivoNavy : color;

    final row = Material(
      // El fondo `surface` solo aparece cuando la fila está seleccionada;
      // `transparent` deja que el InkWell pinte el ripple igual.
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(selected ? 14 : 8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.quesivoSurface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(selected ? 14 : 8),
        ),
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: BorderRadius.circular(selected ? 14 : 8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              // Padding horizontal solo en la pastilla seleccionada.
              horizontal: selected ? 16 : 0,
              vertical: selected ? 14 : 12,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.quesivoYellow : color,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: effectiveColor,
                    ),
                  ),
                ),
                if (showChevron && effectiveOnTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.quesivoPlaceholder,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
```

> Nota: `Material(color: Colors.transparent)` — el `Material` externo se
> necesita para el `InkWell`; el color visible lo pone el `Container`
> decorado. `Colors.transparent` es la constante estándar, no un color de
> marca quemado.

---

## 2. quesivo-design-system.yaml

**Ruta:** `Design/quesivo-design-system.yaml`

- `version`: `1.1.6` → `1.1.7`.
- En `shell.header.menu.drawer.menu_list.module_row` agregar el estado
  `selected`: fondo `quesivoSurface` radius 14 con padding 16/14, ícono
  `quesivoYellow`, label w600 navy; `selected = matchedLocation == route
  || matchedLocation.startsWith("$route/")` (match por prefijo cubre rutas
  hijas futuras del módulo).
- En el tile `Inicio`: el fondo `surface` deja de ser permanente — solo
  aparece con `matchedLocation == /home` exacto.
- Entrada de changelog 1.1.7 describiendo el estado activo (propuesta 28).

---

## Orden de aplicación

1. `quesivo_drawer.dart` (único archivo de código).
2. `flutter analyze` + `flutter test` + `dart format --set-exit-if-changed`.
3. `quesivo-design-system.yaml` (spec).
