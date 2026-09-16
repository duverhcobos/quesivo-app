# Propuesta: Header navy con avatar + nombre (sin título de tab)

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77. Revisor: APROBADO con 2 ajustes menores ya corregidos (`home_tab` alineada a `SafeArea`+padding 16 como las otras tabs; doc comment de `main_layout` actualizado). yaml en versión 1.0.8.

Rediseño del `ShellHeader` según la referencia del usuario: el header deja de
ser un bloque blanco con título de sección y pasa a ser una **banda navy de
identidad de usuario** — avatar circular + nombre, con el menú de cuenta a la
derecha. El título del tab baja al cuerpo de cada pantalla (heading propio),
que es donde el usuario mira el contenido.

## Diseño

```
┌──────────────────────────────────┐
│  NAVY (fondo #07275C, SafeArea)  │
│                                  │
│  ◯ avatar   Ana Pérez        ⋮   │
│  (inicial)  Lácteos El Roble     │
└──────────────────────────────────┘
        Divider 1px (o sombra 4px)
```

- **Fondo**: `quesivoNavy` a todo el ancho, `SafeArea(bottom: false)`, padding
  `16 vertical` + `7.5% lateral`. Cierre: `Divider` 1px `quesivoBorder` (o
  sombra muy sutil — mismo criterio visual del nav flotante).
- **Avatar** (izquierda): círculo 44px fondo `quesivoYellow` con la inicial
  del usuario en navy w700 18px — el acento amarillo conecta con el chip del
  nav y el botón primario. `border` blanco 20% 1.5px para separarlo del navy.
- **Nombre + org** (columna al lado del avatar, gap 12):
  - Nombre del usuario: blanco w600, 16px (placeholder = `user.name` del
    `AuthCubit` vía `context.select`, fallback `l10n.orgName`).
  - Organización: blanco 60%, 13px (mismo valor que el nombre por ahora —
    comentario "organización real llega con el backend").
- **Menú** (derecha): ícono `more_vert` blanco 80% → `PopupMenuButton` con la
  MISMA lógica actual (orgData/orgUsers disabled + logout →
  `context.read<AuthCubit>().logout()`); el avatar ya no es el trigger.
- **Sin título de tab en el header** — la identidad es usuario/org; el
  contexto de sección lo da el nav (chip amarillo) + el heading interno.

## Títulos dentro de cada tab

Cada una de las 4 pantallas del shell abre su `ListView` con su propio heading
(mismo lenguaje que `AuthHeading` pero sin descripción — o reusar un mini
widget):

```
Inicio  (28px w800 navy, gap 20 al primer bloque)
```

- `home_tab.dart`: "Inicio" antes del `HomeHeroCard`.
- `operations_menu_screen.dart`: "Operaciones".
- `catalogs_menu_screen.dart`: "Catálogos".
- `money_menu_screen.dart`: "Dinero".

Para no duplicar el `Text` 4 veces: mini-widget `TabPageTitle({required String
title})` en `features/home/presentation/widgets/` (28px w800 navy + ellipsis).

## Archivos

| Archivo | Acción |
|---------|--------|
| `widgets/shell_header.dart` | **Reescribir** — banda navy (avatar yellow + nombre/org + menú ⋮) |
| `widgets/tab_page_title.dart` | **Nuevo** — heading de sección dentro de cada tab |
| `widgets/main_layout.dart` | Sin cambios de estructura (`ShellHeader` ya no necesita `currentIndex` → simplificar la llamada) |
| `screens/home_tab.dart` + 3 menus | Agregar `TabPageTitle` al inicio del ListView |
| `quesivo-design-system.yaml` | Actualizar `shell.header` (banda navy) + `shell.pages_titles` + changelog |

## Notas

- El `Divider` bajo el header se mantiene; el contraste navy→blanco ya separa
  visualmente.
- `MediaQuery.disableAnimations`: sin animaciones nuevas — no aplica.
- El nav flotante y el hero no se tocan.
- Verificación: `analyze` 0, `test` 77, visual manual.
