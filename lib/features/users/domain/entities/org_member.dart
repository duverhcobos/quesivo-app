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

  @override
  List<Object?> get props => [id, email, name, role, status, organizationId];
}
