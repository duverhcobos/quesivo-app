import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../auth/domain/entities/org_invite.dart';
import 'role_label_for.dart';

/// Card de una invitación pendiente a una quesera (backend 072) — la
/// capa personal la lista en `OrgInvitesSection`. Lenguaje de la card
/// "Entrar" (crema + chip de rol navy + borde amarillo suave) pero con
/// acciones explícitas en vez de tap-en-toda-la-card: "Aceptar" (pill
/// amarillo navy) y "Rechazar" (texto secundario — negativa no
/// destructiva, sin rojo: no es suspender, es "no gracias").
/// `responding` muestra loader y bloquea ambos botones; `enabled` cae
/// a false mientras OTRA invitación responde (una a la vez).
class OrgInviteCard extends StatelessWidget {
  const OrgInviteCard({
    super.key,
    required this.invite,
    required this.responding,
    required this.enabled,
    required this.onAccept,
    required this.onDecline,
  });

  final OrgInvite invite;

  /// Esta card está resolviendo accept/decline.
  final bool responding;

  /// false mientras cualquier card está respondiendo.
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.quesivoCream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.quesivoYellow.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.orgInviteCardTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.quesivoTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invite.organizationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.quesivoNavy,
                      ),
                    ),
                  ],
                ),
              ),
              // Mismo chip de rol navy+punto-amarillo de la card Entrar.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.quesivoNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.quesivoYellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.roleLabelFor(invite.role),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.quesivoWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (responding)
            const Center(child: QuesivoLoader(size: 22))
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: enabled ? onDecline : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.quesivoIconSurface,
                      foregroundColor: AppColors.quesivoNavy,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.orgInviteDeclineCta, maxLines: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: enabled ? onAccept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.quesivoYellow,
                      foregroundColor: AppColors.quesivoNavy,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.orgInviteAcceptCta, maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
