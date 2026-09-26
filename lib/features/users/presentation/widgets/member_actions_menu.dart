import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import 'change_role_dialog.dart';
import 'member_status_dialog.dart';
import 'reset_password_sheet.dart';

/// Menú ⋮ de acciones por fila (§45): "Suspender/Reactivar" abre
/// `MemberStatusDialog`, §54 agrega "Cambiar rol" (ítem neutro entre
/// ambas) que abre `ChangeRoleDialog` — devuelve el `UserRole` nuevo o
/// null — y "Restablecer contraseña" abre `ResetPasswordSheet`. Desde
/// §52/§54 las acciones ya son reales: los dialogs confirman y la
/// screen dispara el PATCH; el sheet de reset lo hace dentro con su
/// cubit y devuelve el miembro del 200.
/// "Suspender usuario" se tiñe `quesivoError` (acción destructiva —
/// mismo criterio que logout en el drawer).
///
/// §68 — Email-C: cuando `member.invitePending` es
/// `pendingVerification` el menú abre con "Reenviar invitación" (ícono
/// `send`, navy — no destructiva) que dispara
/// `POST /auth/users/:id/resend-invite` vía `onResendInvite`. El gate
/// es el estado GLOBAL de la cuenta, no el de la membresía: el invitado
/// pendiente tiene `MemberStatus.active` pero todavía no aceptó el mail.
///
/// §69 — backend 072: sobre `invitePending` el menú solo ofrece
/// Reenviar/Cancelar (suspend/rol/password son errores garantizados:
/// `MEMBERSHIP_INVITED`/`NOT_INVITED` en backend). "Cancelar
/// invitación" pide confirmación y dispara `DELETE /users/:id`
/// vía `onCancelInvite`.
class MemberActionsMenu extends StatelessWidget {
  const MemberActionsMenu({
    super.key,
    required this.member,
    required this.onStatusToggle,
    required this.onPasswordReset,
    required this.onRoleChange,
    required this.onResendInvite,
    required this.onCancelInvite,
    this.sheetTopInset = 0,
  });

  final OrgMember member;

  /// Recibe el nuevo `MemberStatus` si el admin confirmó el diálogo.
  final ValueChanged<MemberStatus> onStatusToggle;

  /// Recibe el `UserRole` nuevo si el admin confirmó `ChangeRoleDialog`
  /// (§54) — la screen dispara el PATCH real.
  final ValueChanged<UserRole> onRoleChange;

  /// Recibe el `OrgMember` del 200 cuando el sheet completó el reset.
  final ValueChanged<OrgMember> onPasswordReset;

  /// §68 — reenvío de invitación (`POST /auth/users/:id/resend-invite`):
  /// la screen dispara el POST real y decide el toast — el menú solo
  /// notifica (no hay diálogo: la acción no es destructiva).
  final VoidCallback onResendInvite;

  /// §69 — cancelación de la invitación (`DELETE /users/:id`):
  /// destructiva suave — el menú ya pidió confirmación con diálogo; la
  /// screen dispara el DELETE real y el toast.
  final VoidCallback onCancelInvite;

  /// Tope del `ResetPasswordSheet` (borde inferior del hero navy) —
  /// lo mide la pantalla y viaja por la card hasta acá.
  final double sheetTopInset;

  Future<void> _onSelected(BuildContext context, String value) async {
    switch (value) {
      case 'invite':
        // §68 — sin confirmación: reenviar el mail no destruye nada y
        // el busy de la card ya da feedback del vuelo.
        onResendInvite();
      case 'cancel':
        final l10n = AppLocalizations.of(context)!;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.quesivoWhite,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(l10n.cancelInviteConfirmTitle),
            content: Text(l10n.cancelInviteConfirmBody(member.email)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancelAction),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  l10n.cancelInviteAction,
                  style: const TextStyle(color: AppColors.quesivoError),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) onCancelInvite();
      case 'status':
        final confirmed = await MemberStatusDialog.show(context, member);
        if (!confirmed || !context.mounted) return;
        onStatusToggle(
          member.status == MemberStatus.active
              ? MemberStatus.suspended
              : MemberStatus.active,
        );
      case 'role':
        // §54 — el diálogo devuelve el rol nuevo o null (canceló o no
        // cambió); la screen dispara el PATCH real.
        final role = await ChangeRoleDialog.show(context, member);
        if (role == null || !context.mounted) return;
        onRoleChange(role);
      case 'password':
        // §52 — el sheet hace el PATCH real con su propio cubit y
        // devuelve el miembro del 200 (o null al cancelar/fallar).
        final resetMember = await ResetPasswordSheet.show(
          context,
          member,
          topInset: sheetTopInset,
        );
        if (resetMember == null || !context.mounted) return;
        onPasswordReset(resetMember);
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
        // §68 — "Reenviar invitación" solo para invitados que todavía
        // no aceptaron el mail (`invitePending` = pending + sin
        // password, derivado del backend — el gate exacto del 204 vs
        // INVITE_NOT_PENDING). Primero en la lista: es la acción más
        // contextual para un invitado pendiente.
        if (member.invitePending)
          PopupMenuItem<String>(
            value: 'invite',
            child: Row(
              children: [
                const Icon(
                  Icons.send_outlined,
                  size: 20,
                  color: AppColors.quesivoNavy,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.resendInviteAction,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // §69 — cancelación: solo con invitación pendiente; destructiva
        // suave (rojo) con confirmación — borra la membresía invited o
        // el artefacto completo si era su única membresía (backend 072).
        if (member.invitePending)
          PopupMenuItem<String>(
            value: 'cancel',
            child: Row(
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  size: 20,
                  color: AppColors.quesivoError,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.cancelInviteAction,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.quesivoError,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // §69 — suspend/rol/password NO sobre invitaciones pendientes:
        // el backend rechaza invited con 409 (MEMBERSHIP_INVITED) y
        // sobre el artefacto no tienen sentido (nunca logueó).
        if (!member.invitePending) ...[
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
            value: 'role',
            child: Row(
              children: [
                const Icon(
                  Icons.manage_accounts_outlined,
                  size: 20,
                  color: AppColors.quesivoDarkText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.changeRoleAction,
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
      ],
    );
  }
}
