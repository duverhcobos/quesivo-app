import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_role.dart';
import 'user_role_ui.dart';

/// Selector de rol del sheet de creación (§44) — los 4 roles del catálogo
/// como chips seleccionables con la misma piel que `RoleFilterChips`
/// (seleccionado navy/blanco, sin seleccionar iconSurface/navy), en Wrap
/// porque 4 chips no siempre entran en una sola fila dentro del sheet.
///
/// Sin "Todos" ni default: el rol es obligatorio y se elige explícito —
/// preseleccionar uno generaría membresías equivocadas por descuido.
class RoleSelectorChips extends StatelessWidget {
  const RoleSelectorChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final UserRole? selected;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in UserRole.values)
          _RoleSelectorChip(
            label: role.label(l10n),
            icon: role.icon,
            isSelected: role == selected,
            onTap: () => onChanged(role),
          ),
      ],
    );
  }
}

class _RoleSelectorChip extends StatelessWidget {
  const _RoleSelectorChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
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
