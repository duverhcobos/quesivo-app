# Propuesta: Menú lateral derecho (endDrawer) con hamburguesa

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77.
Revisor: APROBADO sin hallazgos. yaml en 1.1.1.

(Aprobada por el usuario: menú lateral desde la derecha con hamburguesa;
secciones a criterio propio.)

## Qué va en el drawer

El drawer es el hogar de la **cuenta y la configuración** — lo que quedó
huérfano al retirar el ⋮ — no de navegación (eso ya lo cubren los 4 tabs):

```
┌────────────────────────────┐
│ NAVY (eco del header)      │
│  ◯  Ana Pérez              │
│     Lácteos El Roble       │
├────────────────────────────┤
│ Cuenta                     │  ← label de sección (secondary, caps suave)
│  🏢  Datos de la org.      │  (disabled — pendiente de feature)
│  👥  Usuarios              │  (disabled — pendiente de feature)
├────────────────────────────┤
│                            │
│  ⎋  Cerrar sesión          │  ← quesivoError (destructiva)
│                            │
│        Quesivo v0.1.0      │  ← versión, placeholder al pie
└────────────────────────────┘
```

- **Header interno navy**: mini avatar amarillo (36px, `Icons.person` navy) +
  nombre w600 blanco + org blanco 60% (mismo `context.select` del header).
  `SafeArea` + padding para que no quede pegado al status bar.
- **Sección "Cuenta"**: label 12px w600 `quesivoTextSecondary` letterspacing
  leve + 2 `ListTile` con íconos navy (`business_outlined`,
  `group_outlined`) — `enabled: false` hasta que existan las pantallas.
- **Cerrar sesión**: `ListTile` con `logout` + texto `quesivoError` →
  `Navigator.pop` + `context.read<AuthCubit>().logout()` (el guard redirige
  a `/welcome` — no navegar manual).
- **Pie**: versión de la app centrada, 12px `quesivoPlaceholder` — detalle
  premium, ya tenemos el valor en `pubspec` (hardcodear "0.1.0" no: leer de
  una const o dejar literal documentado; sin paquete nuevo — se escribe el
  literal y se mantiene al día, o se omite si molesta).

## Diseño

- `endDrawer` del `Scaffold` (desliza desde la derecha, como pidió el
  usuario) — ancho `Drawer` por defecto (~304px) o 80% del ancho.
- Trigger: `Icons.menu` (hamburguesa) blanco 80% a la derecha del
  `ShellHeader` → `Scaffold.of(context).openEndDrawer()` — sin Hero ni
  cosas raras: el drawer nativo de Material ya tiene su transición lateral,
  scrim y gesto de cierre.
- `SafeArea` dentro del drawer para el borde inferior.

## Archivos

| Archivo | Acción |
|---------|--------|
| `features/home/presentation/widgets/quesivo_drawer.dart` | **Nuevo** — `QuesivoDrawer` (header navy + secciones + logout + versión) |
| `widgets/shell_header.dart` | Agregar `IconButton` `Icons.menu` blanco 80% al final del Row → `openEndDrawer` |
| `widgets/main_layout.dart` | `Scaffold(endDrawer: const QuesivoDrawer(), ...)` |
| `app_*.arb` ×3 | `drawerAccountSection` ("Cuenta"), `appVersion` ("Quesivo v{version}") — `orgDataItem`/`orgUsersItem`/`logoutTooltip`/`orgName` se reusan |
| `quesivo-design-system.yaml` | `shell.header.menu` → `right_drawer` + spec + changelog |

## Notas

- `Scaffold.of(context)` dentro del `ShellHeader` resuelve el Scaffold del
  `MainLayout` (está debajo en el árbol — OK).
- Sin animaciones custom → `disableAnimations` no aplica.
- El `quesivoBarrier` creado en la propuesta anterior queda disponible para
  futuros diálogos (no se borra el token).
- Verificación: `analyze` 0, `test` 77, manual (⋮≡ abre, scrim cierra,
  logout → `/welcome`).
