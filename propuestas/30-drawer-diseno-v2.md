# Propuesta: Rediseño del QuesivoDrawer — tarjetas de categoría, identidad navy y micro-interacciones

**Estado: aplicada y auditada** — `flutter analyze` 0 issues, `flutter test`
77/77, `dart format` limpio. Revisor: sin bloqueantes; la recomendación de
leer `disableAnimations` vía `MediaQuery` en `didChangeDependencies` (en vez
de `platformDispatcher` en `initState`) quedó aplicada — respeta MediaQuery
sobreescritos en tests. Desviaciones del implementador documentadas:
`Padding` horizontal 20 preservado en `DrawerIdentity` (mantiene el lateral
del spec) e `InkWell` envolviendo al `AnimatedContainer` (hit-area completa
de la pastilla). yaml en 1.3.0.

El usuario aprobó mejorar el menú en 3 frentes: categorías como tarjetas,
identidad/header reforzada y micro-interacciones sutiles. Las filas de
módulo conservan su look actual (ícono suelto + label + chevron, pastilla
`surface` al estar seleccionada) — no se tocan sus contenidos.

**Elemento firma:** la tarjeta de identidad navy — es el único bloque de
color sólido del menú, dialoga con el `ShellHeader` navy del shell y hace
protagonista al usuario/quesera sin competir con las decoraciones de marca.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `widgets/drawer/drawer_category_card.dart` | **Nuevo** — tarjeta que agrupa label + filas de una categoría |
| `widgets/drawer/drawer_menu_list.dart` | Reestructura: `DrawerHomeTile` + 4 `DrawerCategoryCard` + logout; pasa a `StatefulWidget` para la entrada escalonada |
| `widgets/drawer/drawer_staggered_item.dart` | **Nuevo** — wrapper de animación fade+slide por índice |
| `widgets/drawer/drawer_identity.dart` | Rediseño: tarjeta navy con avatar, nombre, quesera y chip de rol amarillo |
| `widgets/drawer/drawer_menu_item_row.dart` | El fondo seleccionado pasa de `Container` a `AnimatedContainer` (transición suave) |
| `widgets/drawer/drawer_home_tile.dart` | Radius 14 → 16 para casar con las tarjetas |
| `widgets/drawer/drawer_section_label.dart` | Ajuste de padding (ahora vive dentro de la tarjeta) |
| `../Design/quesivo-design-system.yaml` | Spec del nuevo look + changelog 1.3.0 |

No requiere l10n nuevas (los labels ya existen) ni rutas.

---

## 1. drawer_category_card.dart (archivo nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer/drawer_category_card.dart`

Tarjeta blanca que agrupa visualmente una categoría del menú: borde
`quesivoBorder` 1px, radius 16, label de sección adentro arriba y las
filas debajo.

```dart
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'drawer_section_label.dart';

/// Tarjeta de categoría del `DrawerMenuList` — contenedor blanco con borde
/// `quesivoBorder` y radius 16 que agrupa el `DrawerSectionLabel` y las
/// filas de esa sección (Operaciones, Directorio, Finanzas, Configuración).
/// La pastilla `surface` del ítem seleccionado sigue leyéndose sobre el
/// blanco de la tarjeta.
class DrawerCategoryCard extends StatelessWidget {
  const DrawerCategoryCard({
    super.key,
    required this.title,
    required this.children,
  });

  /// Texto ya localizado de la sección (pasa al `DrawerSectionLabel`).
  final String title;

  /// Filas de la categoría — los `DrawerMenuItemRow` de sus módulos.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.quesivoWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.quesivoBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerSectionLabel(title),
          ...children,
        ],
      ),
    );
  }
}
```

## 2. drawer_section_label.dart (archivo existente — ajuste)

**Ruta:** `lib/features/home/presentation/widgets/drawer/drawer_section_label.dart`

El label ahora vive dentro de la tarjeta (que ya aporta padding superior),
así que baja su top de 22 a 8 y sube bottom de 8 a 10:

**Antes:**
```dart
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
```

**Después:**
```dart
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
```

## 3. drawer_staggered_item.dart (archivo nuevo)

**Ruta:** `lib/features/home/presentation/widgets/drawer/drawer_staggered_item.dart`

Wrapper de entrada escalonada: fade + slide-up sutil con un `Interval`
que depende del índice del ítem. Lo maneja el `AnimationController` del
`DrawerMenuList` (ahora `StatefulWidget`).

```dart
import 'package:flutter/material.dart';

/// Envoltorio de entrada escalonada del `DrawerMenuList` — cada ítem del
/// menú aparece con fade + slide-up de 12px en una ventana `Interval`
/// propia según su [index], así el menú "cae" en cascada al abrirse el
/// drawer. La animación completa del controller es ~600ms con un paso de
/// ~30ms entre ítems.
class DrawerStaggeredItem extends StatelessWidget {
  const DrawerStaggeredItem({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  /// Controller del `DrawerMenuList` (0 → 1 al abrirse el drawer).
  final Animation<double> animation;

  /// Posición del ítem en la lista — determina su `Interval` de entrada.
  final int index;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Ventana propia del ítem dentro del controller: arranca en
    // index*0.045 y dura 0.4 — los últimos ítems terminan junto al 1.0.
    final begin = (index * 0.045).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, (begin + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
```

## 4. drawer_menu_list.dart (reestructura)

**Ruta:** `lib/features/home/presentation/widgets/drawer/drawer_menu_list.dart`

### a) `StatelessWidget` → `StatefulWidget` con controller

**Antes:**
```dart
class DrawerMenuList extends StatelessWidget {
  const DrawerMenuList({super.key, required this.currentLocation});

  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        children: [
          DrawerHomeTile( ... ),
          DrawerSectionLabel(l10n.menuSectionOperations),
          DrawerMenuItemRow( ... Recepción ... ),
          ...
        ],
      ),
    );
  }
}
```

**Después (esqueleto — el contenido de las filas NO cambia):**
```dart
class DrawerMenuList extends StatefulWidget {
  const DrawerMenuList({super.key, required this.currentLocation});

  final String currentLocation;

  @override
  State<DrawerMenuList> createState() => _DrawerMenuListState();
}

class _DrawerMenuListState extends State<DrawerMenuList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Respeta la accesibilidad: con animaciones deshabilitadas el menú
    // aparece completo de una (skill frontend-design).
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    var index = 0;

    Widget stagger(Widget child) =>
        DrawerStaggeredItem(
          animation: _controller,
          index: index++,
          child: child,
        );

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        children: [
          stagger(DrawerHomeTile( ...igual que hoy... )),
          const SizedBox(height: 16),
          stagger(
            DrawerCategoryCard(
              title: l10n.menuSectionOperations,
              children: const [ /* los 6 DrawerMenuItemRow actuales de
                  Operaciones — selected: no puede ser const, ver nota */ ],
            ),
          ),
          const SizedBox(height: 16),
          // ... Directorio, Finanzas, Configuración igual ...
          stagger(DrawerCategoryCard( ... Configuración ... )),
          const SizedBox(height: 20),
          stagger( /* DrawerMenuItemRow de logout — igual que hoy */ ),
        ],
      ),
    );
  }
}
```

**Nota de implementación:** `selected:` depende de `currentLocation`, así
que las filas no son `const` — cada `DrawerCategoryCard` recibe sus rows
normales como hoy. La cuenta total de ítems animados: 1 (Inicio) + 4
(tarjetas) + 1 (logout) = **6 índices** — la cascada queda contenida y
rápida (~30ms de paso ya incluido en el `Interval`).

Los `DrawerSectionLabel` sueltos desaparecen del `ListView` — ahora van
dentro de cada `DrawerCategoryCard` como `title`.

## 5. drawer_identity.dart (rediseño)

**Ruta:** `lib/features/home/presentation/widgets/drawer/drawer_identity.dart`

La identidad deja de ser un `Row` suelto y pasa a ser la **tarjeta navy
firmada**: fondo `quesivoNavy` radius 16, avatar amarillo (mismo 56px),
nombre blanco 18 w700, quesera blanco 70% y rol como **chip amarillo**
(`quesivoYellow` bg + texto navy 12 w600, radius 8) — el rol es la única
"etiqueta" del menú y el chip la hace significativa, no decorativa.

```dart
/// Tarjeta de identidad del `QuesivoDrawer` — el único bloque navy sólido
/// del menú: avatar amarillo + nombre / quesera / chip de rol del usuario.
/// `displayName` ya viene resuelto por el drawer (nombre real o fallback
/// localizado).
class DrawerIdentity extends StatelessWidget {
  const DrawerIdentity({super.key, required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.quesivoNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.quesivoYellow,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person,
              size: 28,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quesivoWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.orgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.quesivoWhite.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.quesivoYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.adminRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## 6. drawer_menu_item_row.dart (transición del seleccionado)

**Ruta:** `lib/features/home/presentation/widgets/drawer/drawer_menu_item_row.dart`

El `Container` con la decoración `surface` pasa a `AnimatedContainer` para
que el ítem se "encienda" suavemente al navegar:

**Antes:**
```dart
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.quesivoSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(selected ? 14 : 8),
        ),
```

**Después:**
```dart
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppColors.quesivoSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(selected ? 14 : 8),
        ),
```

El `padding` interno del `Padding` (16/14 seleccionado vs 0/12 normal)
también pasa al `AnimatedContainer` para que la pastilla crezca completa:

```dart
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 0,
          vertical: selected ? 14 : 12,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.quesivoSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(selected ? 14 : 8),
        ),
        child: Row( ...mismo contenido, sin el Padding externo... ),
      ),
```

## 7. drawer_home_tile.dart (radius)

**Ruta:** `lib/features/home/presentation/widgets/drawer/drawer_home_tile.dart`

Radius 14 → 16 en `Material`/`borderRadius` para casar con las tarjetas.

## 8. quesivo-design-system.yaml

- `version` → `1.3.0`; spec del drawer actualizado (tarjetas de categoría,
  identidad navy con chip de rol, entrada escalonada, AnimatedContainer en
  la fila seleccionada, radius 16 unificado) + changelog.

---

## Orden de aplicación

1. `drawer_category_card.dart` + `drawer_staggered_item.dart` (nuevos).
2. `drawer_section_label.dart`, `drawer_home_tile.dart`,
   `drawer_menu_item_row.dart` (ajustes).
3. `drawer_identity.dart` (rediseño).
4. `drawer_menu_list.dart` (reestructura con tarjetas + stagger).
5. `flutter analyze` + `flutter test` + `dart format`.
6. yaml 1.3.0.
