import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'onboarding_dots.dart';

/// Panel navy inferior del onboarding: dots + botón next/"Comenzar"
/// (patrón welcome_panel del design doc: ancho completo, esquinas
/// superiores 30px, flat).
class OnboardingBottomPanel extends StatelessWidget {
  const OnboardingBottomPanel({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.buttonLabel,
    required this.onPressed,
  });

  final int count;
  final int currentIndex;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.quesivoNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingDots(
              count: count,
              currentIndex: currentIndex,
              activeColor: AppColors.quesivoYellow,
              inactiveColor: AppColors.quesivoWhite.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.quesivoYellow,
                  foregroundColor: AppColors.quesivoNavy,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
