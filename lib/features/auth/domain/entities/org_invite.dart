import 'package:equatable/equatable.dart';

/// Invitación pendiente a una organización — ítem de `pendingInvites[]`
/// de `GET /auth/me` (propuesta backend 072): alguien te vinculó con
/// `POST /users/link` y tu membresía quedó `invited` hasta que la
/// aceptes o la rechaces con sesión (consentimiento — un typo de email
/// del admin ya no te mete adentro sin autorización).
///
/// `id` es el de la MEMBRESÍA; `organizationId` el path param de
/// accept/decline (`/me/org-invites/:orgId/*`, docs 019/020).
class OrgInvite extends Equatable {
  final String id;
  final String organizationId;
  final String organizationName;
  final String role;

  const OrgInvite({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.role,
  });

  @override
  List<Object?> get props => [id, organizationId, organizationName, role];
}
