import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Pill amarillo 64px/18/w700 de las pantallas de autenticación
/// (§primary_button) con estado disabled atenuado.
///
/// `onPressed` en `null` deja el botón deshabilitado (amarillo/navy
/// atenuados al 45%/50%).
class QuesivoPrimaryButton extends StatelessWidget {
  const QuesivoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.quesivoYellow,
          foregroundColor: AppColors.quesivoNavy,
          disabledBackgroundColor: AppColors.quesivoYellow.withValues(
            alpha: 0.45,
          ),
          disabledForegroundColor: AppColors.quesivoNavy.withValues(alpha: 0.5),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
