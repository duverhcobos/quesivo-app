import 'package:equatable/equatable.dart';

import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/users_failure.dart';

/// Status del listado (propuesta §49): `initial`/`loading` → spinner de
/// marca; `error` → mensaje + retry; `loaded` → lista (o empty state).
enum UsersListStatus { initial, loading, loaded, error }

/// Estado del listado de usuarios — páginas acumuladas del
/// `GET /auth/users` real (paginación server-side, doc 008 + backend
/// 059: `search`/`role` viajan en el query y `meta.total` es el total
/// FILTRADO). A diferencia de los states de los sheets este sí lleva
/// `copyWith`: las transiciones del listado mutan pocos campos sobre un
/// estado grande (append de página, flip de `isLoadingMore`, etc.).
class UsersListState extends Equatable {
  final UsersListStatus status;

  /// Páginas acumuladas en orden de llegada (created_at ASC del
  /// backend + `prependMember` optimista al tope tras crear/vincular).
  final List<OrgMember> members;

  /// `meta.total` del último response — con filtro activo es el total
  /// filtrado ("N miembros" que coinciden con la vista).
  final int total;

  /// Última página cargada (base 1; `0` antes del primer fetch).
  final int page;

  /// `page < totalPages` — queda una página siguiente por pedir.
  final bool hasMore;

  /// Fetch de la página N+1 en vuelo — enciende el footer loader y
  /// bloquea un segundo `loadMore` simultáneo.
  final bool isLoadingMore;

  /// `search` activo (ya trimmeado por el cubit; `''` = sin búsqueda).
  final String query;

  /// Rol activo del chip de filtro (`null` = "Todos").
  final UserRole? roleFilter;

  /// Fallo de la carga inicial/refresh — la pantalla muestra
  /// `usersLoadError` + retry. La página N+1 falla en silencio (el
  /// spinner se apaga y el próximo scroll reintenta).
  final UsersFailure? failure;

  /// Contador de fallos de página 1/refresh — se incrementa en CADA
  /// emit de error para que dos errores Equatable-idénticos seguidos
  /// igual produzcan un estado distinto (§51 review): sin él, un
  /// pull-to-refresh que vuelve a fallar con el mismo failure no emite
  /// y el reintento queda sin feedback (el toast lo dispara el listener
  /// de la screen usando este nonce como trigger).
  final int errorNonce;

  /// IDs de miembros con una acción de fila en vuelo (PATCH status,
  /// §52) — la card muestra un `QuesivoLoader` chico en vez del ⋮
  /// mientras tanto. Set (no un solo id): dos acciones en cards
  /// distintas pueden volar a la vez.
  final Set<String> busyMemberIds;

  const UsersListState({
    this.status = UsersListStatus.initial,
    this.members = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.query = '',
    this.roleFilter,
    this.failure,
    this.errorNonce = 0,
    this.busyMemberIds = const {},
  });

  // Sentinel para distinguir "no se pasó el param" de "se pasó null"
  // en los campos nullable — `roleFilter`/`failure` sí se limpian a
  // null (chip "Todos", error recuperado).
  static const _unset = Object();

  UsersListState copyWith({
    UsersListStatus? status,
    List<OrgMember>? members,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? query,
    Object? roleFilter = _unset,
    Object? failure = _unset,
    int? errorNonce,
    Set<String>? busyMemberIds,
  }) => UsersListState(
    status: status ?? this.status,
    members: members ?? this.members,
    total: total ?? this.total,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    query: query ?? this.query,
    roleFilter: identical(roleFilter, _unset)
        ? this.roleFilter
        : roleFilter as UserRole?,
    failure: identical(failure, _unset)
        ? this.failure
        : failure as UsersFailure?,
    errorNonce: errorNonce ?? this.errorNonce,
    busyMemberIds: busyMemberIds ?? this.busyMemberIds,
  );

  @override
  List<Object?> get props => [
    status,
    members,
    total,
    page,
    hasMore,
    isLoadingMore,
    query,
    roleFilter,
    failure,
    errorNonce,
    busyMemberIds,
  ];
}
