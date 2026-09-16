# Propuesta: Tabs = loop operativo diario (Recepción · Producción · Ventas)

**Estado: aplicada y verificada** — `flutter analyze` 0 issues,
`flutter test` 77/77, `dart format` limpio. yaml en 1.6.0.

Desviaciones/ajustes aplicados:
- `/operaciones/insumos` no existía: la ruta real es
  `/operaciones/inventario` (`suppliesRoute`) — quedó con su URL actual en
  la branch Recepción.
- `AuthGuard`: eliminadas `operationsRoute`/`catalogsRoute`/`moneyRoute`
  (dead code — las rutas de menú dejaron de existir).
- **Bug prevenido**: `ModulePlaceholderScreen` ahora es raíz de branch —
  su flecha back llamaba `context.pop()` sin nada debajo (GoException).
  Ahora solo se muestra si `context.canPop()`.

Decisión del usuario: los 4 tabs pasan de menús intermedios a los módulos
de uso diario — `Inicio · Recepción · Producción · Ventas`. Las pantallas
de menú por categoría (`operations/catalogs/money_menu_screen`) pierden su
razón de ser: el drawer ya navega directo a cada módulo.

## Cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/routes/app_router.dart` | Reestructura de branches + rutas |
| `features/shell/presentation/widgets/quesivo_nav_bar.dart` | Íconos/labels de los tabs nuevos |
| `features/shell/presentation/screens/{operations,catalogs,money}_menu_screen.dart` | **Eliminar** (sin referencias) |
| `features/shell/presentation/widgets/module_menu_tile.dart` | **Eliminar** (solo lo usaban esas pantallas) |
| `../Design/quesivo-design-system.yaml` | Spec + changelog 1.6.0 |

## Nueva estructura de branches

Cada tab = una branch cuyo **root es el módulo** (no un menú). Las rutas
de módulos sin tab se reparten en la branch más cercana por dominio —
así `/dinero/liquidaciones` ilumina el tab Ventas, `/catalogos/*` ilumina
Producción (produce a partir de catálogos), `/operaciones/{insumos,compras,
pedidos}` iluminan Recepción:

```
Branch 0 — Inicio    /home (+ hijos organizacion, usuarios)     [igual]
Branch 1 — Recepción /operaciones/recepcion                     [nueva raíz]
                     /operaciones/insumos, compras, pedidos
                     /catalogos/productores, recolectores,
                     proveedores, clientes, utensilios
Branch 2 — Producción /operaciones/produccion                   [nueva raíz]
Branch 3 — Ventas     /operaciones/ventas                       [nueva raíz]
                      /dinero/liquidaciones, adelantos,
                      pagos-productores, gastos
```

- Las rutas **no cambian de URL** — solo se reagrupan entre branches
  (GoRoute top-level dentro de cada branch, no hijas anidadas).
- El drawer no se toca: sus filas ya apuntan a rutas completas y
  `isDrawerModuleRouteActive` sigue marcando bien el ítem activo.
- `initialLocation` (re-tap) sigue llevando a la raíz de cada branch —
  ahora eso ES el módulo, comportamiento correcto.

## NavBar — íconos y labels

Mismos del drawer, en par outlined/filled:

```dart
(Icons.home_outlined,                        Icons.home,                        l10n.navHome),
(Icons.water_drop_outlined,                  Icons.water_drop,                  l10n.moduleReception),
(Icons.precision_manufacturing_outlined,     Icons.precision_manufacturing,     l10n.moduleProduction),
(Icons.point_of_sale_outlined,               Icons.point_of_sale,               l10n.moduleSales),
```

Labels existentes — cero trabajo de l10n (`navOperations`, `navCatalogs`,
`navMoney` quedan huérfanas en los ARB; se pueden retirar en una limpieza
posterior, no es bloqueante).

## Eliminaciones

- `operations_menu_screen.dart`, `catalogs_menu_screen.dart`,
  `money_menu_screen.dart` — sin referencias tras el cambio de branches.
- `module_menu_tile.dart` — único consumidor eran esas pantallas.
- `module_placeholder_screen.dart` se **queda** — ahora es la raíz de las
  branches de módulo.
- `tab_page_title.dart` se queda (lo usa `home_tab`).

## Verificación

`flutter analyze` + `flutter test` + `dart format`; grep para confirmar que
no quedan imports a los archivos eliminados ni a `navOperations`/`navCatalogs`/
`navMoney` en código. yaml → 1.6.0.
