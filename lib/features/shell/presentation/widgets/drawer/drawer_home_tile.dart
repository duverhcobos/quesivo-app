import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Tile "Inicio" del `QuesivoDrawer` — va a /home tras cerrarse; con
/// `selected` (ruta activa == /home exacto) se pinta como pastilla
/// `quesivoSurface` con ícono `quesivoYellow`, si no queda sobre blanco.
class DrawerHomeTile extends StatelessWidget {
  const DrawerHomeTile({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // Semantics: botón + estado seleccionado para TalkBack — igual que las
    // filas de módulo (`DrawerMenuItemRow`).
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.quesivoSurface : AppColors.quesivoWhite,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 22,
                  color: selected
                      ? AppColors.quesivoYellow
                      : AppColors.quesivoNavy,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.quesivoPlaceholder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
