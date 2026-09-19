import 'package:equatable/equatable.dart';

import 'user_role.dart';

/// Estado de la membresía en la organización (`status` del contrato).
enum MemberStatus {
  active('active'),
  suspended('suspended');

  const MemberStatus(this.apiValue);

  /// Valor del contrato del backend.
  final String apiValue;

  /// Parse del string del API; `active` como fallback defensivo — el
  /// catálogo es cerrado y lo controla el backend.
  static MemberStatus fromApi(String? value) => MemberStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => MemberStatus.active,
  );
}

/// Miembro de la organización activa — una fila del listado de usuarios
/// (`UserListItem` del backend). La organización nunca viaja en el body:
/// la infiere el JWT del admin.
class OrgMember extends Equatable {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final MemberStatus status;
  final String organizationId;

  /// `true` cuando el email ya existía globalmente y `POST /auth/users`
  /// solo creó la membresía (doc 007) — el usuario conserva su password
  /// y el admin no tiene contraseña temporal que compartir.
  final bool linked;

  const OrgMember({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.organizationId,
    this.linked = false,
  });

  /// Copia inmutable con overrides — la UI la usa para flippear
  /// `status` en el dataset local; la integración la usará con el ítem
  /// que devuelve PATCH /auth/users/:id/status.
  OrgMember copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    MemberStatus? status,
    String? organizationId,
    bool? linked,
  }) => OrgMember(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    role: role ?? this.role,
    status: status ?? this.status,
    organizationId: organizationId ?? this.organizationId,
    linked: linked ?? this.linked,
  );

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    role,
    status,
    organizationId,
    linked,
  ];
}
