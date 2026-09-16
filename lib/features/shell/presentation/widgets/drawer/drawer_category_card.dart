import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'drawer_section_label.dart';

/// Tarjeta de categoría del `DrawerMenuList` — contenedor blanco con borde
/// `quesivoBorder` y radius 16 que agrupa el `DrawerSectionLabel` y las
/// filas de esa sección (Operaciones, Directorio, Finanzas, Configuración).
/// La pastilla `surface` del ítem seleccionado sigue leyéndose sobre el
/// blanco de la tarjeta.
class DrawerCategoryCard extends StatelessWidget {
  const DrawerCategoryCard({
    super.key,
    required this.title,
    required this.children,
  });

  /// Texto ya localizado de la sección (pasa al `DrawerSectionLabel`).
  final String title;

  /// Filas de la categoría — los `DrawerMenuItemRow` de sus módulos.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.quesivoWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.quesivoBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [DrawerSectionLabel(title), ...children],
      ),
    );
  }
}
