# Propuesta: Pantallas placeholder de módulos (drawer navegable)

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77.
Revisor: APROBADO (el hallazgo menor sobre el changelog no aplicaba — ya
documenta la pantalla y las rutas). yaml en 1.1.4.

(Aprobada por el usuario: pantallas vacías para ver cómo funciona al dar
clic en los ítems.)

## Qué se construye

Una pantalla placeholder genérica + rutas reales para los **17 módulos** del
drawer. Cada ítem deja de estar deshabilitado y navega a su placeholder
(full-screen, cubre el shell — los módulos son destinos, no tabs).

## Pantalla placeholder

`ModulePlaceholderScreen({required IconData icon, required String label})`
en `features/home/presentation/screens/`:

```
┌──────────────────────────────┐
│  ←                           │  ← back (context.pop), navy
│                              │
│           ◯                  │  ← círculo iconSurface 88px,
│         (ícono)              │     ícono navy 44
│      Recepción de leche      │  ← 22px w700 navy
│        Próximamente          │  ← 14px secondary
│                              │
│                        navy ◯│  ← decoración esquina (opcional,
└──────────────────────────────┘     mismo criterio del drawer)
```

- `Scaffold` blanco + `SafeArea`; el back usa `context.pop()` (los módulos
  entran por `push`, así siempre hay a dónde volver).
- Contenido centrado: círculo + ícono + label + `l10n.moduleComingSoon`.
- Fondo: `QuesivoBackdrop(topCircleFraction: 0.5, bottomCircleFraction: 0,
  animate: false)` — eco de marca sutil sin animación.

## Rutas

Root-level en `app_router.dart` (encima del shell → cubren nav/header);
consts en `AuthGuard` (NO públicas — protegidas por defecto):

```dart
static const String receptionsRoute = '/recepcion';
static const String productionRoute = '/produccion';
static const String suppliesRoute = '/inventario';
static const String purchasesRoute = '/compras';
static const String ordersRoute = '/pedidos';
static const String salesRoute = '/ventas';
static const String producersRoute = '/productores';
static const String collectorsRoute = '/recolectores';
static const String suppliersRoute = '/proveedores';
static const String clientsRoute = '/clientes';
static const String toolsRoute = '/utensilios';
static const String settlementsRoute = '/liquidaciones';
static const String advancesRoute = '/adelantos';
static const String producerPaymentsRoute = '/pagos-productores';
static const String expensesRoute = '/gastos';
static const String orgDataRoute = '/organizacion';
static const String orgUsersRoute = '/usuarios';
```

17 `GoRoute`s con `pageBuilder` → `CustomTransitions.fade` (misma transición
que el resto de la app) — o `builder` simple si el fade complica el pop;
decidir lo más simple consistente con el router actual.

## Drawer

`_MenuItemRow` gana un `route` (String?) — `route != null` → habilitado:
`Navigator.pop` + `context.push(route)` (GoRouter capturado antes del pop,
mismo patrón que Inicio/logout). El tile de Inicio sigue con `go`.

| Categoría | Ítems → rutas |
|---|---|
| Operaciones | recepción→`/recepcion`, producción→`/produccion`, inventario→`/inventario`, compras→`/compras`, pedidos→`/pedidos`, ventas→`/ventas` |
| Directorio | productores→`/productores`, recolectores→`/recolectores`, proveedores→`/proveedores`, clientes→`/clientes`, utensilios→`/utensilios` |
| Finanzas | liquidaciones→`/liquidaciones`, adelantos→`/adelantos`, pagos→`/pagos-productores`, gastos→`/gastos` |
| Configuración | org→`/organizacion`, usuarios→`/usuarios` |

## i18n

- `moduleComingSoon`: "Próximamente" / "Coming soon" / "Em breve" — ×3 arb +
  gen-l10n.

## Archivos

| Archivo | Acción |
|---------|--------|
| `features/home/presentation/screens/module_placeholder_screen.dart` | **Nuevo** |
| `core/routes/auth_guard.dart` | +17 consts de ruta |
| `core/routes/app_router.dart` | +17 GoRoute (root-level) |
| `widgets/quesivo_drawer.dart` | `route` en `_MenuItemRow` + navegación real |
| `app_*.arb` ×3 | `moduleComingSoon` |
| `quesivo-design-system.yaml` | nota: rutas placeholder de módulos + changelog |

## Notas

- Cuando cada feature real aterrice, su `GoRoute` reemplaza al placeholder
  con la misma ruta — el drawer no se vuelve a tocar.
- Verificación: `analyze` 0, `test` 77, manual (abrir drawer → tap módulo →
  placeholder → back → vuelve al tab anterior).
