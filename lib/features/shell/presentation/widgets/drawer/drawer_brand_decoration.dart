import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Círculo decorativo de marca del `QuesivoDrawer` — misma construcción que
/// `_BrandCircle` de `QuesivoBackdrop`: `ClipOval` + `ColoredBox` plano y,
/// opcionalmente, huecos blancos `Positioned` concentrados en el cuadrante
/// visible de la forma (la mitad restante queda fuera del canvas).
class DrawerBrandDecoration extends StatelessWidget {
  const DrawerBrandDecoration({
    super.key,
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
                    // visible (el resto queda fuera del canvas), así que los
                    // huecos se concentran ahí — mismas posiciones
                    // calibradas del backdrop.
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

/// Hueco blanco circular de la decoración — replica `_CheeseHole` del
/// backdrop (los agujeros de la porción de queso del isotipo, §4).
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
