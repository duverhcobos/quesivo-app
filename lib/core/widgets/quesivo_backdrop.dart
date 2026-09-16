import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
