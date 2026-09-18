import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Menú ⋮ de acciones por fila del listado de Usuarios — visual por
/// ahora: cada opción muestra `moduleComingSoon`. Los diálogos de
/// suspender/reactivar y restablecer contraseña llegan con su propuesta.
/// "Suspender usuario" se tiñe `quesivoError` (acción destructiva —
/// mismo criterio que logout en el drawer).
class MemberActionsMenu extends StatelessWidget {
  const MemberActionsMenu({super.key, required this.status});

  final MemberStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suspended = status == MemberStatus.suspended;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.quesivoTextSecondary),
      tooltip: l10n.memberActionsTooltip,
      onSelected: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.moduleComingSoon))),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'status',
          child: Row(
            children: [
              Icon(
                suspended ? Icons.check_circle_outline : Icons.block_outlined,
                size: 20,
                color: suspended
                    ? AppColors.quesivoDarkText
                    : AppColors.quesivoError,
              ),
              const SizedBox(width: 12),
              Text(
                suspended ? l10n.reactivateUserAction : l10n.suspendUserAction,
                style: TextStyle(
                  color: suspended
                      ? AppColors.quesivoDarkText
                      : AppColors.quesivoError,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'password',
          child: Row(
            children: [
              const Icon(
                Icons.lock_reset,
                size: 20,
                color: AppColors.quesivoDarkText,
              ),
              const SizedBox(width: 12),
              Text(l10n.resetPasswordAction),
            ],
          ),
        ),
      ],
    );
  }
}
