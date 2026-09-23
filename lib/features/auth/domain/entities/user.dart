// lib/features/auth/domain/entities/user.dart
import 'package:equatable/equatable.dart';

import 'organization_summary.dart';

/// Usuario autenticado en la aplicación.
///
/// SOLID (SRP - Single Responsibility Principle):
/// Esta clase (Entity) solo tiene la responsabilidad de representar
/// los datos principales del negocio (Usuario) independientemente de
/// cómo se obtienen, almacenan o muestran. No contiene lógica de serialización.
class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? token;
  final String? refreshToken;

  /// Tenant del usuario — `organization_id`/`organization.name` del esquema
  /// F0 (propuesta 36). Null solo en respuestas legacy sin org.
  final String? organizationId;
  final String? organizationName;

  /// Roles del usuario en su organización (`ADMIN`/`OPERADOR` en F0).
  final List<String> roles;

  /// Estado de la cuenta según `GET /auth/me`: `active`,
  /// `pending_verification` o `suspended`. Null en respuestas que no lo
  /// traen (login/register no lo incluyen) — nunca asumirlo "active".
  final String? status;

  /// Queseras del usuario — solo llegan de `GET /auth/me` (propuesta
  /// backend 066). Con token personal `organizationId` es null: el user
  /// está autenticado pero fuera de toda quesera (capa personal).
  final List<OrganizationSummary> organizations;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.token,
    this.refreshToken,
    this.organizationId,
    this.organizationName,
    this.roles = const [],
    this.status,
    this.organizations = const [],
  });

  /// Update en el lugar (§63): tras un select-organization exitoso el
  /// `AuthCubit` reconstruye el User con los tokens/org de la sesión
  /// sin un `GET /auth/me` extra.
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? token,
    String? refreshToken,
    String? organizationId,
    String? organizationName,
    List<String>? roles,
    String? status,
    List<OrganizationSummary>? organizations,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      roles: roles ?? this.roles,
      status: status ?? this.status,
      organizations: organizations ?? this.organizations,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    token,
    refreshToken,
    organizationId,
    organizationName,
    roles,
    status,
    organizations,
  ];
}
