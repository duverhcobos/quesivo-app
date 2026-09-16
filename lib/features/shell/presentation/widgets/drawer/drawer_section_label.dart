import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Label de categoría del menú — 12px w600 `quesivoTextSecondary` en
/// mayúsculas con letterspacing leve (los arb guardan title case natural;
/// el uppercase es solo presentación). Padding top 8 / bottom 10 — vive
/// dentro de la `DrawerCategoryCard`, que ya aporta el aire superior.
class DrawerSectionLabel extends StatelessWidget {
  const DrawerSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.quesivoTextSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
