import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_role.dart';

/// Chip del rol de la membresía — pill `quesivoIconSurface` con label
/// navy. El label se resuelve vía l10n (el rol nunca se muestra crudo
/// del contrato).
class MemberRoleChip extends StatelessWidget {
  const MemberRoleChip({super.key, required this.role});

  final UserRole role;

  String _label(AppLocalizations l10n) => switch (role) {
    UserRole.admin => l10n.adminRole,
    UserRole.operator => l10n.roleOperator,
    UserRole.collector => l10n.roleCollector,
    UserRole.producer => l10n.roleProducer,
  };

  /// Ícono de dominio por rol — vocabulario quesero (§38):
  /// escudo = admin, casco = operario de planta, camión = recolector
  /// de ruta, tractor = productor lechero.
  IconData get _icon => switch (role) {
    UserRole.admin => Icons.shield_outlined,
    UserRole.operator => Icons.engineering_outlined,
    UserRole.collector => Icons.local_shipping_outlined,
    UserRole.producer => Icons.agriculture_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.quesivoIconSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: AppColors.quesivoNavy),
          const SizedBox(width: 5),
          Text(
            _label(l10n),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.quesivoNavy,
            ),
          ),
        ],
      ),
    );
  }
}
