import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// "Accesos rápidos" del tab Inicio (propuesta §shell-premium).
///
/// Fila de 4 tiles circulares `quesivoIconSurface` hacia los flujos más
/// frecuentes. Todos nacen con `onTap: null` (atenuados al 45%) hasta que
/// cada módulo exista — basta pasarles un `onTap` para activarlos.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickActions,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.quesivoNavy,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QuickActionTile(
              icon: Icons.water_drop_outlined,
              label: l10n.quickNewReception,
              onTap: null,
            ),
            _QuickActionTile(
              icon: Icons.point_of_sale_outlined,
              label: l10n.quickNewSale,
              onTap: null,
            ),
            _QuickActionTile(
              icon: Icons.groups_outlined,
              label: l10n.quickProducers,
              onTap: null,
            ),
            _QuickActionTile(
              icon: Icons.receipt_long_outlined,
              label: l10n.quickSettlements,
              onTap: null,
            ),
          ],
        ),
      ],
    );
  }
}

/// Tile circular de acceso rápido: ícono navy sobre `quesivoIconSurface`
/// + label debajo. `onTap: null` = estado "próximamente" atenuado.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    this.onTap, // null = módulo no implementado todavía
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final contentColor = isEnabled
        ? AppColors.quesivoNavy
        : AppColors.quesivoNavy.withValues(alpha: 0.45);

    return Expanded(
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.quesivoIconSurface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 24, color: contentColor),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.15,
                    color: contentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
