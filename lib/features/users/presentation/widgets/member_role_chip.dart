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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.quesivoIconSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(l10n),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.quesivoNavy,
        ),
      ),
    );
  }
}
