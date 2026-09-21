# Propuesta 50: QuesivoLoader — spinner con identidad de marca

Los estados de carga de la app usan `CircularProgressIndicator` genérico (en
auth ni siquiera tiene color de marca — sale con el primary del tema). Se crea
`QuesivoLoader`: un aro track tenue + **arco amarillo de ~110° girando** — el
arco es la "porción de queso" del imagotipo, la firma visual que distingue el
loader de cualquier app Material. Reemplaza todos los loaders existentes.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/widgets/quesivo_loader.dart` | **Nuevo** — spinner de marca (CustomPainter + AnimationController), 3 variantes de color |
| `lib/core/widgets/quesivo_primary_button.dart` | `isLoading` usa `QuesivoLoader(variant: navy)` — sobre fondo amarillo el arco amarillo sería invisible |
| `lib/features/users/presentation/screens/users_screen.dart` | Loader de carga inicial → `QuesivoLoader(size: 40, variant: accent)` + semanticLabel |
| `lib/features/users/presentation/widgets/users_list_footer_loader.dart` | → `QuesivoLoader(size: 22, variant: navy)` |
| `lib/features/auth/presentation/widgets/login_actions.dart` | `CircularProgressIndicator()` → `QuesivoLoader(size: 28, variant: accent)` + label |
| `lib/features/auth/presentation/widgets/register_actions.dart` | ídem |
| `lib/features/auth/presentation/widgets/forgot_password_actions.dart` | ídem |
| `lib/features/auth/presentation/widgets/reset_password_actions.dart` | ídem |
| `lib/l10n/app_es.arb` / `app_en.arb` / `app_pt.arb` | Key nueva `loadingLabel` ("Cargando" / "Loading" / "Carregando") para `Semantics` |
| `test/core/widgets/quesivo_loader_test.dart` | **Nuevo** — widget test del loader |
| `test/features/users/.../users_screen_test.dart` | `find.byType(CircularProgressIndicator)` → `find.byType(QuesivoLoader)` |
| `test/features/users/.../new_user_sheet_test.dart` | ídem (loader del primario) |
| `test/features/users/.../link_user_sheet_test.dart` | ídem |
| `../Design/quesivo-design-system.yaml` | Bump a `1.11.0` (componente nuevo compartido → minor) + spec + changelog |

---

## Diseño

```
   ╭───────╮          variant accent: arco #F7A81D sobre aro navy@18%
  ╱  ····   ╲         variant navy:   arco #07275C sobre aro navy@18%
 │ ··     ·· │   →    variant onNavy: arco #FFFFFF sobre aro white@25%
 │ ··   ◤ ·· │
  ╲  ·◤◤    ╱          stroke = size/9, caps redondos, rotación 1.1s
   ╰───────╯           disableAnimations del SO → arco estático
```

- **accent** (default): la firma — amarillo girando sobre aro navy tenue.
  Para superficies claras: loaders de pantalla completa y los bloques de
  acciones de auth (que reemplazan al botón entero mientras el submit vuela).
- **navy**: todo navy — dentro del `QuesivoPrimaryButton` amarillo (un arco
  amarillo no se vería) y en el footer del listado (momento menor, sutil).
- **onNavy**: blanco sobre blanco tenue — superficies navy (queda lista para
  splash/hero cuando se necesite).

---

## 1. quesivo_loader.dart (archivo nuevo)

**Ruta:** `lib/core/widgets/quesivo_loader.dart`

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Variantes de color del loader según la superficie donde vive.
enum QuesivoLoaderVariant {
  /// Arco quesivoYellow + track navy tenue — la firma de marca: el arco
  /// es la "porción de queso" del imagotipo girando sobre el aro. Para
  /// superficies claras (quesivoSurface/white): loaders de pantalla.
  accent,

  /// Arco + track navy — dentro del pill amarillo del primario (un arco
  /// amarillo desaparecería sobre quesivoYellow) y en momentos sutiles
  /// como el footer del listado.
  navy,

  /// Arco + track quesivoWhite — sobre superficies navy (hero, splash).
  onNavy,
}

/// Spinner de marca (§50) — reemplaza al `CircularProgressIndicator`
/// genérico en toda la app. Aro track tenue + arco de ~110° con caps
/// redondos rotando 1.1s; el arco es la porción de queso del imagotipo.
///
/// Respeta `MediaQuery.disableAnimations`: con "quitar animaciones" del
/// SO activo el loader queda como arco estático (de marca, sin movimiento).
/// `semanticLabel` envuelve en `Semantics` — usarlo en estados de carga
/// de pantalla/bloque (l10n `loadingLabel`); en loaders inline/transitorios
/// (footer de paginación, dentro del botón) dejarlo en null para no llenar
/// TalkBack de anuncios repetidos.
class QuesivoLoader extends StatefulWidget {
  const QuesivoLoader({
    super.key,
    this.size = 24,
    this.variant = QuesivoLoaderVariant.accent,
    this.semanticLabel,
  });

  /// Lado del cuadrado que ocupa el loader; el grosor del trazo es
  /// `size / 9` (22px → ~2.4, igual que los spinners que reemplaza).
  final double size;

  /// Paleta según la superficie — ver `QuesivoLoaderVariant`.
  final QuesivoLoaderVariant variant;

  /// Label para lectores de pantalla — solo en loaders de estado de
  /// pantalla/bloque; null (default) en inline/transitorios.
  final String? semanticLabel;

  @override
  State<QuesivoLoader> createState() => _QuesivoLoaderState();
}

class _QuesivoLoaderState extends State<QuesivoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El ajuste del SO se lee acá (MediaQuery no está listo en initState)
    // y reacciona si cambia en caliente — con movimiento reducido el
    // arco queda estático en vez de rotar.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (arc, track) = switch (widget.variant) {
      QuesivoLoaderVariant.accent => (
        AppColors.quesivoYellow,
        AppColors.quesivoNavy.withValues(alpha: 0.18),
      ),
      QuesivoLoaderVariant.navy => (
        AppColors.quesivoNavy,
        AppColors.quesivoNavy.withValues(alpha: 0.18),
      ),
      QuesivoLoaderVariant.onNavy => (
        AppColors.quesivoWhite,
        AppColors.quesivoWhite.withValues(alpha: 0.25),
      ),
    };

    final loader = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _QuesivoLoaderPainter(
          progress: _controller.value,
          arcColor: arc,
          trackColor: track,
          strokeWidth: widget.size / 9,
        ),
      ),
    );
    return widget.semanticLabel == null
        ? loader
        : Semantics(label: widget.semanticLabel, child: loader);
  }
}

/// Pinta el aro track completo + el arco de ~110° rotando. `progress`
/// (0..1 del controller) define el ángulo de inicio.
class _QuesivoLoaderPainter extends CustomPainter {
  _QuesivoLoaderPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  /// ~110° — la "porción de queso" del imagotipo.
  static const _sweep = math.pi * 0.61;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = trackColor);
    canvas.drawArc(
      arcRect,
      -math.pi / 2 + progress * math.pi * 2,
      _sweep,
      false,
      paint..color = arcColor,
    );
  }

  @override
  bool shouldRepaint(_QuesivoLoaderPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
```

## 2. quesivo_primary_button.dart (actualización)

**Ruta:** `lib/core/widgets/quesivo_primary_button.dart`

**Antes:**
```dart
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.quesivoNavy,
              ),
            )
          : isSuccess
```

**Después:**
```dart
      child: isLoading
          ? const QuesivoLoader(
              size: 22,
              // Sobre el pill amarillo el arco amarillo sería invisible.
              variant: QuesivoLoaderVariant.navy,
            )
          : isSuccess
```

Agregar `import 'quesivo_loader.dart';` (mismo folder `core/widgets`).

## 3. users_screen.dart (actualización)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

**Antes** (en `_buildBody`, rama `loading`):
```dart
        if (state.members.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.quesivoNavy),
          );
        }
```

**Después:**
```dart
        if (state.members.isEmpty) {
          // Primera carga — el momento grande del loader de marca.
          return Center(
            child: QuesivoLoader(size: 40, semanticLabel: l10n.loadingLabel),
          );
        }
```

Agregar `import '../../../../core/widgets/quesivo_loader.dart';`.
(`AppColors` sigue usándose en el RefreshIndicator — el import queda.)

## 4. users_list_footer_loader.dart (actualización)

**Ruta:** `lib/features/users/presentation/widgets/users_list_footer_loader.dart`

**Antes:**
```dart
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.quesivoNavy,
          ),
        ),
      ),
    );
```

**Después:**
```dart
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      // Variante navy: momento menor y transitorio — el accent de marca
      // se reserva para cargas de pantalla. Sin semanticLabel: anunciar
      // "cargando" en cada página del scroll sería ruido en TalkBack.
      child: Center(
        child: QuesivoLoader(size: 22, variant: QuesivoLoaderVariant.navy),
      ),
    );
```

Import: `app_colors.dart` sale, entra `../../../../core/widgets/quesivo_loader.dart`.

## 5-8. Actions de auth (4 actualizaciones idénticas)

`login_actions.dart`, `register_actions.dart`, `forgot_password_actions.dart`,
`reset_password_actions.dart` — el bloque `inProgress` reemplaza al botón
entero mientras el submit vuela (superficie clara → accent, con label porque
es un estado de bloque, no un inline transitorio).

**Antes** (`login_actions.dart`, el patrón es igual en los 4):
```dart
        return state.status.isInProgress
            ? const Center(child: CircularProgressIndicator())
            : Column(
```

**Después:**
```dart
        return state.status.isInProgress
            ? Center(
                child: QuesivoLoader(
                  size: 28,
                  semanticLabel: l10n.loadingLabel,
                ),
              )
            : Column(
```

(En `forgot_password_actions.dart` el bloque es `if (state.status.isInProgress)
{ return const Center(child: CircularProgressIndicator()); }` — mismo
reemplazo. `l10n` ya existe en los 4 archivos; agregar el import del loader —
los que no importan `app_colors.dart` solo agregan `quesivo_loader.dart`.)

## 9. l10n (3 ARBs + regenerar)

Agregar al final de cada ARB:

```json
"loadingLabel": "Cargando"      // es — "Loading" en, "Carregando" pt
```

Ejecutar `flutter gen-l10n`.

## 10. Tests

- **Nuevo** `test/core/widgets/quesivo_loader_test.dart`: renderiza las 3
  variantes (pump + CustomPaint presente), `semanticLabel` envuelve en
  `Semantics`, y con `MediaQuery(disableAnimations: true)` el pumpAndSettle
  no cuelga (el controller no repite).
- **`users_screen_test.dart`**: `find.byType(CircularProgressIndicator)` →
  `find.byType(QuesivoLoader)`.
- **`new_user_sheet_test.dart` / `link_user_sheet_test.dart`**: los finds del
  spinner del primario en vuelo → `QuesivoLoader` (puede haber
  `CircularProgressIndicator` en finds y en `descendant` del button).

## 11. Design system yaml

- `version` → `1.11.0` (componente compartido nuevo → minor).
- Spec nueva `quesivo_loader` en components: variantes, medidas
  (stroke = size/9, sweep ~110°, 1.1s), reglas (accent en pantalla, navy
  en amarillo/inline, onNavy en navy; disableAnimations → estático;
  semanticLabel solo en estados de bloque).
- Actualizar las specs que citan `CircularProgressIndicator`:
  `users_screen` (loading body + footer loader + `submit_state` del
  primario en sheets) → `QuesivoLoader` con su variante.
- Changelog `1.11.0` page "shared", status completed.

---

## Orden de aplicación

1. `quesivo_loader.dart` + `loadingLabel` en 3 ARBs + `flutter gen-l10n`
2. `quesivo_primary_button.dart` + `users_list_footer_loader.dart`
3. `users_screen.dart` + 4 actions de auth
4. Tests (nuevo + finds actualizados) → `flutter analyze` + `flutter test`
5. yaml 1.11.0
