import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_initials_avatar.dart';
import '../../domain/entities/org_member.dart';
import 'member_actions_menu.dart';
import 'member_role_chip.dart';
import 'member_status_chip.dart';

/// Card de un miembro de la organización en el listado de Usuarios:
/// avatar de iniciales + nombre + email + chips de rol/estado + menú de
/// acciones ⋮ que abre `MemberStatusDialog` / `ResetPasswordSheet` (§45).
class OrgMemberCard extends StatelessWidget {
  const OrgMemberCard({
    super.key,
    required this.member,
    required this.onStatusToggle,
    required this.onPasswordReset,
    this.sheetTopInset = 0,
  });

  final OrgMember member;
  final ValueChanged<MemberStatus> onStatusToggle;
  final ValueChanged<String> onPasswordReset;

  /// Tope del `ResetPasswordSheet` — lo mide la pantalla sobre el hero.
  final double sheetTopInset;

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
                  ],
                ),
              ],
            ),
          ),
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
