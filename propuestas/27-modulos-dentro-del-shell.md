# Propuesta: Módulos como rutas hijas del shell (fix navegación)

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77.
Las 17 rutas quedaron verificadas como hijas de su branch. yaml en 1.1.5.

(Corrección pedida por el usuario: las páginas de módulo debían renderizarse
dentro del layout shell, no cubrirlo.)

## El bug de diseño

Las 17 rutas de módulo se declararon a nivel raíz del router → al hacer
`push` desde el drawer se montan **encima** del `StatefulShellRoute` y
tapan header + nav + tabs. El usuario espera que las pantallas hijas se
rendericen **dentro** del shell.

## Fix

Cada módulo pasa a ser **ruta hija de su branch de categoría** — se
renderiza dentro de `MainLayout`, el nav sigue visible con su chip en el
tab correcto, y `context.pop()` vuelve al menú del tab:

| Branch | Rutas hijas |
|---|---|
| `/operaciones` | `/operaciones/recepcion`, `/produccion`, `/inventario`, `/compras`, `/pedidos`, `/ventas` |
| `/catalogos` | `/catalogos/productores`, `/recolectores`, `/proveedores`, `/clientes`, `/utensilios` |
| `/dinero` | `/dinero/liquidaciones`, `/adelantos`, `/pagos-productores`, `/dinero/gastos` |
| `/home` | `/home/organizacion`, `/home/usuarios` — Configuración no tiene tab propio; vive bajo el branch de Inicio (documentado) |

- `app_router.dart`: las 17 `GoRoute` se mueven como `routes:` hijas de la
  `GoRoute` de su branch (mismo `pageBuilder`/fade).
- `auth_guard.dart`: las consts cambian a las rutas anidadas.
- `quesivo_drawer.dart`: sin cambios estructurales — las `route` apuntan a
  los nuevos paths (`AuthGuard.*Route`), el `push` desde el drawer resuelve
  el branch correcto y queda dentro del shell.
- `module_placeholder_screen.dart`: intacta — el back sigue con `pop()`.

## Archivos

| Archivo | Acción |
|---------|--------|
| `core/routes/app_router.dart` | 17 rutas de raíz → hijas de branch |
| `core/routes/auth_guard.dart` | consts a rutas anidadas |
| `quesivo-design-system.yaml` | corregir spec + changelog |

## Verificación

- `analyze` 0, `test` 77.
- Manual: drawer → tap módulo → placeholder DENTRO del shell (header navy
  + píldora visibles, chip del tab de la categoría activo) → back → menú
  del tab.
