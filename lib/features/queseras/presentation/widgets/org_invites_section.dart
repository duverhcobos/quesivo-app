import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../../../auth/domain/entities/org_invite.dart';
import '../../../auth/domain/failures/auth_failure.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/org_invites_cubit.dart';
import '../cubit/org_invites_state.dart';
import 'org_invite_card.dart';

/// Sección "Invitaciones" de la capa personal (`/home` sin quesera
/// activa ni entrando): lista las `pendingInvites` del `User` como
/// `OrgInviteCard` con Aceptar/Rechazar (backend 072). Se auto-oculta
/// cuando la lista está vacía — el /home del admin sin invitaciones no
/// cambia en nada.
///
/// El cubit es factory y vive acá — nace y muere con la sección (mismo
/// criterio que `QueseraSelectionCubit` en el carousel). En éxito el
/// `AuthCubit` actualiza el `User` en el lugar → la card desaparece
/// (decline) o la org aparece como "Entrar" en el selector (accept);
/// en 404 la lista también se refresca — la invitación ya no existía.
class OrgInvitesSection extends StatelessWidget {
  const OrgInvitesSection({super.key});

  String _errorText(AppLocalizations l10n, OrgInvitesState state) {
    // Mapeo por tipo (mismo criterio que _memberActionErrorText de
    // users): el failure.message viene en español fijo del repo.
    return switch (state.failure) {
      OrgInviteNotFoundFailure() => l10n.orgInviteGoneError,
      TooManyAttemptsFailure() => l10n.tooManyAttemptsError,
      NetworkFailure() => l10n.networkError,
      _ => l10n.genericError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final invites = context.select<AuthCubit, List<OrgInvite>>(
      (c) => c.state is AuthSuccess
          ? (c.state as AuthSuccess).user.pendingInvites
          : const <OrgInvite>[],
    );
    if (invites.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => locator<OrgInvitesCubit>(),
      child: BlocConsumer<OrgInvitesCubit, OrgInvitesState>(
        listenWhen: (p, c) => c.failure != null,
        listener: (context, state) {
          QuesivoToast.error(context, message: _errorText(l10n, state));
        },
        builder: (context, state) {
          // Sin padding horizontal — el ListView de home_tab ya da el
          // margen lateral (7.5%): las cards alinean con saludo y carousel.
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.orgInvitesSectionTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quesivoNavy,
                  ),
                ),
                const SizedBox(height: 10),
                for (final invite in invites) ...[
                  OrgInviteCard(
                    invite: invite,
                    responding: state.respondingId == invite.id,
                    enabled: !state.isResponding,
                    onAccept: () async {
                      final cubit = context.read<OrgInvitesCubit>();
                      final ok = await cubit.accept(invite);
                      if (ok && context.mounted) {
                        QuesivoToast.success(
                          context,
                          message: l10n.orgInviteAcceptedFeedback(
                            invite.organizationName,
                          ),
                        );
                      }
                    },
                    onDecline: () =>
                        context.read<OrgInvitesCubit>().decline(invite),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
