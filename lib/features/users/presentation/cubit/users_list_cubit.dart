import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/users_failure.dart';
import '../../domain/use_cases/list_users_use_case.dart';
import '../../domain/use_cases/update_user_role_use_case.dart';
import '../../domain/use_cases/update_user_status_use_case.dart';
import 'users_list_state.dart';

/// Cubit del `UsersScreen` — orquesta el listado real contra
/// `GET /auth/users` (propuesta §49): paginación server-side con
/// `search`/`role` en el query (backend 059). RegisterFactory: nace y
/// muere con la pantalla, como los cubits de los sheets.
///
/// Modelo de estado: `load()` resetea a página 1 con el
/// `query`/`roleFilter` actuales; `loadMore()` apila `page+1` cuando
/// `hasMore`; `prependMember` inserta al tope tras create/link y
/// `setMemberStatus` pega al PATCH real (§52) y mergea el ítem del
/// response.
class UsersListCubit extends Cubit<UsersListState> {
  /// Tamaño de página del listado — mismo chunk que usaba la paginación
  /// local de §43; dentro del `Max(100)` del backend (doc 008).
  static const _pageSize = 15;

  final ListUsersUseCase _listUsers;
  final UpdateUserStatusUseCase _updateUserStatus;
  final UpdateUserRoleUseCase _updateUserRole;

  /// Generación de la carga inicial: cada `load()` la incrementa y una
  /// respuesta que vuelve con un token viejo se descarta — es el guard
  /// anti doble-call (una `load()` nueva por búsqueda/filtro/refresh
  /// invalida la anterior en vuelo en vez de dejar que pise el estado
  /// con resultados del query anterior). Reemplaza al `_loadToken` que
  /// vivía en la screen.
  int _loadToken = 0;

  UsersListCubit(this._listUsers, this._updateUserStatus, this._updateUserRole)
    : super(const UsersListState());

  String? get _search => state.query.isEmpty ? null : state.query;

  /// Carga la página 1 con los filtros activos — entry point del init,
  /// del retry y de cada cambio de búsqueda/rol. Conserva `members`
  /// mientras carga: la screen los muestra atenuados bajo el loader
  /// (§51) en vez de flashear a spinner vacío.
  Future<void> load() => _fetchPage1(showLoading: true);

  /// Pull-to-refresh — misma página 1 con el query/filtro actuales, pero
  /// SIN emitir `loading` (§51): el `RefreshIndicator` ya ES el
  /// indicador visual; marcar `loading` encima metería el loader
  /// centrado + la atenuación — doble feedback.
  Future<void> refresh() => _fetchPage1(showLoading: false);

  Future<void> _fetchPage1({required bool showLoading}) async {
    final token = ++_loadToken;
    emit(
      state.copyWith(
        status: showLoading ? UsersListStatus.loading : state.status,
        isLoadingMore: false,
        failure: null,
      ),
    );
    final result = await _listUsers(
      page: 1,
      limit: _pageSize,
      search: _search,
      role: state.roleFilter,
    );
    // `isClosed`: la pantalla pudo desmontarse con el GET en vuelo —
    // emitir lanzaría StateError. `token != _loadToken`: una load()
    // posterior ya reemplazó el contexto — este resultado es stale.
    if (isClosed || token != _loadToken) return;
    result.fold(
      // El error es de la carga inicial/refresh: los miembros quedan en
      // state (una recarga exitosa los reemplaza; si era refresh el
      // listado previo no se pierde del estado).
      (failure) => emit(
        state.copyWith(
          status: UsersListStatus.error,
          failure: failure,
          // §51 review: el nonce hace que cada intento fallido emita un
          // estado distinto — sin él, Equatable deduplica un segundo
          // error idéntico y el reintento queda sin feedback (el toast
          // lo dispara el listener con el nonce como trigger). Y
          // hasMore:false apaga el footer loader — el hasMore viejo era
          // del query anterior y loadMore() es no-op bajo error.
          errorNonce: state.errorNonce + 1,
          hasMore: false,
        ),
      ),
      (page) => emit(
        state.copyWith(
          status: UsersListStatus.loaded,
          members: page.items,
          total: page.total,
          page: page.page,
          hasMore: page.hasMore,
          failure: null,
        ),
      ),
    );
  }

  /// Fetch de `page+1` al acercarse al fondo — `hasMore &&
  /// !isLoadingMore` es el guard anti doble-call (el footer spinner ya
  /// delata la carga en vuelo). Append con dedup por `id` defensivo: si
  /// el backend solapara una fila entre páginas no se duplica la card.
  Future<void> loadMore() async {
    if (state.status != UsersListStatus.loaded) return;
    if (!state.hasMore || state.isLoadingMore) return;
    final token = _loadToken;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _listUsers(
      page: state.page + 1,
      limit: _pageSize,
      search: _search,
      role: state.roleFilter,
    );
    if (isClosed || token != _loadToken) return;
    result.fold(
      // Página N+1 falla en silencio: se apaga el spinner y el próximo
      // scroll al borde reintenta — sin error full-screen ni toast.
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (next) {
        final seen = state.members.map((m) => m.id).toSet();
        emit(
          state.copyWith(
            members: [
              ...state.members,
              ...next.items.where((m) => !seen.contains(m.id)),
            ],
            total: next.total,
            page: next.page,
            hasMore: next.hasMore,
            isLoadingMore: false,
          ),
        );
      },
    );
  }

  /// La screen lo llama con debounce ~350ms — guarda el query
  /// (trimmeado, `''` = sin búsqueda) y relanza `load()` a página 1.
  /// Mismo query efectivo → no-op (evita refetch redundante).
  void setQuery(String query) {
    final normalized = query.trim();
    if (normalized == state.query) return;
    emit(state.copyWith(query: normalized));
    load();
  }

  /// Chip de rol — guarda y relanza `load()` a página 1 (`null` =
  /// "Todos"). Mismo rol → no-op.
  void setRole(UserRole? role) {
    if (role == state.roleFilter) return;
    emit(state.copyWith(roleFilter: role));
    load();
  }

  /// Insert optimista tras crear/vincular (transitorio: el orden real
  /// es `created_at ASC` — tras un refresh el nuevo aparece al final).
  /// Dedup por `id` defensivo; `total + 1` solo si el id no estaba ya
  /// listado — el miembro nuevo sí suma a la org (meta.total crecería
  /// igual en el próximo fetch), un reorder de uno existente no.
  void prependMember(OrgMember member) {
    if (isClosed) return;
    final alreadyListed = state.members.any((m) => m.id == member.id);
    emit(
      state.copyWith(
        members: [member, ...state.members.where((m) => m.id != member.id)],
        total: alreadyListed ? state.total : state.total + 1,
      ),
    );
  }

  /// Reemplaza por `id` — merge del ítem fresco que devuelve el PATCH
  /// de status (§52) en el dataset del listado.
  void updateMember(OrgMember member) {
    if (isClosed) return;
    final index = state.members.indexWhere((m) => m.id == member.id);
    if (index == -1) return;
    final updated = [...state.members];
    updated[index] = member;
    emit(state.copyWith(members: updated));
  }

  /// `PATCH /auth/users/:id/status` real (§52, doc 009): marca la card
  /// busy mientras vuela y devuelve el `Either` crudo — la screen lo
  /// traduce a toast (warning al suspender, success al reactivar,
  /// error mapeado al fallar). En éxito mergea el `OrgMember` fresco
  /// del response (mismo shape que el ítem del listado — nada de flip
  /// local optimista). Defensivo: una segunda acción sobre la misma
  /// card con el PATCH en vuelo es no-op (el ⋮ ya está inerte).
  Future<Either<UsersFailure, OrgMember>> setMemberStatus(
    OrgMember member,
    MemberStatus status,
  ) async {
    if (state.busyMemberIds.contains(member.id)) {
      // Inalcanzable por UI (el ⋮ cede al loader mientras está busy) —
      // defensivo: el miembro no cambió, devolverlo es honesto (nada
      // pasó) y la screen no muestra toast de error engañoso.
      return Right(member);
    }
    emit(state.copyWith(busyMemberIds: {...state.busyMemberIds, member.id}));
    final result = await _updateUserStatus(userId: member.id, status: status);
    // La pantalla pudo cerrarse con el PATCH en vuelo — el cambio ya
    // quedó aplicado en el servidor; el próximo load() lo refleja.
    if (isClosed) return result;
    emit(
      state.copyWith(
        busyMemberIds: {...state.busyMemberIds}..remove(member.id),
      ),
    );
    switch (result) {
      case Right(value: final fresh):
        updateMember(fresh);
      case Left():
        break;
    }
    return result;
  }

  /// `PATCH /auth/users/:id/role` real (§54, doc 012): mismo contrato
  /// que `setMemberStatus` — busy mientras vuela, Either crudo a la
  /// screen, merge del `OrgMember` fresco en éxito, no-op defensivo si
  /// la card ya está busy. El backend revoca las sesiones del miembro
  /// en la org (el JWT lleva `roles` — re-ingresa con el rol nuevo).
  Future<Either<UsersFailure, OrgMember>> setMemberRole(
    OrgMember member,
    UserRole role,
  ) async {
    if (state.busyMemberIds.contains(member.id)) {
      // Inalcanzable por UI (el ⋮ cede al loader) — ver setMemberStatus.
      return Right(member);
    }
    emit(state.copyWith(busyMemberIds: {...state.busyMemberIds, member.id}));
    final result = await _updateUserRole(userId: member.id, role: role);
    if (isClosed) return result;
    emit(
      state.copyWith(
        busyMemberIds: {...state.busyMemberIds}..remove(member.id),
      ),
    );
    switch (result) {
      case Right(value: final fresh):
        updateMember(fresh);
      case Left():
        break;
    }
    return result;
  }
}
