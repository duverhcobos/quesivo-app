import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Hero visual del slide de onboarding: blob amarillo QUESIVO con "huecos de
/// queso" blancos + ícono navy centrado. Es el elemento firma de la marca
/// llevado a tamaño protagonista.
class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key, required this.icon, required this.size});

  final IconData icon;

  /// Diámetro del blob.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ColoredBox(
              color: AppColors.quesivoYellow,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    _hole(0.16, 0.22, 0.11),
                    _hole(0.62, 0.14, 0.075),
                    _hole(0.74, 0.52, 0.12),
                    _hole(0.28, 0.68, 0.09),
                    _hole(0.48, 0.38, 0.06),
                  ],
                ),
              ),
            ),
          ),
          Icon(icon, size: size * 0.30, color: AppColors.quesivoNavy),
        ],
      ),
    );
  }

  /// Hueco blanco posicionado en fracciones del diámetro del blob
  /// (`left`/`top`/`size` relativos al tamaño del blob).
  Widget _hole(double left, double top, double holeSize) {
    return Positioned(
      left: size * left,
      top: size * top,
      child: Container(
        width: size * holeSize,
        height: size * holeSize,
        decoration: const BoxDecoration(
          color: AppColors.quesivoWhite,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
