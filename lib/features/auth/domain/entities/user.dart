// lib/features/auth/domain/entities/user.dart
import 'package:equatable/equatable.dart';

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

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.token,
    this.refreshToken,
    this.organizationId,
    this.organizationName,
    this.roles = const [],
  });

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
  ];
}
