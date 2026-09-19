import 'package:equatable/equatable.dart';

import 'user_role.dart';

/// Estado de la membresía en la organización (`status` del contrato).
enum MemberStatus { active, suspended }

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

  const OrgMember({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.organizationId,
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
  }) => OrgMember(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    role: role ?? this.role,
    status: status ?? this.status,
    organizationId: organizationId ?? this.organizationId,
  );

  @override
  List<Object?> get props => [id, email, name, role, status, organizationId];
}
