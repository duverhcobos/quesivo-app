# Propuesta: Feature `shell` — separar la infraestructura de navegación de `home`

**Estado: aplicada y auditada** — `flutter analyze` 0 issues, `flutter test`
77/77, `dart format` limpio. Revisor: estructura y dependencias correctas
(20 archivos en shell/, 4 en home/, shell nunca importa de home). El único
hallazgo del revisor fue un falso positivo (buscó la versión 1.3.3 en
`pubspec.yaml`/`Frontend/` — el yaml de la propuesta es
`Design/quesivo-design-system.yaml`, sí quedó en 1.3.3). Desviación del
implementador: el import de `home_tab.dart` a `tab_page_title` requería 3
niveles (`../../../shell/...`), no 2 como decía esta propuesta — corregido.

Pedido directo del usuario: `main_layout`, el drawer y las piezas del shell
viven en `features/home/` pero no son de home — son infraestructura
compartida que envuelve las 4 ramas del `StatefulShellRoute`. Crear
`features/shell/` y mover todo lo que es del shell.

**Dirección de dependencia resultante (limpia):**
`app_router` → `shell` + `home` ; `home` → `shell` (usa widgets
compartidos) ; `shell` → `core`/`auth` — el shell nunca importa de un
feature concreto.

---

## Qué se mueve y qué se queda

### Se mueve a `lib/features/shell/presentation/`

| Archivo destino | Por qué es shell |
|-----------------|------------------|
| `widgets/main_layout.dart` | El `StatefulNavigationShell` builder — envuelve las 4 ramas |
| `widgets/shell_header.dart` | Header navy persistente del shell |
| `widgets/quesivo_nav_bar.dart` | Bottom nav de 4 tabs |
| `widgets/quesivo_drawer.dart` | Composición del menú a pantalla completa |
| `widgets/drawer/` (9 archivos) | Todas las piezas `drawer_*` del menú |
| `widgets/tab_page_title.dart` | Título de página compartido por las 4 raíces de rama |
| `widgets/module_menu_tile.dart` | Tile de módulo usado por las 3 pantallas de menú |
| `screens/operations_menu_screen.dart` | Raíz de la rama /operaciones |
| `screens/catalogs_menu_screen.dart` | Raíz de la rama /catalogos |
| `screens/money_menu_screen.dart` | Raíz de la rama /dinero |
| `screens/module_placeholder_screen.dart` | Placeholder compartido de los 17 módulos |

### Se queda en `lib/features/home/`

| Archivo | Por qué es home |
|---------|-----------------|
| `screens/home_tab.dart` | Raíz de la rama /home |
| `widgets/home_hero_card.dart` | Contenido propio de la pantalla home |
| `widgets/home_quick_actions.dart` | Ídem |
| `widgets/home_recent_activity.dart` | Ídem |

---

## Cambios de imports (los únicos)

1. **`lib/core/routes/app_router.dart`** — 5 imports pasan de
   `features/home/...` a `features/shell/...`:
   ```dart
   import '../../features/shell/presentation/screens/catalogs_menu_screen.dart';
   import '../../features/shell/presentation/screens/module_placeholder_screen.dart';
   import '../../features/shell/presentation/screens/money_menu_screen.dart';
   import '../../features/shell/presentation/screens/operations_menu_screen.dart';
   import '../../features/shell/presentation/widgets/main_layout.dart';
   ```
   (`home_tab.dart` queda en `features/home/`.)

2. **`lib/features/home/presentation/screens/home_tab.dart`** — usa
   `TabPageTitle` que se movió:
   ```dart
   import '../../shell/presentation/widgets/tab_page_title.dart';
   ```
   (reemplaza `import '../widgets/tab_page_title.dart';`)

3. **Nada más cambia**: como `features/shell/` tiene exactamente la misma
   profundidad que `features/home/`, **todos los imports relativos
   internos** de los archivos movidos (`../../../../core/...`,
   `../../../../../core/...` en drawer/, `../../../auth/...`,
   `import 'drawer/...'`, `import '../widgets/...'` entre las pantallas de
   menú y sus tiles) quedan idénticos.

---

## Pasos mecánicos

1. Crear `lib/features/shell/presentation/screens/` y
   `lib/features/shell/presentation/widgets/`.
2. `git`-independiente: mover los 4 widgets de shell + `tab_page_title` +
   `module_menu_tile` a `shell/presentation/widgets/`; mover la carpeta
   `drawer/` completa; mover las 4 screens a `shell/presentation/screens/`.
3. Actualizar los 5 imports de `app_router.dart` y el de `home_tab.dart`.
4. `flutter analyze` + `flutter test` + `dart format --set-exit-if-changed`.
5. yaml changelog (1.3.3): reorganización `home` → `shell`, sin cambios
   visuales.

## Qué NO se toca

- Nombres de clases/widgets (`MainLayout`, `QuesivoDrawer`, etc.) — solo
  cambian rutas.
- Comportamiento, estilos, rutas — refactor puramente estructural.
- `quesivo_backdrop.dart` ya vive en `core/widgets/` — queda donde está.
