import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../../core/widgets/user_initials_avatar.dart';
import '../../domain/entities/org_member.dart';
import 'member_actions_menu.dart';
import 'member_role_chip.dart';
import 'member_status_chip.dart';

/// Card de un miembro de la organización en el listado de Usuarios:
/// avatar de iniciales + nombre + email + chips de rol/estado + menú de
/// acciones ⋮ que abre `MemberStatusDialog` / `ResetPasswordSheet` (§45).
///
/// §49: cuando `member.isOwner` el Wrap de chips gana el badge "Dueño"
/// (pill con borde navy — la marca distintiva del owner, `isOwner` del
/// GET /auth/users) y el ⋮ `MemberActionsMenu` NO se renderiza:
/// suspender/reset sobre el dueño son `OWNER_*` en backend — ofrecerlos
/// sería un error garantizado. §52: tampoco se renderiza en la card
/// propia (`isSelf` — SELF_SUSPENSION garantizado y resetearse revocaría
/// la sesión propia) y con un PATCH en vuelo (`isBusy`) cede a un
/// `QuesivoLoader` chico navy.
class OrgMemberCard extends StatelessWidget {
  const OrgMemberCard({
    super.key,
    required this.member,
    required this.onStatusToggle,
    required this.onPasswordReset,
    this.sheetTopInset = 0,
    this.isSelf = false,
    this.isBusy = false,
  });

  final OrgMember member;
  final ValueChanged<MemberStatus> onStatusToggle;
  final ValueChanged<OrgMember> onPasswordReset;

  /// Tope del `ResetPasswordSheet` — lo mide la pantalla sobre el hero.
  final double sheetTopInset;

  /// `true` cuando la card es del propio admin logueado (§52) — sin ⋮:
  /// suspenderse es SELF_SUSPENSION y resetearse revocaría la sesión
  /// propia.
  final bool isSelf;

  /// `true` mientras un PATCH de la fila está en vuelo (§52) — el ⋮
  /// cede al loader chico y queda inerte.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.quesivoWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.quesivoBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.quesivoShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserInitialAvatar(displayName: member.name, size: 46, fontSize: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quesivoDarkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.quesivoTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    MemberRoleChip(role: member.role),
                    MemberStatusChip(status: member.status),
                    if (member.isOwner) const _OwnerBadge(),
                  ],
                ),
              ],
            ),
          ),
          // Sin ⋮ donde no hay acción útil: el dueño no es suspendible
          // ni reseteable (OWNER_* en backend) y la card propia tampoco
          // (SELF_SUSPENSION garantizado; resetearse revocaría la
          // sesión propia — auto-logout confuso). Con un PATCH en
          // vuelo el ⋮ cede al loader chico de marca (§52).
          if (isBusy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: QuesivoLoader(
                size: 20,
                variant: QuesivoLoaderVariant.navy,
              ),
            )
          else if (!member.isOwner && !isSelf)
            MemberActionsMenu(
              member: member,
              onStatusToggle: onStatusToggle,
              onPasswordReset: onPasswordReset,
              sheetTopInset: sheetTopInset,
            ),
        ],
      ),
    );
  }
}

/// Pill "Dueño" (§49) — borde navy 1px + texto navy 11px w600, junto al
/// chip de estado en el Wrap de la card. Solo marca, sin interacción.
class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.quesivoNavy),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        l10n.ownerBadge,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.quesivoNavy,
        ),
      ),
    );
  }
}
