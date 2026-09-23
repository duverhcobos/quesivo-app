import 'package:equatable/equatable.dart';

/// Sesión emitida por `POST /auth/select-organization`
/// (`documentacion/api/auth/006-post-select-organization.md`): par de
/// tokens org-scoped + contexto de la quesera entrante.
///
/// Es el tipo que el dominio expone hacia las capas superiores (§63):
/// el repo lo devuelve tras persistir los tokens y `AuthCubit` lo usa
/// para reconstruir el `User` en el lugar — sin `GET /auth/me` extra.
/// El model de data (`OrganizationSessionModel`) lo extiende para
/// agregar el parseo JSON, igual que `UserModel extends User`.
class OrganizationSession extends Equatable {
  final String accessToken;
  final String refreshToken;
  final String organizationId;
  final String organizationName;

  const OrganizationSession({
    required this.accessToken,
    required this.refreshToken,
    required this.organizationId,
    required this.organizationName,
  });

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    organizationId,
    organizationName,
  ];
}
