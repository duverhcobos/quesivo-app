import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'onboarding_hero.dart';

/// Slide individual del carrusel: hero de marca + título + descripción.
/// El hero aplica parallax según la posición de scroll del PageView.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.controller,
    required this.index,
  });

  final IconData icon;
  final String title;
  final String description;

  /// Controller del PageView — se escucha para el parallax del hero.
  final PageController controller;

  /// Índice de este slide dentro del PageView.
  final int index;

  /// Cuánto se desplaza el hero por página de scroll (px por delta).
  static const double _parallaxPx = 40;

  @override
  Widget build(BuildContext context) {
    final heroSize = MediaQuery.sizeOf(context).width * 0.62;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              // delta = cuánto está scrolleada esta página fuera de foco:
              // 0 = visible, ±1 = adyacente. El hero se mueve en dirección
              // contraria → efecto de profundidad al arrastrar.
              final page = controller.hasClients
                  ? (controller.page ?? index.toDouble())
                  : index.toDouble();
              final delta = (page - index).clamp(-1.0, 1.0);
              return Transform.translate(
                offset: Offset(delta * -_parallaxPx, 0),
                child: child,
              );
            },
            child: OnboardingHero(icon: icon, size: heroSize),
          ),
          const SizedBox(height: 44),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
