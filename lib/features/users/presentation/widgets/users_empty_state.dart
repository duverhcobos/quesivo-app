import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// Estado vacío del listado de Usuarios — mismo lenguaje visual que
/// `ModulePlaceholderScreen` (círculo iconSurface + título + hint).
class UsersEmptyState extends StatelessWidget {
  const UsersEmptyState({super.key, this.icon, this.title, this.hint});

  /// Overrides opcionales — §43: la búsqueda/filtro sin resultados reusa
  /// este widget con ícono/textos distintos en vez del vacío real de la
  /// org (`group_outlined` + `emptyUsers*`, que quedan como default).
  final IconData? icon;
  final String? title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.quesivoIconSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon ?? Icons.group_outlined,
              size: 44,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title ?? l10n.emptyUsersTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint ?? l10n.emptyUsersHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
