import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../shell/presentation/widgets/shell_insets.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../widgets/member_stats_row.dart';
import '../widgets/new_user_sheet.dart';
import '../widgets/org_member_card.dart';
import '../widgets/role_filter_chips.dart';
import '../widgets/users_empty_state.dart';
import '../widgets/users_list_footer_loader.dart';
import '../widgets/users_search_field.dart';
import 'sample_org_members.dart';

/// Pantalla principal del módulo Usuarios (`/home/usuarios` — hija del
/// branch Inicio). Solo UI: el listado se pinta con
/// `generateSampleOrgMembers()` hasta la propuesta que integre
/// `GET /auth/users`; las acciones de fila mutan el dataset local (§45
/// — solo UI, el PATCH llega con la integración); el FAB de creación
/// abre `NewUserSheet` (§44).
///
/// Rediseño §38: cabecera navy del módulo. §39: hero edge-to-edge
/// detrás del ShellHeader. §41/§42: hero mínimo sin back/subtítulo.
/// La acción de creación vive en el FAB circular amarillo que flota
/// sobre el nav (pedido del usuario — el hero queda solo con
/// título + stats).
///
/// §43: `StatefulWidget` — búsqueda + filtro por rol (locales sobre el
/// dataset de 54 muestras, `GET /auth/users` hoy no soporta query
/// params de texto/rol) y **scroll paginado**: se muestran de a
/// `_pageSize` filas y se cargan más al acercarse al final de la lista
/// (`Future.delayed` simula la latencia real; se reemplaza por
/// `GET /auth/users?page=` al integrar el endpoint). Sigue sin
/// Cubit/repositorio — todo el estado es de presentación pura.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _pageSize = 15;
  static const _loadMoreThreshold = 200.0;

  final _allMembers = generateSampleOrgMembers();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  // Mide el hero navy en vivo: el sheet de creación topea su alto en el
  // borde inferior de la tarjeta azul (sigue visible detrás del scrim).
  final _heroKey = GlobalKey();

  UserRole? _roleFilter;
  String _query = '';
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  // Ignora una carga en vuelo si búsqueda/filtro cambiaron mientras
  // esperaba — evita que un Future viejo pise el estado del filtro nuevo.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<OrgMember> get _filteredMembers => _allMembers.where((m) {
    final matchesRole = _roleFilter == null || m.role == _roleFilter;
    final q = _query.trim().toLowerCase();
    final matchesQuery =
        q.isEmpty ||
        m.name.toLowerCase().contains(q) ||
        m.email.toLowerCase().contains(q);
    return matchesRole && matchesQuery;
  }).toList();

  bool _hasMore(List<OrgMember> filtered) => _visibleCount < filtered.length;

  void _onScroll() {
    if (_isLoadingMore) return;
    if (!_hasMore(_filteredMembers)) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final token = ++_loadToken;
    setState(() => _isLoadingMore = true);
    // Simula la latencia de red — reemplazar por
    // `GET /auth/users?page=` al integrar el endpoint.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || token != _loadToken) return;
    setState(() {
      _visibleCount = min(_visibleCount + _pageSize, _filteredMembers.length);
      _isLoadingMore = false;
    });
  }

  void _resetPagination() {
    _loadToken++;
    setState(() {
      _visibleCount = _pageSize;
      _isLoadingMore = false;
    });
  }

  void _onQueryChanged(String value) {
    _query = value;
    _resetPagination();
  }

  void _onRoleChanged(UserRole? role) {
    _roleFilter = role;
    _resetPagination();
  }

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

  /// §44 — abre el sheet de creación; al volver con un miembro lo
  /// inserta al tope del dataset local (stats + listado se actualizan
  /// solos) y muestra feedback. La integración reemplaza el insert por
  /// `POST /auth/users` + refresh de la página.
  Future<void> _openNewUserSheet() async {
    // El hero arranca en y=0 de la pantalla → su alto ES la coordenada del
    // borde inferior de la tarjeta navy; el sheet no crece más arriba de
    // ahí ni siquiera cuando el teclado lo empuja (scrollea dentro).
    final created = await NewUserSheet.show(context, topInset: _sheetTopInset);
    if (created == null || !mounted) return;
    setState(() => _allMembers.insert(0, created));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.memberCreatedFeedback),
      ),
    );
  }

  /// §45 — flip de estado en el dataset local tras confirmar el
  /// diálogo. La integración lo reemplaza por
  /// `PATCH /auth/users/:id/status` + merge del ítem devuelto.
  void _setMemberStatus(OrgMember member, MemberStatus status) {
    final index = _allMembers.indexWhere((m) => m.id == member.id);
    if (index == -1) return;
    setState(() => _allMembers[index] = member.copyWith(status: status));
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == MemberStatus.suspended
              ? l10n.memberSuspendedFeedback
              : l10n.memberReactivatedFeedback,
        ),
      ),
    );
  }

  /// §45 — feedback del reset. La integración manda el password a
  /// `PATCH /auth/users/:id/password` (que además levanta el lockout).
  void _resetMemberPassword(OrgMember member, String password) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.passwordResetFeedback(member.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filteredMembers;
    final visible = filtered.take(_visibleCount).toList();
    final isFiltering = _query.trim().isNotEmpty || _roleFilter != null;

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
                          // Stats siempre sobre el total de la org — no sobre
                          // lo filtrado/visible (§43).
                          MemberStatsRow(members: _allMembers),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Búsqueda + filtros (§43) ──
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
                    RoleFilterChips(
                      selected: _roleFilter,
                      onChanged: _onRoleChanged,
                    ),
                  ],
                ),
              ),
              // ── Listado sobre surface ──
              Expanded(
                child: visible.isEmpty
                    ? (isFiltering
                          ? UsersEmptyState(
                              icon: Icons.search_off,
                              title: l10n.noSearchResultsTitle,
                              hint: l10n.noSearchResultsHint,
                            )
                          : const UsersEmptyState())
                    // Padding en el ListView (no en un wrapper): las cards
                    // pueden scrollear bajo el nav navy y el último ítem sube
                    // por encima — inset = shellNavBarHeight (§39) + alto del
                    // FAB (56) + su margen (16) para que el ⋮ de la última
                    // card nunca quede tapado al llegar al fondo.
                    : ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          context.shellNavBarHeight + 72,
                        ),
                        itemCount: visible.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index >= visible.length) {
                            return const UsersListFooterLoader();
                          }
                          final member = visible[index];
                          return OrgMemberCard(
                            member: member,
                            onStatusToggle: (s) => _setMemberStatus(member, s),
                            onPasswordReset: (pw) =>
                                _resetMemberPassword(member, pw),
                            sheetTopInset: _sheetTopInset,
                          );
                        },
                      ),
              ),
            ],
          ),
          // ── FAB de creación: círculo amarillo que flota sobre el nav
          // navy — la acción primaria del listado vive al alcance del
          // pulgar aunque el hero quede lejos al scrollear (sale del
          // hero: pedido del usuario).
          Positioned(
            right: 24,
            bottom: context.shellNavBarHeight + 16,
            child: FloatingActionButton(
              onPressed: _openNewUserSheet,
              tooltip: l10n.newUserButton,
              backgroundColor: AppColors.quesivoYellow,
              foregroundColor: AppColors.quesivoNavy,
              shape: const CircleBorder(),
              child: const Icon(Icons.person_add_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
