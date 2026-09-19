import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';
import 'member_status_dialog.dart';
import 'reset_password_sheet.dart';

/// Menú ⋮ de acciones por fila (§45): "Suspender/Reactivar" abre
/// `MemberStatusDialog` y "Restablecer contraseña" abre
/// `ResetPasswordSheet`. Los resultados suben por callback — la
/// pantalla decide la mutación local hoy y el PATCH mañana.
/// "Suspender usuario" se tiñe `quesivoError` (acción destructiva —
/// mismo criterio que logout en el drawer).
class MemberActionsMenu extends StatelessWidget {
  const MemberActionsMenu({
    super.key,
    required this.member,
    required this.onStatusToggle,
    required this.onPasswordReset,
    this.sheetTopInset = 0,
  });

  final OrgMember member;

  /// Recibe el nuevo `MemberStatus` si el admin confirmó el diálogo.
  final ValueChanged<MemberStatus> onStatusToggle;

  /// Recibe el password ingresado si el admin completó el sheet.
  final ValueChanged<String> onPasswordReset;

  /// Tope del `ResetPasswordSheet` (borde inferior del hero navy) —
  /// lo mide la pantalla y viaja por la card hasta acá.
  final double sheetTopInset;

  Future<void> _onSelected(BuildContext context, String value) async {
    switch (value) {
      case 'status':
        final confirmed = await MemberStatusDialog.show(context, member);
        if (!confirmed || !context.mounted) return;
        onStatusToggle(
          member.status == MemberStatus.active
              ? MemberStatus.suspended
              : MemberStatus.active,
        );
      case 'password':
        final password = await ResetPasswordSheet.show(
          context,
          member,
          topInset: sheetTopInset,
        );
        if (password == null || !context.mounted) return;
        onPasswordReset(password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suspended = member.status == MemberStatus.suspended;

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
      onSelected: (value) => _onSelected(context, value),
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
              Expanded(
                child: Text(
                  suspended
                      ? l10n.reactivateUserAction
                      : l10n.suspendUserAction,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: suspended
                        ? AppColors.quesivoSuccess
                        : AppColors.quesivoError,
                  ),
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
              Expanded(
                child: Text(
                  l10n.resetPasswordAction,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.quesivoDarkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
