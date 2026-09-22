import 'dart:async';

// `hide State`: dartz exporta su propia mónada State<S, A> que choca con
// el State<T> de Flutter — primer archivo del módulo que combina
// StatefulWidget con Either/Left/Right (§52).
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
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
import '../widgets/role_filter_chips.dart';
import '../widgets/users_list_body.dart';
import '../widgets/users_search_field.dart';
import '../widgets/users_speed_dial.dart';

/// Pantalla principal del módulo Usuarios (`/home/usuarios` — hija del
/// branch Inicio). Desde §49 el listado es REAL: `UsersListCubit` pega a
/// `GET /auth/users` con paginación server-side (`page`/`limit` +
/// `search`/`role` en el query, doc 008 + backend 059) — murieron el
/// dataset sintético de 54 y el filtrado/chunking local. Las acciones
/// de fila son reales desde §52 (PATCH status/password) y el speed
/// dial de §48 abre `NewUserSheet` / `LinkUserSheet` y el miembro
/// devuelto se inserta al tope como reflejo optimista (el orden real
/// es `created_at ASC` — tras un refresh aparece al final).
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

  /// §52 — flip REAL vía `PATCH /auth/users/:id/status`: el cubit pone
  /// la card en busy y devuelve el Either — éxito mergea el miembro
  /// fresco del backend; error → toast con el mensaje de la regla
  /// (SELF_SUSPENSION/LAST_ADMIN/OWNER_* — doc 009).
  Future<void> _setMemberStatus(OrgMember member, MemberStatus status) async {
    final result = await context.read<UsersListCubit>().setMemberStatus(
      member,
      status,
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (result) {
      case Left(value: final failure):
        QuesivoToast.error(
          context,
          message: _memberActionErrorText(l10n, failure),
        );
      case Right():
        // Suspendida deja un estado restrictivo → warning ámbar;
        // reactivada es éxito → verde (mismo criterio de §45).
        if (status == MemberStatus.suspended) {
          QuesivoToast.warning(context, message: l10n.memberSuspendedFeedback);
        } else {
          QuesivoToast.success(
            context,
            message: l10n.memberReactivatedFeedback,
          );
        }
    }
  }

  /// §54 — cambio de rol REAL vía `PATCH /auth/users/:id/role`: el cubit
  /// pone la card en busy y devuelve el Either — éxito mergea el miembro
  /// fresco; error → toast con el mensaje de la regla (doc 012). El
  /// miembro queda deslogueado de la org (el backend revoca sus
  /// sesiones) — re-ingresa con el rol nuevo.
  Future<void> _setMemberRole(OrgMember member, UserRole role) async {
    final result = await context.read<UsersListCubit>().setMemberRole(
      member,
      role,
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (result) {
      case Left(value: final failure):
        QuesivoToast.error(
          context,
          message: _memberActionErrorText(l10n, failure),
        );
      case Right():
        QuesivoToast.success(
          context,
          message: l10n.memberRoleChangedFeedback(member.name),
        );
    }
  }

  /// Traducción de los failures de los PATCH de fila (status doc 009,
  /// role doc 012) — los de regla propia/dueño son defensivos (la UI ya
  /// no ofrece el ⋮ al dueño ni a la card propia, y LAST_ADMIN solo se
  /// da con datos stale).
  String _memberActionErrorText(AppLocalizations l10n, UsersFailure f) =>
      switch (f) {
        SelfSuspensionFailure() => l10n.selfSuspensionError,
        OwnerSuspensionFailure() => l10n.ownerSuspensionError,
        SelfRoleChangeFailure() => l10n.selfRoleChangeError,
        OwnerRoleChangeFailure() => l10n.ownerRoleChangeError,
        LastAdminFailure() => l10n.lastAdminError,
        MemberNotFoundFailure() => l10n.memberNotFoundError,
        UsersForbiddenFailure() => l10n.usersForbiddenError,
        UsersRateLimitFailure() => l10n.tooManyAttemptsError,
        UsersNetworkFailure() => l10n.networkError,
        _ => l10n.genericError,
      };

  /// §52 — el `ResetPasswordSheet` ya pegó `PATCH /auth/users/:id/password`
  /// con su cubit (el miembro devuelto no cambia a la vista); acá solo
  /// queda el toast — el temporal se comparte a mano (doc 010).
  void _resetMemberPassword(OrgMember member) {
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
                  builder: (context, state) => UsersListBody(
                    state: state,
                    scrollController: _scrollController,
                    sheetTopInset: _sheetTopInset,
                    onStatusToggle: _setMemberStatus,
                    onPasswordReset: _resetMemberPassword,
                    onRoleChange: _setMemberRole,
                  ),
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
}
