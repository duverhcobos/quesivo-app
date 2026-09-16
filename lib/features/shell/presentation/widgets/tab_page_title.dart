import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Heading de sección al inicio del cuerpo de cada tab del shell
/// (propuesta §header-navy-avatar).
///
/// El `ShellHeader` ya no muestra el título del tab (es banda navy de
/// identidad): cada pantalla abre su `ListView` con este título — mismo
/// lenguaje que `AuthHeading` (navy w800) pero a 28px y sin descripción.
class TabPageTitle extends StatelessWidget {
  const TabPageTitle({super.key, required this.title});

  /// Texto del título (reusa las claves l10n `nav*` existentes).
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.quesivoNavy,
      ),
    );
  }
}
