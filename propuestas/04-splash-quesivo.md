# Propuesta: Splash Screen con identidad QUESIVO

Rediseño de `SplashScreen` según `Design/quesivo-design-system.yaml` (§8 `pages.splash`,
§2 paleta, §4 sistema decorativo): fondo blanco, logo QUESIVO centrado como único foco,
círculo amarillo parcial con "huecos de queso" en la esquina superior derecha y círculo
navy grande parcial en la esquina inferior izquierda. Flat 2D — sin sombras, degradados
ni marco exterior.

La lógica de sesión (`AuthCubit.checkSession()` → `AuthGuard` → redirect) **no cambia**;
solo cambia la presentación. Se eliminan el texto de carga y el `CircularProgressIndicator`
porque el documento de diseño deja al logo como único foco con mucho espacio negativo.

**Estado: aplicada.** El usuario aportó el imagotipo oficial en
`assets/images/imagotipo_quesivo.png` (2070×760, fondo blanco — sobre el fondo blanco
del splash se ve correcto; si en el futuro se necesita sobre fondo de color, pedir la
versión con transparencia). El `Image` quedó a ancho completo del viewport
(`width: screenWidth`, ajuste manual del usuario): el padding interno del PNG hace
que el imagotipo se vea ~65–70% del ancho real.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `assets/images/imagotipo_quesivo.png` | **Nuevo (binario, lo aporta el usuario)** — imagotipo oficial |
| `lib/core/theme/app_colors.dart` | Actualización — sección aditiva de tokens QUESIVO |
| `lib/core/widgets/quesivo_backdrop.dart` | **Nuevo** — decoración de esquinas reutilizable por todas las pantallas de auth |
| `lib/features/splash/presentation/screens/splash_screen.dart` | Actualización — reemplazo visual completo |

**Sin tocar:** `pubspec.yaml` (`assets/images/` ya está declarado), `app_theme.dart`
(el recableado del `ColorScheme` a la paleta QUESIVO es una propuesta aparte, cuando se
migre el resto de pantallas), `app_router.dart`, `setup_di.dart`.

**i18n:** no se agregan textos. La clave `splashLoadingMessage` queda sin uso en los 3
`.arb` — limpieza opcional (ver paso 6 del orden de aplicación); no es requerida para
que esto funcione.

---

## 1. imagotipo_quesivo.png (archivo nuevo, binario — aporta el usuario)

**Ruta:** `assets/images/imagotipo_quesivo.png`

Imagotipo oficial de QUESIVO sobre fondo transparente. Debe ser la versión original del
logo (no recrearlo con widgets — la spec prohíbe modificarlo/deformarlo).

## 2. app_colors.dart (archivo existente — actualización aditiva)

**Ruta:** `lib/core/theme/app_colors.dart`

Se agrega al final de la clase, antes del cierre — los valores salen directo del design
system (§2 + tokens que repiten las páginas ya especificadas). Los colores 3TIEMPO se
conservan mientras convivan pantallas sin migrar.

**Antes:**
```dart
  // --- COLORES NEUTROS Y COMPARTIDOS ---
  static const Color grey = Colors.grey;
  static const Color transparent = Colors.transparent;
}
```

**Después:**
```dart
  // --- COLORES NEUTROS Y COMPARTIDOS ---
  static const Color grey = Colors.grey;
  static const Color transparent = Colors.transparent;

  // --- IDENTIDAD QUESIVO (Design/quesivo-design-system.yaml §2) ---
  // Tokens fijos de marca: las pantallas de identidad (splash, welcome, auth)
  // usan estos valores directos — no dependen del ColorScheme ni del modo oscuro.
  static const Color quesivoNavy = Color(0xFF07275C); // primary
  static const Color quesivoYellow = Color(0xFFF7A81D); // secondary_accent
  static const Color quesivoWhite = Color(0xFFFFFFFF); // background
  static const Color quesivoDarkText = Color(0xFF172033); // texto principal
  static const Color quesivoSurface = Color(0xFFF7F9FC); // tarjetas / secciones
  static const Color quesivoBorder = Color(0xFFE5EAF2); // bordes sutiles
  static const Color quesivoTextSecondary = Color(0xFF68758A);
  static const Color quesivoPlaceholder = Color(0xFF7A8499);
  static const Color quesivoIconSurface = Color(0xFFEEF2F7); // fondo de íconos

  // Semánticos (§2 semantic_colors)
  static const Color quesivoSuccess = Color(0xFF2E9B62);
  static const Color quesivoWarning = Color(0xFFF2A900);
  static const Color quesivoError = Color(0xFFD64545);
  static const Color quesivoInfo = Color(0xFF3478C8);
}
```

## 3. quesivo_backdrop.dart (archivo nuevo)

**Ruta:** `lib/core/widgets/quesivo_backdrop.dart`

Widget de fondo reutilizable: implementa el `decorative_system` global (§4) — círculo
amarillo con huecos tipo queso arriba a la derecha y círculo navy abajo a la izquierda,
ambos parcialmente fuera del canvas (el `Stack` los recorta con `clipBehavior` por
defecto). Las fracciones de diámetro son parametrizables porque cada página del design
doc usa tamaños levemente distintos (login ~38%, register ~34%, forgot ~27–30%).

> **Nota:** el código mostrado es el **final aplicado** (incluye los ajustes
> post-aplicación y la coreografía documentados más abajo — los valores aquí
> ya difieren de la propuesta original).

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Duración total de la coreografía de entrada (splash / pantallas de auth):
///
/// ```
/// 0ms    400ms   800ms   1200ms  1600ms
///  ├──── navy ────┤                    (0.0–0.5)
///       ├──── yellow ────┤             (0.25–0.75: arranca cuando navy va a la mitad)
///              ├──── imagotipo ────┤   (0.5–1.0: arranca cuando yellow va a la mitad)
/// ```
///
/// Las tres piezas usan esta misma duración con `Interval` distinto, así los
/// `TweenAnimationBuilder` de cada widget quedan sincronizados al montarse en
/// el mismo frame — sin compartir un AnimationController.
const Duration kQuesivoEntryDuration = Duration(milliseconds: 1600);

/// Fondo decorativo de marca QUESIVO (quesivo-design-system.yaml §4).
///
/// Envuelve el contenido de una pantalla con las dos formas decorativas de la
/// identidad: círculo amarillo parcial (con "huecos de queso" blancos) en la
/// esquina superior derecha y círculo navy parcial en la esquina inferior
/// izquierda. Ambos quedan recortados por el borde de la pantalla.
///
/// Flat 2D: color plano, sin bordes, sin sombras, sin degradados.
///
/// Uso:
/// ```dart
/// Scaffold(
///   backgroundColor: AppColors.quesivoWhite,
///   body: QuesivoBackdrop(child: ...),
/// )
/// ```
class QuesivoBackdrop extends StatelessWidget {
  const QuesivoBackdrop({
    super.key,
    required this.child,
    this.topCircleFraction = 0.78,
    this.bottomCircleFraction = 1.30,
    this.withCheeseHoles = true,
    this.animate = true,
  });

  /// Contenido de la pantalla, pintado por encima de la decoración.
  final Widget child;

  /// Diámetro del círculo amarillo como fracción del ancho disponible.
  /// El centro del círculo queda sobre la esquina, así el radio visible
  /// equivale a ~la mitad del diámetro (0.78 → span visible ~0.39 del ancho).
  final double topCircleFraction;

  /// Diámetro del círculo navy como fracción del ancho disponible.
  /// El splash aprobado usa un círculo mayor que el ancho de pantalla.
  final double bottomCircleFraction;

  /// Si el círculo amarillo lleva huecos blancos tipo queso.
  final bool withCheeseHoles;

  /// Si las formas entran animadas desde su esquina al montar la pantalla.
  /// Se desactiva automáticamente con `MediaQuery.disableAnimations`.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final animate = this.animate && !MediaQuery.of(context).disableAnimations;

    return LayoutBuilder(
      builder: (context, constraints) {
        final topDiameter = constraints.maxWidth * topCircleFraction;
        final bottomDiameter = constraints.maxWidth * bottomCircleFraction;

        return Stack(
          children: [
            Positioned(
              bottom: -bottomDiameter / 2,
              left: -bottomDiameter / 2,
              child: _CornerEntry(
                enabled: animate,
                anchor: Alignment.bottomLeft,
                interval: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
                child: _BrandCircle(
                  diameter: bottomDiameter,
                  color: AppColors.quesivoNavy,
                ),
              ),
            ),
            Positioned(
              top: -topDiameter / 2,
              right: -topDiameter / 2,
              child: _CornerEntry(
                enabled: animate,
                anchor: Alignment.topRight,
                interval: const Interval(
                  0.25,
                  0.75,
                  curve: Curves.easeOutCubic,
                ),
                child: _BrandCircle(
                  diameter: topDiameter,
                  color: AppColors.quesivoYellow,
                  withCheeseHoles: withCheeseHoles,
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

/// Anima la entrada de una forma desde su esquina: crece desde el punto de la
/// esquina indicada hasta su tamaño final (scale anclado al corner), dentro de
/// su ventana de la coreografía compartida ([kQuesivoEntryDuration]).
class _CornerEntry extends StatelessWidget {
  const _CornerEntry({
    required this.anchor,
    required this.child,
    required this.interval,
    this.enabled = true,
  });

  /// Esquina desde la que la forma "sale" — coincide con la esquina de la
  /// pantalla donde vive la decoración.
  final Alignment anchor;

  final Widget child;
  final bool enabled;

  /// Ventana del timeline compartido en la que entra esta forma
  /// (navy: 0.0–0.5, amarillo: 0.25–0.75).
  final Interval interval;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: kQuesivoEntryDuration,
      curve: interval,
      builder: (context, value, child) =>
          Transform.scale(scale: value, alignment: anchor, child: child),
      child: child,
    );
  }
}

/// Círculo de color plano; opcionalmente lleva huecos blancos internos que
/// recuerdan los agujeros de la porción de queso del isotipo (§4 optional_detail).
class _BrandCircle extends StatelessWidget {
  const _BrandCircle({
    required this.diameter,
    required this.color,
    this.withCheeseHoles = false,
  });

  final double diameter;
  final Color color;
  final bool withCheeseHoles;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: ColoredBox(
          color: color,
          child: withCheeseHoles
              ? Stack(
                  children: [
                    // Solo el cuadrante inferior-izquierdo del círculo es
                    // visible en pantalla (el resto queda fuera del canvas),
                    // por eso los huecos se concentran ahí. Posiciones y
                    // tamaños calibrados contra el splash aprobado (§8).
                    Positioned(
                      left: diameter * 0.10,
                      top: diameter * 0.55,
                      child: _CheeseHole(size: diameter * 0.10),
                    ),
                    Positioned(
                      left: diameter * 0.17,
                      top: diameter * 0.76,
                      child: _CheeseHole(size: diameter * 0.135),
                    ),
                    Positioned(
                      left: diameter * 0.43,
                      top: diameter * 0.64,
                      child: _CheeseHole(size: diameter * 0.075),
                    ),
                    Positioned(
                      left: diameter * 0.34,
                      top: diameter * 0.95,
                      child: _CheeseHole(size: diameter * 0.085),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _CheeseHole extends StatelessWidget {
  const _CheeseHole({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.quesivoWhite,
        shape: BoxShape.circle,
      ),
    );
  }
}
```

## 4. splash_screen.dart (archivo existente — reemplazo completo)

**Ruta:** `lib/features/splash/presentation/screens/splash_screen.dart`

**Antes:** fondo `colorScheme.primary` (teal 3TIEMPO), logo 120×120, texto
`splashLoadingMessage` y `CircularProgressIndicator` en `tertiary`.

**Después (archivo completo — versión final aplicada):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/auth_cubit.dart';
import '../widgets/quesivo_backdrop.dart';

/// Splash Screen — primer instante de la identidad visual QUESIVO
/// (quesivo-design-system.yaml §8 pages.splash).
///
/// Composición: fondo blanco, imagotipo centrado como único foco (~70% del
/// ancho), círculo amarillo con huecos de queso arriba a la derecha y círculo
/// navy abajo a la izquierda, ambos parcialmente fuera del canvas.
/// Sin texto de carga ni spinner — el logo es el foco con espacio negativo.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Desencadenamos la verificación de sesión cuando el splash se monta;
    // AuthGuard resuelve el redirect cuando el Cubit emite.
    context.read<AuthCubit>().checkSession();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        child: Align(
          // El logo va levemente sobre el centro geométrico (~45% de alto),
          // como en la referencia aprobada del design system.
          alignment: const Alignment(0, -0.15),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            // El imagotipo es la última pieza de la coreografía: permanece
            // oculto la primera mitad del timeline y entra cuando el círculo
            // amarillo va a la mitad de su transición (ver kQuesivoEntryDuration).
            duration: reduceMotion ? Duration.zero : kQuesivoEntryDuration,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.9 + (0.1 * value),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/images/imagotipo_quesivo.png',
              width: screenWidth,
              semanticLabel: 'QUESIVO',
            ),
          ),
        ),
      ),
    );
  }
}
```

**Nota:** se elimina el `import` de `app_localizations.dart` (ya no hay texto en
pantalla) y `l10n` deja de usarse.

---

## Orden de aplicación

1. **(bloqueante)** El usuario copia el imagotipo oficial a
   `assets/images/imagotipo_quesivo.png`.
2. Actualizar `lib/core/theme/app_colors.dart`.
3. Crear `lib/core/widgets/quesivo_backdrop.dart`.
4. Reemplazar `lib/features/splash/presentation/screens/splash_screen.dart`.
5. Correr `flutter analyze` y `flutter test`; verificar visualmente en emulador
   (portrait) en tema claro y oscuro — la pantalla debe verse **idéntica** en ambos
   (los tokens QUESIVO son fijos, decisión del design doc).
6. *(Opcional)* Eliminar `splashLoadingMessage` de `app_es.arb`, `app_en.arb`,
   `app_pt.arb` y correr `flutter gen-l10n`.

## Ajuste post-aplicación (contra la captura aprobada)

Calibrado visual contra la imagen de referencia del splash aprobado:

- `topCircleFraction`: 0.36 → **0.78** (el círculo amarillo es mucho más grande:
  diámetro ~0.8× el ancho, centro sobre la esquina → span visible ~0.39 del ancho).
- `bottomCircleFraction`: 0.30 → **1.30** (el navy es un círculo mayor que el ancho
  de pantalla — el arco visible ocupa ~⅓ del alto).
- Huecos de queso: 3 → **4**, posiciones/tamaños recalibrados (uno queda tangente
  al borde del círculo, recortado por `ClipOval`).
- Logo: 70% → 65% → **ancho completo** (`width: screenWidth`, ajuste manual del
  usuario — el padding interno del PNG lo deja ~65–70% visual), y de `Center` a
  `Align(0, -0.15)` — queda levemente sobre el centro geométrico (~45% de alto),
  como en la captura.

## Coreografía de entrada (agregada)

Las tres piezas entran en secuencia escalonada sobre un reloj compartido de 1600ms
(`kQuesivoEntryDuration`) — cada una corre un `TweenAnimationBuilder` con su propio
`Interval`, sincronizadas por montarse en el mismo frame:

```
0ms    400ms   800ms   1200ms  1600ms
 ├──── navy ────┤                    (0.0–0.5, easeOutCubic, desde bottom-left)
      ├──── yellow ────┤            (0.25–0.75, easeOutCubic, desde top-right)
             ├──── imagotipo ────┤  (0.5–1.0, easeOutCubic, fade+scale)
```

- Navy sale primero de su esquina; amarillo arranca cuando navy va a la mitad;
  el imagotipo arranca cuando amarillo va a la mitad.
- La escala de los círculos está anclada a su esquina (`Transform.scale` con
  `alignment`) — la forma "sale" del borde, no aparece de golpe.
- Curva `easeOutCubic` en las tres piezas: entrada suave y simple, sin rebote
  (se descartó `easeOutBack` por feedback visual).
- `QuesivoBackdrop.animate` (default `true`) controla la entrada; se desactiva
  solo si el sistema pide `disableAnimations`.

## Reubicación (post-aplicación)

`splash_screen.dart` se movió de `features/auth/` a su propio mini-feature:
`features/splash/presentation/screens/splash_screen.dart`. Motivo: el splash es
la entrada de la app, no una pantalla de autenticación — solo depende de
`AuthCubit` para disparar `checkSession()`.

`quesivo_backdrop.dart` se movió a `lib/core/widgets/quesivo_backdrop.dart`
(nueva carpeta de widgets compartidos): al quedar consumido por `features/splash`
además de las pantallas de auth, pasó a ser infraestructura transversal de marca,
no un widget de un feature.

## Notas

- **Logo placeholder:** mientras no exista el imagotipo oficial, se puede copiar
  cualquier PNG a `assets/images/imagotipo_quesivo.png` solo para probar el layout —
  la spec exige el logo real para la versión final.
- **Animación:** el imagotipo conserva su fade+scale pero ahora corre dentro de
  la coreografía compartida de 1600ms (ver "Coreografía de entrada"); se respeta
  `disableAnimations` en las tres piezas.
- **Rebrand pendiente (fuera de alcance):** renombrar el paquete `tercer_tiempo` →
  `quesivo` (pubspec + todos los imports `package:tercer_tiempo/...`), recablear
  `AppTheme`/`ColorScheme` a la paleta QUESIVO, y migrar login/register/welcome —
  cada una es propuesta aparte según el workflow.
- **Reutilización:** `QuesivoBackdrop` es el mismo componente que welcome, login,
  register, forgot_password y reset_password usarán — solo variando
  `topCircleFraction`/`bottomCircleFraction`/`withCheeseHoles` según la spec de
  cada página.
