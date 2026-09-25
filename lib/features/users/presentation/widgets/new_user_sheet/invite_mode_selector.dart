import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// Modo de alta del `NewUserSheet` (Email-C, §68):
/// `invite` (default) — el backend manda el correo con el link
/// accept-invite y el invitado elige su password; `manual` — el admin
/// define una contraseña temporal y la comparte a mano (caso real:
/// operario sin correo propio).
enum NewUserMode { invite, manual }

/// Toggle de dos chips con la piel de `RoleSelectorChips` (seleccionado
/// navy/blanco, sin seleccionar iconSurface/navy) en formato segmentado
/// — cada mitad ocupa la misma franja. Congelado durante el submit:
/// `enabled:false` lo deja inerte y atenuado.
class InviteModeSelector extends StatelessWidget {
  const InviteModeSelector({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final NewUserMode selected;

  /// `false` mientras el submit está en vuelo o en la pausa de éxito —
  /// mismo criterio de congelado que `RoleSelectorChips` en el sheet.
  final bool enabled;

  /// Recibe el modo elegido — tocar el activo igual notifica (es no-op
  /// para el sheet: setState con el mismo valor no cambia nada).
  final ValueChanged<NewUserMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Row(
          children: [
            Expanded(
              child: _ModeChip(
                icon: Icons.mail_outline,
                label: l10n.newUserInviteMode,
                isSelected: selected == NewUserMode.invite,
                onTap: () => onChanged(NewUserMode.invite),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeChip(
                icon: Icons.lock_outline,
                label: l10n.newUserManualMode,
                isSelected: selected == NewUserMode.manual,
                onTap: () => onChanged(NewUserMode.manual),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip individual del toggle — misma piel que `_RoleSelectorChip`
/// (pill radius 20, padding 14/10, label 13px w600), centrado porque
/// ocupa una mitad fija del selector.
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
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
      ),
    );
  }
}
