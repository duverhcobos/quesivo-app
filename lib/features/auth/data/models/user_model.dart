// lib/features/auth/data/models/user_model.dart
import '../../domain/entities/org_invite.dart';
import '../../domain/entities/organization_summary.dart';
import '../../domain/entities/user.dart';

/// Modelo de Usuario que extiende la Entidad (Entity).
///
/// SOLID (SRP): Esta clase se encarga ÚNICAMENTE de la transformación/serialización
/// de datos provenientes de la fuente externa (ej. un JSON) hacia objetos manejables.
/// La Entidad User no necesita saber cómo se parsea un JSON.
///
/// Contrato real: `documentacion/api/auth/001-post-register.md` y
/// `002-post-login.md` (quesivo-api).
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    super.token,
    super.refreshToken,
    super.organizationId,
    super.organizationName,
    super.roles,
    super.status,
    super.organizations,
    super.pendingInvites,
  });

  /// Factory Data constructor — shape real de AuthResponseDto.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      token: json['accessToken'],
      refreshToken: json['refreshToken'],
      organizationId: json['organizationId'],
      organizationName: json['organizationName'],
      roles:
          (json['roles'] as List?)?.map((e) => e as String).toList() ??
          const [],
      status: json['status'],
      organizations:
          (json['organizations'] as List?)
              ?.map(
                (e) => OrganizationSummary(
                  id: e['id']?.toString() ?? '',
                  name: e['name'] ?? '',
                  role: e['role'] ?? '',
                ),
              )
              .toList() ??
          const [],
      // Backend 072 — invitaciones a orgs pendientes (membresías
      // `invited`). Ausente en respuestas que no lo traen → [].
      pendingInvites:
          (json['pendingInvites'] as List?)
              ?.map(
                (e) => OrgInvite(
                  id: e['id']?.toString() ?? '',
                  organizationId: e['organizationId']?.toString() ?? '',
                  organizationName: e['organizationName']?.toString() ?? '',
                  role: e['role']?.toString() ?? '',
                ),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'accessToken': token,
      'refreshToken': refreshToken,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'roles': roles,
      'status': status,
      'organizations': organizations
          .map((o) => {'id': o.id, 'name': o.name, 'role': o.role})
          .toList(),
      'pendingInvites': pendingInvites
          .map(
            (i) => {
              'id': i.id,
              'organizationId': i.organizationId,
              'organizationName': i.organizationName,
              'role': i.role,
            },
          )
          .toList(),
    };
  }
}
