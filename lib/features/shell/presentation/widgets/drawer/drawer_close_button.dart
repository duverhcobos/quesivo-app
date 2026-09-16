import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Botón ✕ del header del `QuesivoDrawer` — círculo navy 40px con
/// `Icons.close` blanco 22; cierra el drawer con pop. Mismo tamaño que la
/// hamburguesa del `ShellHeader` (≡ blanca en círculo de borde blanco) —
/// ocupa su misma posición para que el mismo toque abra y cierre.
class DrawerCloseButton extends StatelessWidget {
  const DrawerCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.quesivoNavy,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Ripple circular — mismo criterio que la hamburguesa del header.
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).pop(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close, size: 22, color: AppColors.quesivoWhite),
        ),
      ),
    );
  }
}
