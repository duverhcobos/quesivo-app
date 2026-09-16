import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "texto plano linkAmarillo" en una línea (§login_prompt /
/// register_prompt): texto 16px `darkText` seguido de un `TextSpan`
/// amarillo w700 que dispara `onTap`.
class AuthPrompt extends StatelessWidget {
  const AuthPrompt({
    super.key,
    required this.text,
    required this.linkText,
    required this.onTap,
  });

  final String text;
  final String linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.quesivoDarkText,
            ),
            children: [
              TextSpan(text: text),
              const TextSpan(text: ' '),
              TextSpan(
                text: linkText,
                style: const TextStyle(
                  color: AppColors.quesivoYellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
