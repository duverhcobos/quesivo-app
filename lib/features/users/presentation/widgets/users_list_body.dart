import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../shell/presentation/widgets/shell_insets.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/users_failure.dart';
import '../cubit/users_list_cubit.dart';
import '../cubit/users_list_state.dart';
import 'org_member_card.dart';
import 'users_empty_state.dart';
import 'users_list_error_state.dart';
import 'users_list_footer_loader.dart';

/// Cuerpo del listado del `UsersScreen` — extraído en §52 por la regla
/// de tamaño de archivo (la screen quedó como composición: shell +
/// BlocConsumer + listener del toast). Resuelve el switch de estados
/// del cubit, el pull-to-refresh, la atenuación del refetch con lista
/// previa (§51) y la lista de cards.
///
/// Las acciones de fila suben por `onStatusToggle`/`onPasswordReset`
/// (la screen decide el toast y dispara los PATCH de §52); el retry y
/// el refresh llaman al cubit directo — son callbacks, no viajan por
/// params.
class UsersListBody extends StatelessWidget {
  const UsersListBody({
    super.key,
    required this.state,
    required this.scrollController,
    required this.sheetTopInset,
    required this.onStatusToggle,
    required this.onPasswordReset,
    required this.onRoleChange,
  });

  final UsersListState state;
  final ScrollController scrollController;

  /// Tope de los sheets modales — lo mide la screen sobre el hero navy.
  final double sheetTopInset;

  /// El admin confirmó el diálogo de estado — la screen dispara
  /// `PATCH /auth/users/:id/status` (§52).
  final void Function(OrgMember member, MemberStatus status) onStatusToggle;

  /// El `ResetPasswordSheet` completó el PATCH y devolvió el miembro
  /// del 200 — la screen solo muestra el toast de éxito.
  final ValueChanged<OrgMember> onPasswordReset;

  /// El admin confirmó el `ChangeRoleDialog` — la screen dispara
  /// `PATCH /auth/users/:id/role` (§54).
  final void Function(OrgMember member, UserRole role) onRoleChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // §52 — el ⋮ tampoco se ofrece en la card propia: suspenderse es
    // SELF_SUSPENSION garantizado y resetearse revocaría la sesión
    // propia (auto-logout confuso). Null cuando no hay sesión cargada.
    final selfId = context.select<AuthCubit, String?>(
      (c) => c.state is AuthSuccess ? (c.state as AuthSuccess).user.id : null,
    );

    switch (state.status) {
      case UsersListStatus.initial:
      case UsersListStatus.loading:
        // Sin lista previa → loader de marca centrado; con lista, cae
        // al render de abajo que la muestra ATENUADA bajo el loader
        // (§51 — feedback visible del refetch por búsqueda/filtro).
        if (state.members.isEmpty) {
          // Primera carga — el momento grande del loader de marca.
          return Center(
            child: QuesivoLoader(size: 40, semanticLabel: l10n.loadingLabel),
          );
        }
      case UsersListStatus.error:
        // §51: la pantalla de error solo cuando no hay NADA que mostrar;
        // con filas cargadas la lista se conserva y el listener ya
        // disparó el toast de error (reintento = pull-to-refresh o
        // reescribir la búsqueda).
        if (state.members.isEmpty) {
          return UsersListErrorState(
            onRetry: () => context.read<UsersListCubit>().load(),
            // 429 sin datos: misma distinción que el toast — el genérico
            // "revisá tu conexión" mentiría sobre la causa.
            message: state.failure is UsersRateLimitFailure
                ? l10n.tooManyAttemptsError
                : null,
          );
        }
      case UsersListStatus.loaded:
        break;
    }

    if (state.members.isEmpty) {
      final isFiltering = state.query.isNotEmpty || state.roleFilter != null;
      return isFiltering
          ? UsersEmptyState(
              icon: Icons.search_off,
              title: l10n.noSearchResultsTitle,
              hint: l10n.noSearchResultsHint,
            )
          : const UsersEmptyState();
    }

    // Footer de página siguiente: visible mientras queden páginas por
    // pedir (hasMore) o el fetch de la N+1 esté en vuelo — desaparece
    // al llegar a la última página.
    final showFooter = state.hasMore || state.isLoadingMore;

    final list = RefreshIndicator(
      color: AppColors.quesivoNavy,
      backgroundColor: AppColors.quesivoWhite,
      onRefresh: () => context.read<UsersListCubit>().refresh(),
      // Padding en el ListView (no en un wrapper): las cards
      // pueden scrollear bajo el nav navy y el último ítem sube
      // por encima — inset = shellNavBarHeight (§39) + alto del
      // FAB (56) + su margen (16) para que el ⋮ de la última
      // card nunca quede tapado al llegar al fondo.
      child: ListView.separated(
        controller: scrollController,
        // AlwaysScrollable: el pull-to-refresh tiene que poder
        // gatillarse aunque la página no llene el viewport.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, 0, 24, context.shellNavBarHeight + 72),
        itemCount: state.members.length + (showFooter ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= state.members.length) {
            return const UsersListFooterLoader();
          }
          final member = state.members[index];
          return OrgMemberCard(
            member: member,
            isSelf: member.id == selfId,
            isBusy: state.busyMemberIds.contains(member.id),
            onStatusToggle: (s) => onStatusToggle(member, s),
            onPasswordReset: onPasswordReset,
            onRoleChange: (r) => onRoleChange(member, r),
            sheetTopInset: sheetTopInset,
          );
        },
      ),
    );

    // §51 — refetch con lista previa (búsqueda/filtro): la lista queda
    // atenuada y sin gestos bajo el loader de marca — se ve que está
    // trabajando y la data vieja no se lee como fresca. El pull-to-
    // refresh queda bloqueado mientras vuela el refetch (ya hay carga).
    if (state.status == UsersListStatus.loading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // ExcludeSemantics: la lista atenuada tampoco es navegable por
          // TalkBack durante el refetch (§51 review — el IgnorePointer
          // solo bloquea gestos, no el árbol de semantics).
          ExcludeSemantics(
            child: IgnorePointer(child: Opacity(opacity: 0.45, child: list)),
          ),
          Center(
            child: QuesivoLoader(size: 28, semanticLabel: l10n.loadingLabel),
          ),
        ],
      );
    }
    return list;
  }
}
