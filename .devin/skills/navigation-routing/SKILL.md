---
name: navigation-routing
description: Convenciones de go_router en Quesivo — rutas completas en AuthGuard, segmentos relativos en GoRoute hijos, push vs go, fuente de verdad de la ruta activa en el shell
allowed-tools:
  - read
  - grep
  - glob
triggers:
  - user
  - model
---

Convenciones de navegación con `go_router` (`^17`) en **Quesivo**. Las rutas
viven en `lib/core/routes/`: `app_router.dart` (declaración),
`auth_guard.dart` (constantes públicas) y `custom_transitions.dart`
(page builders). Toda pantalla nueva pasa por ahí — nunca `Navigator.push`
con `MaterialPageRoute` suelto.

## Reglas duras

- **Rutas completas solo en `AuthGuard`** (`AuthGuard.homeRoute = '/home'`,
  `productionRoute = '/operaciones/produccion'`, etc.). La UI navega siempre
  con esas constantes — ningún string de ruta escrito a mano.
- **`GoRoute` hijos usan segmentos RELATIVOS**, no la constante completa:
  ```dart
  // dentro de la branch /operaciones:
  GoRoute(path: 'produccion', ...)          // ✓ → /operaciones/produccion
  GoRoute(path: AuthGuard.productionRoute)  // ✗ → /operaciones/operaciones/produccion
  ```
  go_router concatena padre + hijo por segmentos; un path absoluto duplica
  el prefijo (bug real, propuesta §27).
- **`go` vs `push`**: `go` para moverse entre raíces/tabs o reemplazar el
  flujo (post-auth, logout → /welcome); `push` para entrar a una pantalla
  que debe poder volver atrás (detalle desde un listado, sub-pantalla).
- **`push` no cambia de branch en el `StatefulShellRoute`** (bug real,
  §35): `push` apila la pantalla sobre el branch actual sin mover
  `navigationShell.currentIndex` → el tab del nav bar no se marca aunque
  la ruta pertenezca a otra branch. Toda navegación del drawer/menú entre
  secciones usa `go` — además `go` a una ruta hija (`/home/organizacion`)
  construye el stack completo del match, así el back sigue funcionando.
  `push` solo para pantallas del MISMO branch que deben volver atrás.
- **Page builders siempre vía `CustomTransitions`** (fade/slideUp) — nada de
  `MaterialPage` crudo ni transiciones custom sueltas.
- **Capturar el router/cubit ANTES de cerrar el drawer**: cerrado el drawer,
  su contexto queda desactivado para lookups. Patrón:
  ```dart
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  router.push(route);
  ```

## Ruta activa dentro del shell (fuente de verdad)

Para saber qué ruta está visible desde un widget persistente del shell
(drawer, header), la fuente es **`GoRouter.of(context).routerDelegate`**
como `Listenable` + `GoRouter.of(context).state.matchedLocation` — el
`GoRouterState` de la configuración ya resuelta:

```dart
final routerDelegate = GoRouter.of(context).routerDelegate;
ListenableBuilder(
  listenable: routerDelegate,
  builder: (context, _) {
    final loc = GoRouter.of(context).state.matchedLocation;
    ...
  },
);
```

**Fuentes descartadas (bugs verificados en device, propuesta §28):**
- `GoRouterState.of(context)` — el widget del shell no se reconstruye al
  hacer `push` dentro de un branch; la ruta queda congelada al montarse.
- `routeInformationProvider.value.uri.path` — se desincroniza tras cerrar
  el drawer (podía seguir reportando la ruta anterior).

Match de módulo activo: `loc == route || loc.startsWith('$route/')` — una
ruta hija futura (`/operaciones/produccion/nueva`) sigue marcando su fila.

## Estructura del shell

`StatefulShellRoute.indexedStack` con 4 branches (`/home`, `/operaciones`,
`/catalogos`, `/dinero`); `MainLayout` es el builder y recibe
`StatefulNavigationShell`. Las pantallas de módulo se declaran como rutas
hijas de su branch — NUNCA como rutas raíz, porque eso las sacaría del
shell (bug real: el módulo tapaba header + nav).

## Hot restart obligatorio

El `GoRouter` se construye una sola vez (`late final` en `AppRouter`) —
tras tocar `app_router.dart` un hot reload no alcanza: **restart completo**
(`R`) o relanzar para que la tabla de rutas se regenere.
