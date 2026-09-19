import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';

/// Confirmación de suspender/reactivar la membresía (§45) — primer
/// `AlertDialog` de la app. La variante se deriva de `member.status`:
/// suspender = destructiva (rojo), reactivar = neutra (amarillo).
///
/// Devuelve `true` si se confirmó. Solo UI: la mutación la hace el
/// caller en el dataset local; al integrar `PATCH /auth/users/:id/status`
/// las reglas `SELF_SUSPENSION`/`LAST_ADMIN` del backend se mapean a
/// mensajes acá (doc 009).
class MemberStatusDialog extends StatelessWidget {
  const MemberStatusDialog({super.key, required this.member});

  final OrgMember member;

  static Future<bool> show(BuildContext context, OrgMember member) {
    return showDialog<bool>(
      context: context,
      builder: (_) => MemberStatusDialog(member: member),
    ).then((v) => v ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suspending = member.status == MemberStatus.active;
    final accent = suspending
        ? AppColors.quesivoError
        : AppColors.quesivoSuccess;

    return AlertDialog(
      backgroundColor: AppColors.quesivoWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: CircleAvatar(
        radius: 24,
        backgroundColor: accent.withValues(alpha: 0.12),
        child: Icon(
          suspending ? Icons.block_outlined : Icons.check_circle_outline,
          color: accent,
          size: 24,
        ),
      ),
      title: Text(
        suspending
            ? l10n.suspendMemberTitle(member.name)
            : l10n.reactivateMemberTitle(member.name),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.quesivoNavy,
        ),
      ),
      content: Text(
        suspending ? l10n.suspendMemberMessage : l10n.reactivateMemberMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppColors.quesivoTextSecondary,
        ),
      ),
      // Botones hug-content centrados: OverflowBar los pone lado a lado
      // cuando entran (la mayoría de teléfonos) y los apila a ancho
      // completo cuando el diálogo es muy angosto — nunca envuelve el
      // label a 2 líneas (un Row+Expanded lo forzaría en ~110dp).
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.quesivoIconSurface,
            foregroundColor: AppColors.quesivoNavy,
            elevation: 0,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(l10n.cancelAction),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: suspending
                ? AppColors.quesivoError
                : AppColors.quesivoYellow,
            foregroundColor: suspending
                ? AppColors.quesivoWhite
                : AppColors.quesivoNavy,
            elevation: 0,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(
            suspending ? l10n.suspendUserAction : l10n.reactivateUserAction,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
