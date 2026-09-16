import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// "Actividad reciente" del tab Inicio (propuesta §shell-premium).
///
/// Hoy es solo el empty state — las operaciones del día (recepciones,
/// ventas, pagos) se listan acá cuando el backend las exponga.
class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentActivity,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.quesivoNavy,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: AppColors.quesivoPlaceholder,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.noActivity,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.quesivoTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.noActivityHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.quesivoTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
