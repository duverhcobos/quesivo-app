# Propuesta: Drawer a pantalla completa con módulos por categoría

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77.
Revisor: APROBADO sin hallazgos. yaml en 1.1.3.

(Aprobada por el usuario vía mockup de referencia: menú a pantalla completa
con logo, identidad, funcionalidades por categoría, botón ✕ y logout.)

## Diseño

```
┌──────────────────────────────────┐
│  [imagotipo QUESIVO]         ⊗ ✕ │  ← logo izq + botón cerrar der
│                       ◯◯ huecos  │     (círculo amarillo arriba-der)
│  ◯ avatar   Juan Pérez           │
│  (amarillo) Quesera Los Alpes    │
│             Administrador        │
│                                  │
│  ┌────────────────────────────┐  │
│  │ ⌂  Inicio                > │  │  ← tile resaltado, navega a /home
│  └────────────────────────────┘  │
│                                  │
│  OPERACIONES                     │  ← label categoría 12px secondary
│  💧 Recepción de leche         > │
│  🏭 Producción                 > │
│  📦 Inventario                 > │
│  🛒 Compras                    > │
│  📋 Pedidos                    > │
│  💲 Ventas                     > │
│                                  │
│  DIRECTORIO                      │
│  👥 Productores                > │
│  🚚 Recolectores y rutas       > │
│  🏪 Proveedores                > │
│  🧑 Clientes                   > │
│  🍳 Utensilios y equipos       > │
│                                  │
│  FINANZAS                        │
│  🧾 Liquidaciones              > │
│  💵 Adelantos                  > │
│  💳 Pagos a productores        > │
│  💸 Gastos                     > │
│                                  │
│  CONFIGURACIÓN                   │
│  🏢 Datos de la organización   > │
│  👥 Usuarios                   > │
│                                  │
│  ⎋  Cerrar sesión               │  ← rojo, sin chevron
│                            navy ◯│  ← arco navy abajo-der
└──────────────────────────────────┘
```

- **Pantalla completa**: `Drawer(width: double.infinity)` como `endDrawer` —
  conserva el desliz desde la derecha, el scrim y el gesto; visualmente es
  una página, no un panel angosto.
- **Decoración de marca**: círculo amarillo con huecos arriba-derecha
  (mismo motif del backdrop, parcialmente fuera del canvas — replicar la
  técnica de `QuesivoBackdrop` con `Stack`+`Positioned`+`ClipOval`) y arco
  navy abajo-derecha. Sutiles, detrás del contenido.
- **Header**: `SafeArea` + Row — imagotipo (alto ~28px) izquierda + botón
  ✕ derecha (círculo blanco con borde `quesivoBorder`, `Icons.close` navy)
  → `Navigator.pop`.
- **Identidad**: Row — avatar 56px amarillo `Icons.person` navy 28 + Column:
  nombre 18px w700 navy, **nombre de la quesera** 14px secondary
  (placeholder `orgName` hasta que el backend la exponga), **rol** 13px
  secondary (`l10n.adminRole` "Administrador" — fijo en el MVP, único rol).
- **Inicio**: tile resaltado (`quesivoSurface` radius 14) — `onTap` real:
  `Navigator.pop` + `context.go(AuthGuard.homeRoute)`.
- **Tiles de módulo**: Row[ícono navy outlined 22, gap 14, label 15px w500
  navy, `chevron_right` placeholder 20]; `onTap: null` → `Opacity(0.45)` sin
  chevron (criterio ya usado).
- **Labels de categoría**: 12px w600 `quesivoTextSecondary` + letterspacing,
  padding top 22/bottom 8.
- **Cerrar sesión**: al final del scroll — `logout` + texto `quesivoError`,
  sin chevron; pop + `AuthCubit.logout()` (cubit capturado antes del pop).
- Sin versión al pie (la referencia no la muestra; queda el arco navy).

## Categorías (todos los módulos del MVP)

- **Operaciones**: recepción, producción, inventario (moduleSupplies),
  compras, pedidos, ventas
- **Directorio**: productores, recolectores/rutas, proveedores, clientes,
  utensilios
- **Finanzas**: liquidaciones, adelantos, pagos, gastos
- **Configuración**: datos org, usuarios

## Archivos

| Archivo | Acción |
|---------|--------|
| `widgets/quesivo_drawer.dart` | **Reescribir** — full-screen + decoraciones + categorías |
| `app_*.arb` ×3 | `menuSectionOperations/Directorio/Finances/Settings` + `adminRole` ("Administrador"/"Administrator"/"Administrador") — el resto reusa claves `module*`/`navHome`/`logoutTooltip`/`orgDataItem`/`orgUsersItem` existentes; `appVersion` queda huérfana → eliminar |
| `quesivo-design-system.yaml` | `shell.header.menu.drawer` → full-screen + spec + changelog |

## Notas

- `context.go(AuthGuard.homeRoute)` desde el drawer funciona: `/home` es el
  branch 0 del shell — go_router resuelve el branch correcto.
- Todos los módulos `onTap: null` excepto Inicio — se activan cuando cada
  feature aterrice (cada tile documenta a qué feature pertenece).
- Verificación: `analyze` 0, `test` 77, visual.
