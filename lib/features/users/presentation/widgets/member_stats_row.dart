import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Fila de stats del listado de Usuarios dentro de la cabecera navy —
/// "N miembros · N activos" (dot amarillo = total, dot success =
/// activos). Números de dominio, no decoración.
///
/// Desde §49 el conteo de miembros usa `meta.total` del
/// `GET /auth/users` (total FILTRADO — con búsqueda/rol activo muestra
/// los que coinciden con la vista), no `members.length` que sería solo
/// lo cargado por paginación. El dot de activos sigue contando sobre
/// las filas cargadas — el backend no expone un conteo por estado.
class MemberStatsRow extends StatelessWidget {
  const MemberStatsRow({super.key, required this.members, this.total});

  /// Filas cargadas del listado — alimenta el conteo de activos.
  final List<OrgMember> members;

  /// Total real del backend (`UsersPage.total`). `null` →
  /// `members.length` (fixture/local).
  final int? total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = members.where((m) => m.status == MemberStatus.active).length;

    return Row(
      children: [
        _StatDot(
          color: AppColors.quesivoYellow,
          label: l10n.membersCount(total ?? members.length),
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
