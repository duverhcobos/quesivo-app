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
      // Piel clara forzada: el módulo es light-only y sin `color` el popup
      // toma el surface del tema — en dark mode sale oscuro y los textos
      // navy quedan ilegibles (bug visto en físico). Mismo lenguaje que la
      // card: blanco, radius 16, hairline border, sombra navy 12%.
      color: AppColors.quesivoWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: AppColors.quesivoShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.quesivoBorder),
      ),
      // Cae justo debajo del ⋮ en vez de cubrir el contenido de la card.
      offset: const Offset(0, 8),
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
                    ? AppColors.quesivoSuccess
                    : AppColors.quesivoError,
              ),
              const SizedBox(width: 12),
              Text(
                suspended ? l10n.reactivateUserAction : l10n.suspendUserAction,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: suspended
                      ? AppColors.quesivoSuccess
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
              Text(
                l10n.resetPasswordAction,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.quesivoDarkText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
