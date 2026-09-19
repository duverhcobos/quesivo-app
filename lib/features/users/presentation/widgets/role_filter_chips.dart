import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_role.dart';

/// Fila de chips horizontales para filtrar el listado por rol — "Todos"
/// (`selected == null`) + los 4 roles del catálogo, mismos íconos de
/// dominio que `MemberRoleChip` (§38) para que el vocabulario visual sea
/// el mismo en el chip de fila y en el filtro.
class RoleFilterChips extends StatelessWidget {
  const RoleFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// `null` = "Todos".
  final UserRole? selected;
  final ValueChanged<UserRole?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(UserRole?, String, IconData?)>[
      (null, l10n.roleFilterAll, null),
      (UserRole.admin, l10n.adminRole, Icons.shield_outlined),
      (UserRole.operator, l10n.roleOperator, Icons.engineering_outlined),
      (UserRole.collector, l10n.roleCollector, Icons.local_shipping_outlined),
      (UserRole.producer, l10n.roleProducer, Icons.agriculture_outlined),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (role, label, icon) = options[index];
          return _RoleFilterChip(
            label: label,
            icon: icon,
            isSelected: role == selected,
            onTap: () => onChanged(role),
          );
        },
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? AppColors.quesivoWhite : AppColors.quesivoNavy;
    return Material(
      color: isSelected ? AppColors.quesivoNavy : AppColors.quesivoIconSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
