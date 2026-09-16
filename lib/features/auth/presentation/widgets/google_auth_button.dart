import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// Botón outlined pill 64px con la "G" de Google de las pantallas de
/// autenticación (§google_register / §google_login): 17px w600 navy,
/// border `quesivoBorder` 1.5.
class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({
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
      child: OutlinedButton.icon(
        icon: SvgPicture.asset(
          'assets/images/google_g.svg',
          width: 24,
          height: 24,
        ),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.quesivoNavy,
          side: const BorderSide(color: AppColors.quesivoBorder, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        label: Text(label),
      ),
    );
  }
}
