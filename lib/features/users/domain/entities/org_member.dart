import 'package:equatable/equatable.dart';

import 'user_role.dart';

/// Estado de la membresía en la organización (`status` del contrato).
enum MemberStatus {
  active('active'),
  suspended('suspended'),
  // Backend 072: membresía de vinculación sin aceptar — el ⋮ solo
  // ofrece reenviar/cancelar y el chip muestra "Invitado" (ámbar).
  invited('invited');

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

  /// Estado de la MEMBRESÍA en la org (`status` del contrato) —
  /// active/suspended/invited (backend 072). No confundir con
  /// `invitePending` (estado global).
  final MemberStatus status;

  /// `true` solo cuando el miembro es un **invitado que aún no aceptó**
  /// (`invitePending` del contrato — backend 071, Email-C): la regla es
  /// `userStatus=pending_verification` Y sin password, derivada en el
  /// backend. Un auto-registrado sin verificar también es
  /// `pending_verification` pero TIENE password → no es invitado y esto
  /// queda `false` (el gate exacto de "Reenviar invitación", doc 018).
  /// Ausente en backends viejos → `false` (degradación limpia).
  final bool invitePending;
  final String organizationId;

  /// `true` cuando el email ya existía globalmente y `POST /auth/users`
  /// solo creó la membresía (doc 007) — el usuario conserva su password
  /// y el admin no tiene contraseña temporal que compartir. Solo viene
  /// en las respuestas de create/link: los ítems de `GET /users`
  /// no lo traen (queda en `false`).
  final bool linked;

  /// `true` cuando el miembro es el dueño de la organización
  /// (`isOwner` del contrato de `GET /users` — backend 056): la UI
  /// lo marca con el badge "Dueño" y oculta el menú ⋮ (suspender/reset
  /// son `OWNER_*` en backend — ofrecerlos siempre falla).
  final bool isOwner;

  const OrgMember({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.invitePending,
    required this.organizationId,
    this.linked = false,
    this.isOwner = false,
  });

  /// Copia inmutable con overrides — la UI la usa para flippear
  /// `status` en el dataset local; la integración la usará con el ítem
  /// que devuelve PATCH /users/:id/status.
  OrgMember copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    MemberStatus? status,
    bool? invitePending,
    String? organizationId,
    bool? linked,
    bool? isOwner,
  }) => OrgMember(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    role: role ?? this.role,
    status: status ?? this.status,
    invitePending: invitePending ?? this.invitePending,
    organizationId: organizationId ?? this.organizationId,
    linked: linked ?? this.linked,
    isOwner: isOwner ?? this.isOwner,
  );

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    role,
    status,
    invitePending,
    organizationId,
    linked,
    isOwner,
  ];
}
