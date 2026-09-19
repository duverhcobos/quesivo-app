import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Fila de stats del listado de Usuarios dentro de la cabecera navy —
/// "N miembros · N activos" calculados de la lista real (dot amarillo =
/// total, dot success = activos). Números de dominio, no decoración.
class MemberStatsRow extends StatelessWidget {
  const MemberStatsRow({super.key, required this.members});

  final List<OrgMember> members;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = members.where((m) => m.status == MemberStatus.active).length;

    return Row(
      children: [
        _StatDot(
          color: AppColors.quesivoYellow,
          label: l10n.membersCount(members.length),
        ),
        const SizedBox(width: 16),
        _StatDot(
          color: AppColors.quesivoSuccess,
          label: l10n.activeMembersCount(active),
        ),
      ],
    );
  }
}

/// Punto de color + label blanco — unidad visual de un stat.
class _StatDot extends StatelessWidget {
  const _StatDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.quesivoWhite,
          ),
        ),
      ],
    );
  }
}
