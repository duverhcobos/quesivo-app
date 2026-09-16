# Propuesta: Shell persistente post-auth (4 tabs + menú de usuario)

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77. Revisor: APROBADO sin hallazgos. Correcciones del implementador documentadas: `StatefulNavigationShell` como tipo del param (el spec original decía `StatefulShellRoute` — no compila), `logoutTooltip` reusada para el menú (sin `logoutItem` duplicada), y limpieza extra de `homeWelcomeMessage` (huérfana tras eliminar `home_screen.dart`).

Implementa el layout persistente que envuelve todo lo autenticado: AppBar
(título contextual + nombre de organización + menú de usuario con logout) y
bottom navigation de 4 tabs — **Inicio · Operaciones · Catálogos · Dinero** —
con `StatefulShellRoute.indexedStack` (cada tab conserva su propio stack y
scroll). Config va en el menú de usuario del AppBar, no en la barra. Sin FAB
global — el "+" vive dentro de cada módulo cuando exista.

Los módulos todavía no existen: los tabs Operaciones/Catálogos/Dinero abren un
**menú de módulos** (tarjetas con ícono + nombre, deshabilitadas hasta que el
módulo aterrice) e Inicio queda como panel placeholder con el logout. Las rutas
de módulos se agregan como rutas hijas del branch cuando cada feature se
implemente.

## Decisiones (ya tomadas con el usuario)

- 4 tabs (sin Config abajo) + menú de usuario en AppBar con Datos de la
  organización / Usuarios / Cerrar sesión.
- Sin drawer, sin FAB global.
- Shell solo en autenticado — auth flow y onboarding quedan full-screen fuera
  del shell (rutas de nivel raíz como hoy).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/home/presentation/widgets/main_layout.dart` | **Nuevo** — Scaffold + AppBar (título, org, menú usuario) + NavigationBar(4) + `navigationShell` |
| `lib/features/home/presentation/screens/home_tab.dart` | **Nuevo** — Inicio placeholder (saludo org + logout implícito vía menú) |
| `lib/features/home/presentation/screens/operations_menu_screen.dart` | **Nuevo** — menú de módulos de Operaciones |
| `lib/features/home/presentation/screens/catalogs_menu_screen.dart` | **Nuevo** — menú de módulos de Catálogos |
| `lib/features/home/presentation/screens/money_menu_screen.dart` | **Nuevo** — menú de módulos de Dinero |
| `lib/features/home/presentation/widgets/module_menu_tile.dart` | **Nuevo** — tarjeta de módulo (ícono + nombre + estado) |
| `lib/core/routes/auth_guard.dart` | Consts `operationsRoute`/`catalogsRoute`/`moneyRoute` (NO públicas — protegidas por defecto) |
| `lib/core/routes/app_router.dart` | `StatefulShellRoute.indexedStack` con 4 branches envolviendo `/home` + nuevas rutas |
| `lib/features/home/presentation/screens/home_screen.dart` | **Reemplazada** por `home_tab.dart` (el placeholder actual con logout se absorbe) |
| `lib/l10n/app_*.arb` ×3 | Labels de tabs, módulos y menú + `gen-l10n` |

---

## 1. Rutas y branches

`auth_guard.dart` — consts nuevas (sin agregar a `publicRoutes` — quedan
protegidas automáticamente):

```dart
static const String operationsRoute = '/operaciones';
static const String catalogsRoute = '/catalogos';
static const String moneyRoute = '/dinero';
```

`app_router.dart` — el `/home` actual pasa a ser branch 0 del shell:

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) =>
      MainLayout(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [
      GoRoute(path: AuthGuard.homeRoute, builder: (_, __) => const HomeTab()),
    ]),
    StatefulShellBranch(routes: [
      GoRoute(path: AuthGuard.operationsRoute,
              builder: (_, __) => const OperationsMenuScreen()),
    ]),
    StatefulShellBranch(routes: [
      GoRoute(path: AuthGuard.catalogsRoute,
              builder: (_, __) => const CatalogsMenuScreen()),
    ]),
    StatefulShellBranch(routes: [
      GoRoute(path: AuthGuard.moneyRoute,
              builder: (_, __) => const MoneyMenuScreen()),
    ]),
  ],
),
```

El `redirect` del guard sigue igual: `matchedLocation` de cualquier branch no
pública redirige a login sin sesión — el shell nunca se ve deslogueado.

Las futuras rutas de módulos (ej. `/operaciones/recepciones/nueva`) se cuelgan
como `routes:` hijas del branch correspondiente con `parentNavigatorKey` — al
pushearlas cubren el nav (formularios full-screen). Eso se documenta para las
features futuras, no se implementa ahora.

## 2. `main_layout.dart` (archivo nuevo)

```dart
/// Layout persistente post-auth: AppBar (título contextual + org + menú de
/// usuario) + NavigationBar de 4 tabs. Recibe el `navigationShell` de
/// go_router — no conoce rutas concretas (SRP).
class MainLayout extends StatelessWidget {
  const MainLayout({super.key, required this.navigationShell});
  final StatefulShellRoute navigationShell;
}
```

- **AppBar**: `title` según `navigationShell.currentIndex` (l10n navHome/
  navOperations/navCatalogs/navMoney), fondo `quesivoWhite`, texto navy;
  actions: `PopupMenuButton` con avatar/ícono `account_circle_outlined` navy
  → items `orgDataItem`, `orgUsersItem` (por ahora sin destino — comentario
  "pendiente de feature") y `logoutItem` → `context.read<AuthCubit>().logout()`
  (el guard redirige solo a `/welcome`).
- **NavigationBar**: 4 `NavigationDestination` con íconos
  `home_outlined`/`home`, `water_drop_outlined`/`water_drop`,
  `grid_view_outlined`/`grid_view`, `payments_outlined`/`payments` — label
  l10n; `selectedIndex: navigationShell.currentIndex`;
  `onDestinationSelected: (i) => navigationShell.goBranch(i,
  initialLocation: i == navigationShell.currentIndex)` (el patrón oficial:
  re-tap vuelve a la raíz del branch).
- Colores: fondo white, indicador `quesivoYellow.withValues(alpha: 0.15)`,
  ícono activo navy, inactivo `quesivoPlaceholder`.

## 3. `module_menu_tile.dart` (archivo nuevo)

```dart
/// Tarjeta de módulo del menú de un tab (§shell). `enabled: false` muestra el
/// estado "próximamente" (ícono y texto atenuados) hasta que el módulo exista.
class ModuleMenuTile extends StatelessWidget {
  const ModuleMenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap, // null = módulo no implementado todavía
  });
}
```

Container surface `quesivoSurface`, radius 16, Row[`Container` círculo
`quesivoIconSurface` + ícono navy 26, gap 16, `Expanded` Text 16/w600 navy,
`chevron_right` placeholder] — `onTap == null` → atenuado (`withValues` 0.45)
sin chevron.

## 4. Screens de tab (4 archivos nuevos)

Todas `SafeArea + ListView` con padding lateral `7.5%` y separación 12:

- **`home_tab.dart`** — `Column`: saludo "Hola, {org}" (placeholder del user
  del `AuthCubit` state — `context.select<AuthCubit, ...>`) + texto
  "Resumen del día próximamente" + tarjeta `quesivoSurface` vacía con el
  comentario F5. Mínima a propósito: el dashboard real es F5.
- **`operations_menu_screen.dart`** — tiles: Recepción de leche
  (`water_drop_outlined`), Producción (`precision_manufacturing_outlined`),
  Compras (`shopping_bag_outlined`), Pedidos (`assignment_outlined`),
  Ventas (`point_of_sale_outlined`) — todas `onTap: null` (pendientes).
- **`catalogs_menu_screen.dart`** — tiles: Productores (`groups_outlined`),
  Recolectores y rutas (`local_shipping_outlined`), Productos
  (`category_outlined`), Insumos e inventario (`inventory_2_outlined`),
  Proveedores (`storefront_outlined`), Clientes (`people_outline`),
  Utensilios y equipos (`kitchen_outlined`) — `onTap: null`.
- **`money_menu_screen.dart`** — tiles: Liquidaciones (`receipt_long_outlined`),
  Adelantos (`request_quote_outlined`), Pagos a productores
  (`payments_outlined`), Gastos (`money_off_outlined`) — `onTap: null`.

## 5. `home_screen.dart` (reemplazada)

El placeholder actual (`AppBar + logout + body "Home Protegido"`) se elimina —
su único contenido útil (logout) pasa al menú de usuario del `MainLayout`.
Borrar el archivo.

## 6. Diccionarios i18n

**`app_es.arb`:**
```json
  "navHome": "Inicio",
  "navOperations": "Operaciones",
  "navCatalogs": "Catálogos",
  "navMoney": "Dinero",
  "orgDataItem": "Datos de la organización",
  "orgUsersItem": "Usuarios",
  "logoutItem": "Cerrar sesión",
  "homeGreeting": "Hola, {name}",
  "homeSummarySoon": "Resumen del día próximamente",
  "moduleReception": "Recepción de leche",
  "moduleProduction": "Producción",
  "modulePurchases": "Compras",
  "moduleOrders": "Pedidos",
  "moduleSales": "Ventas",
  "moduleProducers": "Productores",
  "moduleCollectors": "Recolectores y rutas",
  "moduleProducts": "Productos",
  "moduleSupplies": "Insumos e inventario",
  "moduleSuppliers": "Proveedores",
  "moduleClients": "Clientes",
  "moduleTools": "Utensilios y equipos",
  "moduleSettlements": "Liquidaciones",
  "moduleAdvances": "Adelantos",
  "moduleProducerPayments": "Pagos a productores",
  "moduleExpenses": "Gastos"
```
(`homeGreeting` con placeholder `{name}` → `@homeGreeting` con `placeholders`.)

**`app_en.arb`:** Inicio→Home, Operaciones→Operations, Catálogos→Catalogs,
Dinero→Money, y los módulos en inglés equivalentes; `homeGreeting`: "Hi, {name}",
`homeSummarySoon`: "Daily summary coming soon".

**`app_pt.arb`:** equivalentes en portugués ("Início", "Operações", "Catálogos",
"Dinheiro", "Olá, {name}", "Resumo do dia em breve", módulos traducidos).

`logoutTooltip` ya existe ("Cerrar sesión") — reutilizarla para el item del
menú si el texto es idéntico (`logoutItem` puede omitirse si se prefiere).
Eliminar `homeTitle` ("Home Protegido") — queda huérfana con el reemplazo.

Después **`flutter gen-l10n`**.

## 7. Tests

- Actualizar/eliminar el test que referencie `HomeScreen`/`homeTitle` si existe
  (buscar en `test/`).
- No hay cubits nuevos — `MainLayout` y menus son UI + navegación; si hay
  widget tests existentes del home placeholder, ajustarlos o borrarlos
  (reportar qué se tocó).

## 8. Verificación

- `flutter analyze` — 0 issues.
- `flutter test` — 77 existentes ± ajustes por el home placeholder.
- Manual: login → cae en `/home` dentro del shell; cambiar de tab conserva
  estado; menú usuario → logout → vuelve a `/welcome`.
