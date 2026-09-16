import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Título 32/w800 navy + descripción 16 de las pantallas de autenticación
/// (§*_heading, alineado a la izquierda).
///
/// Los defaults son los valores de register/login (`height: 1.0` y gap 14
/// en el título, descripción `quesivoDarkText`); las demás pantallas pasan
/// los suyos (forgot: `titleHeight: 1.05`, `titleGap: 16`,
/// `quesivoTextSecondary`, `descriptionHeight: 1.45`; reset:
/// `quesivoPlaceholder`).
class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.title,
    required this.description,
    this.titleHeight = 1.0,
    this.titleGap = 14,
    this.descriptionMaxLines = 2,
    this.descriptionColor = AppColors.quesivoDarkText,
    this.descriptionHeight = 1.4,
  });

  final String title;
  final String description;
  final double titleHeight;
  final double titleGap;
  final int descriptionMaxLines;
  final Color descriptionColor;
  final double descriptionHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: titleHeight,
            color: AppColors.quesivoNavy,
          ),
        ),
        SizedBox(height: titleGap),
        Text(
          description,
          maxLines: descriptionMaxLines,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: descriptionHeight,
            color: descriptionColor,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
