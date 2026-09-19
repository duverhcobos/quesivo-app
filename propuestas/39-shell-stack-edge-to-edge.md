# Propuesta: Shell edge-to-edge — header, nav y pantalla hija en Stack

**Problema** (feedback visual del usuario sobre §38): el `MainLayout` arma el shell con un `Column` (ShellHeader → hija) + `bottomNavigationBar`. La hija **no puede pintar detrás** del chrome, entonces:

- Las esquinas inferiores r20 del `ShellHeader` dejan una muesca clara entre la banda navy y el hero navy del módulo — dos superficies del mismo color separadas por una grieta del fondo.
- Las esquinas superiores r20 de la `QuesivoNavBar` dejan ver el blanco del `Scaffold`, no el surface de la pantalla.

**Solución** (dirección del usuario): pasar el body a `Stack` — la hija pinta edge-to-edge, header y nav flotan encima. Las esquinas redondeadas del chrome dejan ver el fondo **de la propia pantalla** (hero navy → continuidad total con la banda; surface → notches coherentes bajo el nav).

Cada pantalla reserva su espacio con una extensión nueva `context.shellHeaderHeight` / `context.shellNavBarHeight` — única fuente de verdad de "cuánto ocupa el chrome". Una pantalla con hero navy usa el inset **dentro** del hero (pinta hasta y=0, contenido debajo de la banda); una pantalla clara lo usa como padding normal. Solo existen 3 widgets de pantalla en el shell — el cambio es acotado.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/shell/presentation/widgets/shell_insets.dart` | **nuevo** — extensión `ShellInsets` sobre `BuildContext` |
| `lib/features/shell/presentation/widgets/main_layout.dart` | `Column`+`bottomNavigationBar` → `Stack` con hija full-bleed |
| `lib/features/shell/presentation/widgets/shell_header.dart` | `static const contentHeight = 76` + altura fijada con `SizedBox` |
| `lib/features/shell/presentation/widgets/quesivo_nav_bar.dart` | `static const height = 74` reemplaza el literal |
| `lib/features/shell/presentation/screens/module_placeholder_screen.dart` | `SafeArea` → `Padding` con insets del shell |
| `lib/features/home/presentation/screens/home_tab.dart` | `SafeArea` → padding explícito en el `ListView` |
| `lib/features/users/presentation/screens/users_screen.dart` | hero navy pinta desde y=0 (inset dentro del hero); padding del listado al `ListView` |
| `Design/quesivo-design-system.yaml` | spec shell + versión 1.7.1 → **1.7.2** + changelog |

Sin cambios de i18n, DI ni rutas.

---

## 1. `shell_insets.dart` (archivo nuevo)

**Ruta:** `lib/features/shell/presentation/widgets/shell_insets.dart`

```dart
import 'package:flutter/material.dart';

import 'quesivo_nav_bar.dart';
import 'shell_header.dart';

/// Insets que reserva cada pantalla hija del shell (§39 — body en Stack
/// edge-to-edge). El `ShellHeader` y la `QuesivoNavBar` flotan sobre el
/// contenido: cada pantalla decide si su fondo llega al borde (hero navy
/// que se fusiona con la banda) o si su contenido empieza debajo. Estas
/// extensiones son la única fuente de verdad de "cuánto ocupa el chrome".
extension ShellInsets on BuildContext {
  /// Alto total del `ShellHeader`: inset del status bar + contenido navy.
  /// Como padding superior del contenido — o como aire dentro de un hero
  /// navy que pinta detrás de la banda.
  double get shellHeaderHeight =>
      MediaQuery.paddingOf(this).top + ShellHeader.contentHeight;

  /// Alto total de la `QuesivoNavBar`: lámina de 74 + inset inferior del
  /// sistema (barra de gestos). Como padding inferior de contenido
  /// scrolleable — el último ítem puede subir por encima del nav.
  double get shellNavBarHeight =>
      MediaQuery.paddingOf(this).bottom + QuesivoNavBar.height;
}
```

---

## 2. `main_layout.dart` (existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/main_layout.dart`

Doc de la clase — **antes:**

```dart
/// Layout persistente post-auth (propuestas §shell-premium +
/// §header-navy-avatar + §drawer-cuenta): `ShellHeader` navy de identidad
/// arriba + `QuesivoNavBar` flotante abajo + `QuesivoDrawer` como
/// endDrawer (cuenta/logout, se abre desde la hamburguesa del header).
```

**después** (mismo texto + nota §39):

```dart
/// Layout persistente post-auth (propuestas §shell-premium +
/// §header-navy-avatar + §drawer-cuenta): `ShellHeader` navy de identidad
/// arriba + `QuesivoNavBar` flotante abajo + `QuesivoDrawer` como
/// endDrawer (cuenta/logout, se abre desde la hamburguesa del header).
/// §39: el body es un `Stack` edge-to-edge — la hija pinta a pantalla
/// completa detrás del chrome y reserva sus insets con
/// `context.shellHeaderHeight` / `context.shellNavBarHeight`
/// (shell_insets.dart); así un hero navy puede fusionarse con la banda y
/// las esquinas redondeadas del chrome revelan el fondo de la propia
/// pantalla, no el del Scaffold.
```

`build` — **antes:**

```dart
    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      endDrawer: const QuesivoDrawer(),
      body: Column(
        children: [
          const ShellHeader(),
          // El header ya consumió el inset superior con su SafeArea; se lo
          // retiro a las tabs para que sus SafeArea internos no dupliquen
          // el espacio bajo la banda navy.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              // Slide direccional + fade al cambiar de tab: ...
              child: TweenAnimationBuilder<Offset>(
                ... // (sin cambios internos)
                child: navigationShell,
              ),
            ),
          ),
        ],
      ),
      // Transparente: la `QuesivoNavBar` ya trae su propio fondo navy,
      // margen y sombra — el Scaffold solo le reserva el slot inferior.
      bottomNavigationBar: QuesivoNavBar(navigationShell: navigationShell),
    );
```

**después:**

```dart
    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      endDrawer: const QuesivoDrawer(),
      // §39 — Stack edge-to-edge: la hija pinta a pantalla completa y
      // reserva sus insets con shell_insets; el header y el nav flotan
      // encima. Ya no se remueve el padding superior del MediaQuery: las
      // pantallas lo necesitan para calcular shellHeaderHeight.
      body: Stack(
        children: [
          // Slide direccional + fade al cambiar de tab — mismo tween que
          // antes, ahora deslizando el contenido bajo el chrome navy.
          Positioned.fill(
            child: TweenAnimationBuilder<Offset>(
              key: ValueKey(index),
              tween: Tween(
                begin: Offset(0.15 * direction, 0),
                end: Offset.zero,
              ),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, offset, child) => FractionalTranslation(
                translation: offset,
                child: Opacity(
                  opacity: 1 - (offset.dx.abs() / 0.15),
                  child: child,
                ),
              ),
              child: navigationShell,
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: ShellHeader()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: QuesivoNavBar(navigationShell: navigationShell),
          ),
        ],
      ),
    );
```

> Se eliminan: el `Column`, el `Expanded`, el `MediaQuery.removePadding` (las pantallas ahora necesitan el inset real del status bar) y el slot `bottomNavigationBar` (el nav pasa al Stack).

---

## 3. `shell_header.dart` (existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/shell_header.dart`

Agregar la constante tras el constructor:

```dart
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key});

  /// Alto del contenido navy (sin el inset del status bar): avatar 44 +
  /// padding vertical 16×2. Fijado con `SizedBox` en el build para que
  /// `context.shellHeaderHeight` (§39) sea exacto en todo dispositivo.
  static const double contentHeight = 76;
```

En el `build`, fijar la altura del contenido — **antes:**

```dart
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.075,
                  vertical: 16,
                ),
                child: Row(
```

**después:**

```dart
            SafeArea(
              bottom: false,
              // Altura fija = contentHeight — antes era implícita
              // (padding 16×2 + avatar 44); ahora es contrato: las
              // pantallas reservan exactamente este alto bajo la banda.
              child: SizedBox(
                height: contentHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.075,
                  ),
                  child: Row(
```

> Ajustar el cierre correspondiente (un `)` más al final del `Row`). Visualmente idéntico: el `Row` se centra verticalmente en los mismos 76px.

---

## 4. `quesivo_nav_bar.dart` (existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/quesivo_nav_bar.dart`

Agregar la constante tras el campo `navigationShell`:

```dart
  /// Shell de go_router: expone `currentIndex` y `goBranch` para los tabs.
  final StatefulNavigationShell navigationShell;

  /// Alto de la lámina de contenido — el total en pantalla es
  /// `height` + inset inferior del sistema (`SafeArea` interno). Las
  /// pantallas lo leen vía `context.shellNavBarHeight` (§39).
  static const double height = 74;
```

En el `build` — **antes:** `height: 74,` → **después:** `height: height,` (mismo valor, ahora es contrato).

---

## 5. `module_placeholder_screen.dart` (existente — actualización)

**Ruta:** `lib/features/shell/presentation/screens/module_placeholder_screen.dart`

- Import nuevo: `import '../widgets/shell_insets.dart';`
- El `SafeArea` que envuelve el `Column` del contenido — **antes:**

```dart
            SafeArea(
              child: Column(
```

**después:**

```dart
            // §39: el contenido reserva el chrome del shell — back debajo
            // de la banda, contenido centrado por encima del nav. Las
            // decoraciones del backdrop quedan fuera (pintan full-bleed).
            Padding(
              padding: EdgeInsets.only(
                top: context.shellHeaderHeight,
                bottom: context.shellNavBarHeight,
              ),
              child: Column(
```

> El `QuesivoBackdrop` y el arco navy NO se tocan — ahora pintan edge-to-edge detrás del chrome (el círculo amarillo superior asoma por las esquinas redondeadas de la banda — coherente con la firma de marca).

---

## 6. `home_tab.dart` (existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/home_tab.dart`

- Import nuevo: `import '../../../shell/presentation/widgets/shell_insets.dart';`
- **antes:**

```dart
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.075,
          vertical: 16,
        ),
        children: [
```

**después:**

```dart
    // §39: sin SafeArea — los insets del shell se reservan en el padding
    // del ListView (el contenido puede scrollear bajo el chrome navy).
    return ListView(
      padding: EdgeInsets.only(
        left: size.width * 0.075,
        right: size.width * 0.075,
        top: context.shellHeaderHeight + 16,
        bottom: context.shellNavBarHeight + 16,
      ),
      children: [
```

> Ajustar el cierre (un `)` menos). El `+16` conserva el aire que hoy deja `vertical: 16`.

---

## 7. `users_screen.dart` (existente — actualización)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

- Import nuevo: `import '../../../shell/presentation/widgets/shell_insets.dart';`
- Doc de la clase: agregar al final — `§39: el hero pinta edge-to-edge detrás del ShellHeader (mismo navy → una sola superficie continua); su contenido empieza bajo la banda con context.shellHeaderHeight.`

- **antes:**

```dart
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabecera navy del módulo (elemento firma §38) ──
            Container(
              decoration: const BoxDecoration(
                color: AppColors.quesivoNavy,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (context.canPop())
```

**después:**

```dart
      // §39: sin SafeArea — el hero navy pinta desde y=0 detrás del
      // ShellHeader (navy sobre navy = superficie continua); el primer
      // hijo reserva el alto del chrome dentro del propio hero.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabecera navy del módulo (elemento firma §38) ──
          Container(
            decoration: const BoxDecoration(
              color: AppColors.quesivoNavy,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: context.shellHeaderHeight),
                if (context.canPop())
```

> Ajustar niveles de cierre del `Column`/`Container`/`Expanded` al quitar el `SafeArea`.

- Listado — **antes:**

```dart
            // ── Listado sobre surface ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _sampleMembers.isEmpty
                    ? const UsersEmptyState()
                    : ListView.separated(
                        itemCount: _sampleMembers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            OrgMemberCard(member: _sampleMembers[index]),
                      ),
              ),
            ),
```

**después:**

```dart
          // ── Listado sobre surface ──
          Expanded(
            child: _sampleMembers.isEmpty
                ? const UsersEmptyState()
                // Padding en el ListView (no en un wrapper): las cards
                // pueden scrollear bajo el nav navy y el último ítem sube
                // por encima — inset = shellNavBarHeight (§39).
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      20,
                      24,
                      context.shellNavBarHeight,
                    ),
                    itemCount: _sampleMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        OrgMemberCard(member: _sampleMembers[index]),
                  ),
          ),
```

---

## 8. `Design/quesivo-design-system.yaml`

- `version`: `1.7.1` → `1.7.2`
- `shell.signature_nav_bar.container.note`: actualizar — la lámina ya no vive en el slot `bottomNavigationBar` sino como `Positioned(bottom)` del Stack del body (§39); las esquinas superiores revelan el fondo de la pantalla hija.
- `shell.header`: agregar `content_height: "76px fijos (SizedBox — avatar 44 + 16×2); las pantallas lo reservan vía context.shellHeaderHeight"`.
- Agregar bajo `shell` una nota de layout: `stack_layout` — body `Stack` edge-to-edge desde 1.7.2: hija `Positioned.fill` + header `Positioned(top)` + nav `Positioned(bottom)`; cada pantalla reserva insets con la extensión `ShellInsets` (§39).
- `changelog` — nueva entrada:

```yaml
  - version: "1.7.2"
    page: "shell"
    status: "completed"
    changes:
      - "Shell edge-to-edge (propuesta §39, feedback visual del usuario): el body del MainLayout pasa de Column+bottomNavigationBar a Stack — la pantalla hija pinta a pantalla completa detrás del header y del nav. Motivo: al darle radius al header, las esquinas revelaban el fondo equivocado (muesca clara entre la banda navy y el hero navy del módulo; blanco del Scaffold bajo las esquinas del nav) porque la hija no podía cubrir ese espacio."
      - "Nueva extensión ShellInsets (shell_insets.dart): context.shellHeaderHeight = statusBar + 76 (contentHeight fijado con SizedBox en ShellHeader) y context.shellNavBarHeight = 74 + inset de gestos — única fuente de verdad del alto del chrome para las pantallas hijas."
      - "UsersScreen: el hero navy pinta desde y=0 detrás del ShellHeader → las dos superficies navy se fusionan en una sola; sus esquinas inferiores r28 revelan el surface del listado. HomeTab y ModulePlaceholderScreen reservan los mismos insets como padding (sin cambio visual apreciable)."
      - "El slide de transición entre tabs ahora desliza el contenido por debajo del chrome navy — lectura más pulida."
```

---

## Orden de aplicación

1. `shell_header.dart` — constante `contentHeight` + `SizedBox`.
2. `quesivo_nav_bar.dart` — constante `height`.
3. `shell_insets.dart` — archivo nuevo.
4. `main_layout.dart` — Stack.
5. `module_placeholder_screen.dart`, `home_tab.dart`, `users_screen.dart` — insets.
6. `Design/quesivo-design-system.yaml` — spec + 1.7.2 + changelog.
7. `dart format` en los archivos tocados.
8. `flutter analyze` — debe quedar en 0.
9. `flutter test` — los specs existentes deben seguir verdes; si `users_screen_test` asume alguna posición, ajustar el test (el contenido ahora baja 76px dentro del hero).

## Verificación visual esperada

- Usuarios: banda navy + hero navy = **una sola superficie continua** (sin muescas en las esquinas de la banda); las esquinas r28 del hero revelan el surface del listado; bajo el nav las esquinas muestran surface, no blanco.
- Inicio / placeholders: se ven igual que hoy (contenido bajo la banda, último ítem por encima del nav al scrollear).
- Drawer, tabs y transiciones sin cambio funcional.
