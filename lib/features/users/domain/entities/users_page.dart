import 'package:equatable/equatable.dart';

import 'org_member.dart';

/// Una página del listado de miembros de la organización
/// (`GET /auth/users`, doc 008 — propuestas backend 052+059). El
/// backend pagina y filtra: `total`/`totalPages` del `meta` reflejan el
/// `search`/`role` activo (total FILTRADO, no el de la org).
class UsersPage extends Equatable {
  /// Miembros de la página — orden `created_at ASC` + tiebreaker `id`.
  final List<OrgMember> items;

  /// Página devuelta (`meta.page` — base 1).
  final int page;

  /// Tamaño de página pedido (`meta.limit`).
  final int limit;

  /// Total de filas que cumplen los filtros (`meta.total`).
  final int total;

  /// Páginas totales bajo los filtros (`meta.totalPages`).
  final int totalPages;

  const UsersPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  /// Quedan páginas por pedir — el scroll al borde dispara `page + 1`.
  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [items, page, limit, total, totalPages];
}
