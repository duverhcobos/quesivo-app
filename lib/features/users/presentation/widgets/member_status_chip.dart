import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Chip del estado de la membresía — pill con punto + label:
/// `active` en `quesivoSuccess`, `suspended` en `quesivoError`.
class MemberStatusChip extends StatelessWidget {
  const MemberStatusChip({super.key, required this.status});

  final MemberStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (color, label) = switch (status) {
      MemberStatus.active => (
        AppColors.quesivoSuccess,
        l10n.memberStatusActive,
      ),
      MemberStatus.suspended => (
        AppColors.quesivoError,
        l10n.memberStatusSuspended,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
