import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Divisor con texto centrado de las pantallas de autenticación
/// (§social_divider): línea — texto 15px secondary — línea.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.quesivoBorder, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.quesivoBorder, thickness: 1),
        ),
      ],
    );
  }
}
