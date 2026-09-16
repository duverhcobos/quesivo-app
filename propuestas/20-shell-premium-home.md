# Propuesta: Shell premium con identidad + Home

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77. Revisor: APROBADO con 3 ajustes menores ya corregidos (token `quesivoShadow` para la sombra del nav, `navigationShell` eliminado de `ShellHeader` por no usarse, KPIs placeholder pasados a l10n con `kpiLitersValue`/`kpiReceptionsValue`/`kpiBalanceValue`). `homeGreeting` y `homeSummarySoon` eliminadas de los arb por huérfanas.

El shell actual funciona pero se ve como "app Material por default": 
`NavigationBar` estándar pegado al borde + `AppBar` estándar + home de texto
plano. Esta propuesta le da identidad Quesivo en dos frentes — la **barra de
navegación firma** (el elemento distintivo del shell) y el **hero del home**
(el primer instante post-login). Solo shell + home; los menús de los otros
tabs se pulen después.

## Dirección visual

### Elemento firma: barra flotante navy "pill"

```
┌──────────────────────────────┐
│                              │
│         página hija          │
│                              │
│   ╭──────────────────────╮   │
│   │ ⌂ │ 💧 │ ▦ │ 💰      │   │  ← navy, flotante, pill 34px
│   ╰──────────────────────╯   │
└──────────────────────────────┘
```

- Contenedor flotante: margen 16 lateral + 12 abajo, alto ~68, `radius: 34`,
  fondo `quesivoNavy`, sombra suave (`black12` blur 20, offset y 8) — flota
  sobre el contenido en vez de pegarse al borde.
- Item activo: **chip amarillo pill** que envuelve ícono+label (texto navy
  w700) — eco del botón primario de auth. Inactivos: ícono blanco 60% + label
  blanco 60%.
- Transición del chip con `AnimatedContainer` (250ms easeOut) — se desliza al
  tab nuevo; respeta `disableAnimations`.
- El `NavigationBar` de Material se reemplaza por `QuesivoNavBar` (widget
  propio sobre `navigationShell.goBranch`) — misma API de navegación, identidad
  propia.

### Header — marca, no AppBar genérico

```
┌──────────────────────────────┐
│  Inicio                  ◯   │
│  Lácteos El Roble        👤  │
└──────────────────────────────┘
```

- Sin `AppBar` de Material — header custom en `SafeArea`: título del tab
  (28px w800 navy) + **nombre de la organización** debajo (14px
  `quesivoTextSecondary` — contexto multi-tenant siempre visible).
- Derecha: avatar circular navy 40px con la inicial del usuario (blanco w700);
  tap → `PopupMenu` (misma lógica actual: org/usuarios/logout).
- División sutil: `Divider` 1px `quesivoBorder` bajo el header.

### Home — el primer instante

```
┌──────────────────────────────┐
│  Inicio                  ◯👤 │
│  Lácteos El Roble            │
│                              │
│  ╭────────────────────────╮  │
│  │ NAVY HERO CARD         │  │
│  │  "Hoy"        ◯ huecos │  │
│  │  0 L  recibidos        │  │
│  │  0    recepciones      │  │
│  │  $0   saldo pendiente  │  │
│  ╰────────────────────────╯  │
│                              │
│  Accesos rápidos             │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ │
│  │ 💧 │ │ 💰 │ │ 👥 │ │ 🧾 │ │  ← 4 shortcuts (placeholder)
│  └────┘ └────┘ └────┘ └────┘ │
│                              │
│  Actividad reciente          │
│  (empty state)               │
└──────────────────────────────┘
```

- **Hero card navy** (radius 28): label "Hoy" amarillo w600 + 3 KPIs en
  columnas — valor amarillo 28/w800 + label blanco 70% 13px. Huecos de queso
  **blancos al 6% de opacidad** en la esquina (mismo motif del backdrop,
  versión sutil sobre navy). Datos placeholder — el real llega con F5.
- **Accesos rápidos**: 4 tiles circulares `quesivoIconSurface` + ícono navy +
  label 13px — Nueva recepción, Nueva venta, Productores, Liquidaciones
  (deshabilitados hasta que existan los módulos).
- **Actividad reciente**: empty state — ícono `inbox_outlined` 48px
  placeholder + "Sin actividad todavía" + "Las operaciones del día aparecen
  acá" (13px secondary).

## Archivos

| Archivo | Acción |
|---------|--------|
| `widgets/quesivo_nav_bar.dart` (en `features/home/presentation/widgets/`) | **Nuevo** — barra flotante firma |
| `widgets/shell_header.dart` | **Nuevo** — header custom (título + org + avatar menú) |
| `widgets/home_hero_card.dart` | **Nuevo** — card navy con KPIs + huecos |
| `widgets/home_quick_actions.dart` | **Nuevo** — fila de 4 shortcuts |
| `widgets/home_recent_activity.dart` | **Nuevo** — empty state |
| `widgets/main_layout.dart` | Reemplazar AppBar+NavigationBar por header custom + `QuesivoNavBar` (el nav va flotante sobre el body — `bottomNavigationBar` lo acepta con `extendBody: true` o `Padding`) |
| `screens/home_tab.dart` | Componer hero + quick actions + actividad |
| `app_*.arb` ×3 | `navToday` "Hoy", KPIs labels, `quickActions`, `recentActivity`, `noActivity`, `noActivityHint`, labels de los 4 shortcuts, `orgName` fallback |
| `quesivo-design-system.yaml` | Documentar `shell` (nav firma + header) + `home` (hero) — changelog |

## Notas

- `MediaQuery.disableAnimations` respeta el slide del chip.
- El avatar usa la inicial del user del `AuthCubit` (mismo `context.select`
  que el saludo del home).
- Tipografía: el yaml pide Poppins pero no hay fuente bundleada ni
  `google_fonts` en pubspec — queda para una propuesta aparte (requiere
  descargar los .ttf y declararlos en pubspec/assets).
- Verificación: `analyze` 0, `test` 77, manual visual.
