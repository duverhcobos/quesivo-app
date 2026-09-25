import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';

/// Modelo de `OrgMember` — única responsable de parsear el JSON del API
/// (shape de `POST /auth/users` → 201, doc 007; el mismo shape repite
/// `GET /auth/users` por ítem).
///
/// SOLID (SRP): la entidad no sabe parsear JSON — igual que
/// `UserModel extends User` en auth.
class OrgMemberModel extends OrgMember {
  const OrgMemberModel({
    required super.id,
    required super.email,
    required super.name,
    required super.role,
    required super.status,
    required super.invitePending,
    required super.organizationId,
    super.linked,
    super.isOwner,
  });

  /// Ítems del listado/PATCH (doc 008+): `status` = membresía,
  /// `invitePending` = invitado sin aceptar (backend 071 — Email-C).
  /// `invitePending` ausente (backend viejo) cae a `false` — degradación
  /// limpia: sin el campo no hay badge ni reenvío.
  ///
  /// Contrato del listado (`GET /auth/users`, doc 008):
  /// `{id,email,name,role,status,userStatus,invitePending,lastLoginAt,
  /// isOwner}` — los ítems del GET NO traen `organizationId` ni `linked`
  /// (la org es la del JWT y `linked` solo aplica a create/link): caen a
  /// los defaults `''` / `false`. `userStatus`/`lastLoginAt` no se usan
  /// en la UI hoy — no se parsean.
  ///
  /// Defaults defensivos: `role`/`status` son catálogos cerrados del
  /// backend — un valor desconocido cae a operator/active en vez de
  /// romper el flujo completo. `name` puede venir `null` en el listado
  /// (profile sin nombre cargado) → `''`.
  factory OrgMemberModel.fromJson(Map<String, dynamic> json) {
    return OrgMemberModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: UserRole.fromApi(json['role'] as String?),
      status: MemberStatus.fromApi(json['status'] as String?),
      invitePending: json['invitePending'] == true,
      organizationId: json['organizationId']?.toString() ?? '',
      linked: json['linked'] == true,
      isOwner: json['isOwner'] == true,
    );
  }

  /// Contrato create/link (doc 007): `{id,email,name,role,status,
  /// organizationId,linked,invitePending}` — acá `status` ES el del
  /// usuario global ('pending_verification' en modo invitación — Email-C
  /// 070): la membresía nueva siempre nace `active` y el backend ya
  /// deriva `invitePending` (pending + passwordless).
  factory OrgMemberModel.fromCreatedJson(Map<String, dynamic> json) {
    return OrgMemberModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: UserRole.fromApi(json['role'] as String?),
      status: MemberStatus.active,
      invitePending: json['invitePending'] == true,
      organizationId: json['organizationId']?.toString() ?? '',
      linked: json['linked'] == true,
      isOwner: json['isOwner'] == true,
    );
  }
}
