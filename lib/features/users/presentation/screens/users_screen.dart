import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../../../shell/presentation/widgets/shell_insets.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/users_failure.dart';
import '../cubit/users_list_cubit.dart';
import '../cubit/users_list_state.dart';
import '../widgets/link_user_sheet.dart';
import '../widgets/member_stats_row.dart';
import '../widgets/new_user_sheet.dart';
import '../widgets/org_member_card.dart';
import '../widgets/role_filter_chips.dart';
import '../widgets/users_empty_state.dart';
import '../widgets/users_list_error_state.dart';
import '../widgets/users_list_footer_loader.dart';
import '../widgets/users_search_field.dart';
import '../widgets/users_speed_dial.dart';

/// Pantalla principal del módulo Usuarios (`/home/usuarios` — hija del
/// branch Inicio). Desde §49 el listado es REAL: `UsersListCubit` pega a
/// `GET /auth/users` con paginación server-side (`page`/`limit` +
/// `search`/`role` en el query, doc 008 + backend 059) — murieron el
/// dataset sintético de 54 y el filtrado/chunking local. Las acciones
/// de fila siguen mutando el estado del cubit localmente (el PATCH real
/// llega con una propuesta posterior); el speed dial de §48 abre `NewUserSheet` /
/// `LinkUserSheet` y el miembro devuelto se inserta al tope como
/// reflejo optimista (el orden real es `created_at ASC` — tras un
/// refresh aparece al final).
///
/// Rediseño §38: cabecera navy del módulo. §39: hero edge-to-edge
/// detrás del ShellHeader. §41/§42: hero mínimo sin back/subtítulo.
/// Las acciones de alta viven en el `UsersSpeedDial` amarillo que flota
/// sobre el nav (pedido del usuario — el hero queda solo con
/// título + stats).
///
/// §49: la búsqueda pasa por debounce de 350ms antes de
/// `cubit.setQuery` (no pega un GET por tecla), el scroll dispara
/// `loadMore()` al acercarse al fondo y `RefreshIndicator` relanza la
/// página 1 con los filtros activos.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UsersListCubit>(
      // El cubit es factory (efímero como los del módulo) — nace con la
      // pantalla y dispara la primera página de inmediato.
      create: (_) => locator<UsersListCubit>()..load(),
      child: const _UsersView(),
    );
  }
}

class _UsersView extends StatefulWidget {
  const _UsersView();

  @override
  State<_UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<_UsersView> {
  static const _loadMoreThreshold = 200.0;
  static const _searchDebounce = Duration(milliseconds: 350);

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  // Mide el hero navy en vivo: el sheet de creación topea su alto en el
  // borde inferior de la tarjeta azul (sigue visible detrás del scrim).
  final _heroKey = GlobalKey();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Scroll paginado real: al acercarse al fondo pide la página
  /// siguiente — el guard anti doble-call (`hasMore && !isLoadingMore`)
  /// vive en el cubit, acá solo se dispara el intento.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      context.read<UsersListCubit>().loadMore();
    }
  }

  /// Debounce 350ms sobre el buscador — `search` viaja en el query del
  /// GET (backend 059), sin él cada tecla sería un request.
  void _onQueryChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      context.read<UsersListCubit>().setQuery(value);
    });
  }

  void _onRoleChanged(UserRole? role) =>
      context.read<UsersListCubit>().setRole(role);

  /// Borde inferior del hero navy medido en vivo — tope de los sheets
  /// modales (creación §44, reset §45) con el teclado abierto.
  double get _sheetTopInset {
    final heroContext = _heroKey.currentContext;
    if (heroContext == null) return 0;
    final box = heroContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;
    // El hero arranca en y=0 del body → su alto ES la coordenada del
    // borde inferior. `size` solo necesita el layout propio del hero;
    // `localToGlobal` recorre ancestors y crashea cuando el itemBuilder
    // del ListView lo lee durante el layout de la sliver.
    return box.size.height;
  }

  /// §44/§46 — abre el sheet de creación, que pega a `POST /auth/users`
  /// real vía `CreateUserCubit`; al volver con el miembro del backend lo
  /// inserta al tope del listado (reflejo optimista — el orden real es
  /// `created_at ASC`) y muestra feedback.
  ///
  /// Desde §48 el endpoint solo crea (backend 058): un email existente
  /// ya no vincula — sale `EMAIL_ALREADY_EXISTS` → error en el sheet —
  /// así que la rama `linked` quedó muerta y el toast es success siempre
  /// (`OrgMember.linked` se conserva: `linkUser` sí lo trae en true).
  Future<void> _openNewUserSheet() async {
    // El hero arranca en y=0 de la pantalla → su alto ES la coordenada del
    // borde inferior de la tarjeta navy; el sheet no crece más arriba de
    // ahí ni siquiera cuando el teclado lo empuja (scrollea dentro).
    final created = await NewUserSheet.show(context, topInset: _sheetTopInset);
    if (created == null || !mounted) return;
    context.read<UsersListCubit>().prependMember(created);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    // Toast flotante arriba — único mensaje; dentro del sheet solo
    // quedó el check del botón.
    QuesivoToast.success(
      context,
      message: AppLocalizations.of(context)!.memberCreatedFeedback,
    );
  }

  /// §48 — abre el sheet de vinculación (`POST /auth/users/link` vía
  /// `LinkUserCubit`): al volver con el `OrgMember` (`linked:true`) lo
  /// inserta al tope + scroll + toast info con `memberLinkedFeedback` —
  /// semántica informativa: no se creó cuenta, solo la membresía.
  Future<void> _openLinkUserSheet() async {
    final linked = await LinkUserSheet.show(context, topInset: _sheetTopInset);
    if (linked == null || !mounted) return;
    context.read<UsersListCubit>().prependMember(linked);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    QuesivoToast.info(
      context,
      message: AppLocalizations.of(context)!.memberLinkedFeedback(linked.name),
    );
  }

  /// §45 — flip de estado local tras confirmar el diálogo: reemplaza el
  /// miembro en el cubit. Una propuesta posterior lo conecta al
  /// `PATCH /auth/users/:id/status` real + merge del ítem devuelto.
  void _setMemberStatus(OrgMember member, MemberStatus status) {
    context.read<UsersListCubit>().updateMember(
      member.copyWith(status: status),
    );
    final l10n = AppLocalizations.of(context)!;
    // Suspendida deja un estado restrictivo → warning ámbar;
    // reactivada es éxito → verde.
    if (status == MemberStatus.suspended) {
      QuesivoToast.warning(context, message: l10n.memberSuspendedFeedback);
    } else {
      QuesivoToast.success(context, message: l10n.memberReactivatedFeedback);
    }
  }

  /// §45 — feedback del reset. Una propuesta posterior manda el password
  /// a `PATCH /auth/users/:id/password` (que además levanta el lockout).
  void _resetMemberPassword(OrgMember member, String password) {
    final l10n = AppLocalizations.of(context)!;
    QuesivoToast.success(
      context,
      message: l10n.passwordResetFeedback(member.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.quesivoSurface,
      // Mismo criterio que MainLayout: si el body encoge con el teclado,
      // el FAB (Positioned bottom) sube flotando sobre él separado del nav.
      // El buscador queda arriba y visible de todos modos; la lista sigue
      // scrolleable detrás del teclado.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cabecera navy del módulo (elemento firma §38) ──
              Container(
                key: _heroKey,
                decoration: const BoxDecoration(
                  color: AppColors.quesivoNavy,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: context.shellHeaderHeight),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.orgUsersItem,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.quesivoWhite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Stats del GET real: "N miembros" =
                          // meta.total (filtrado) — no lo cargado (§49).
                          BlocBuilder<UsersListCubit, UsersListState>(
                            buildWhen: (p, c) =>
                                p.total != c.total || p.members != c.members,
                            builder: (context, state) => MemberStatsRow(
                              members: state.members,
                              total: state.total,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Búsqueda + filtros (§43 — server-side desde §49) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UsersSearchField(
                      controller: _searchController,
                      onChanged: _onQueryChanged,
                    ),
                    const SizedBox(height: 12),
                    BlocBuilder<UsersListCubit, UsersListState>(
                      buildWhen: (p, c) => p.roleFilter != c.roleFilter,
                      builder: (context, state) => RoleFilterChips(
                        selected: state.roleFilter,
                        onChanged: _onRoleChanged,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Listado sobre surface — estados del GET real ──
              Expanded(
                child: BlocConsumer<UsersListCubit, UsersListState>(
                  // §51: error CON lista cargada → toast (la pantalla de
                  // error se reserva para cuando no hay nada que mostrar).
                  // Solo en la transición a error — un rebuild con el
                  // error ya presente no repite el toast.
                  listenWhen: (p, c) =>
                      c.status == UsersListStatus.error &&
                      c.errorNonce != p.errorNonce &&
                      c.members.isNotEmpty,
                  listener: (context, state) => QuesivoToast.error(
                    context,
                    // 429 dice la verdad (esperá y reintentá), no el
                    // genérico de conexión.
                    message: state.failure is UsersRateLimitFailure
                        ? l10n.tooManyAttemptsError
                        : l10n.usersLoadError,
                  ),
                  builder: (context, state) => _buildBody(context, state),
                ),
              ),
            ],
          ),
          // ── Speed dial (§48): círculo amarillo que flota sobre el
          // nav navy — expande "Crear usuario" y "Vincular existente"
          // (backend 058 separó crear de vincular). Misma posición que
          // el FAB que reemplaza; el scrim lo maneja el propio widget.
          Positioned(
            right: 24,
            bottom: context.shellNavBarHeight + 16,
            child: UsersSpeedDial(
              onCreate: _openNewUserSheet,
              onLink: _openLinkUserSheet,
            ),
          ),
        ],
      ),
    );
  }

  /// Cuerpo del listado según el estado del cubit: spinner de marca en
  /// la primera carga, error + retry si el GET falló, empty state
  /// (org vacía o "Sin resultados" con filtro) o la lista real con
  /// pull-to-refresh y footer de página siguiente.
  Widget _buildBody(BuildContext context, UsersListState state) {
    final l10n = AppLocalizations.of(context)!;

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
        controller: _scrollController,
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
            onStatusToggle: (s) => _setMemberStatus(member, s),
            onPasswordReset: (pw) => _resetMemberPassword(member, pw),
            sheetTopInset: _sheetTopInset,
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
