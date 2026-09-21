import '../../domain/entities/users_page.dart';
import 'org_member_model.dart';

/// Modelo de `UsersPage` — única responsable de parsear el JSON del API
/// (shape de `GET /auth/users` → 200, doc 008): `{items: [...], meta:
/// {page, limit, total, totalPages}}`.
///
/// SOLID (SRP): la entidad no sabe parsear JSON — mismo patrón que
/// `OrgMemberModel extends OrgMember`.
class UsersPageModel extends UsersPage {
  const UsersPageModel({
    required super.items,
    required super.page,
    required super.limit,
    required super.total,
    required super.totalPages,
  });

  /// Contrato: `{items, meta:{page,limit,total,totalPages}}`. Defaults
  /// defensivos: un `meta` ausente o campos no numéricos caen a una
  /// página única con lo parseado — el listado no rompe por un body
  /// incompleto (los ítems, en cambio, sí se parsean uno a uno).
  factory UsersPageModel.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'];
    final metaMap = meta is Map<String, dynamic>
        ? meta
        : const <String, dynamic>{};
    final rawItems = json['items'];
    final items = (rawItems is List ? rawItems : const [])
        .whereType<Map<String, dynamic>>()
        .map(OrgMemberModel.fromJson)
        .toList();

    int metaInt(String key, int fallback) {
      final value = metaMap[key];
      return value is num ? value.toInt() : fallback;
    }

    return UsersPageModel(
      items: items,
      page: metaInt('page', 1),
      limit: metaInt('limit', items.length),
      total: metaInt('total', items.length),
      totalPages: metaInt('totalPages', 1),
    );
  }
}
