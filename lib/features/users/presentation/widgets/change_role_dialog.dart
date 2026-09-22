import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import 'role_selector_chips.dart';

/// Diálogo "Cambiar rol" (§54, doc 012) — `RoleSelectorChips`
/// preseleccionado al rol actual del miembro. Devuelve el `UserRole`
/// nuevo si se confirmó o `null` al cancelar. Confirmar deshabilitado
/// mientras la selección no cambie: un no-op no justifica PATCH ni
/// toast (el backend también es idempotente, pero la UI ni llega).
///
/// El mensaje advierte la semántica real del backend: al cambiar el rol
/// se revocan las sesiones del miembro en la org — el nuevo rol aplica
/// cuando vuelva a ingresar.
class ChangeRoleDialog extends StatefulWidget {
  const ChangeRoleDialog({super.key, required this.member});

  final OrgMember member;

  static Future<UserRole?> show(BuildContext context, OrgMember member) {
    return showDialog<UserRole?>(
      context: context,
      builder: (_) => ChangeRoleDialog(member: member),
    );
  }

  @override
  State<ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<ChangeRoleDialog> {
  late UserRole _selected = widget.member.role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final changed = _selected != widget.member.role;

    return AlertDialog(
      backgroundColor: AppColors.quesivoWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.quesivoNavy.withValues(alpha: 0.10),
        child: const Icon(
          Icons.manage_accounts_outlined,
          color: AppColors.quesivoNavy,
          size: 24,
        ),
      ),
      title: Text(
        l10n.changeRoleTitle(widget.member.name),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.quesivoNavy,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.changeRoleMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          RoleSelectorChips(
            selected: _selected,
            onChanged: (role) => setState(() => _selected = role),
          ),
        ],
      ),
      // Botones hug-content centrados — mismo patrón que
      // MemberStatusDialog: lado a lado si entran, apilados si el
      // diálogo es muy angosto.
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
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
          onPressed: changed
              ? () => Navigator.of(context).pop(_selected)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.quesivoNavy,
            foregroundColor: AppColors.quesivoWhite,
            disabledBackgroundColor: AppColors.quesivoIconSurface,
            disabledForegroundColor: AppColors.quesivoTextSecondary,
            elevation: 0,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(l10n.changeRoleConfirm, maxLines: 1),
        ),
      ],
    );
  }
}
