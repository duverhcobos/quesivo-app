import '../../domain/entities/organization_session.dart';

/// Response de `POST /auth/select-organization`
/// (`documentacion/api/auth/006-post-select-organization.md`):
/// par de tokens org-scoped + contexto de la quesera entrante.
/// La sesión personal que lo llamó queda consumida server-side —
/// el par viejo se descarta al persistir este.
class OrganizationSessionModel extends OrganizationSession {
  const OrganizationSessionModel({
    required super.accessToken,
    required super.refreshToken,
    required super.organizationId,
    required super.organizationName,
  });

  factory OrganizationSessionModel.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'] as String? ?? '';
    final refreshToken = json['refreshToken'] as String? ?? '';
    // Tokens vacíos = respuesta malformada: lanzar en vez de tragar —
    // si llegaran al repo pisarían la sesión válida en storage con
    // credenciales vacías (peor que fallar; auditoría §63).
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const FormatException(
        'select-organization: accessToken/refreshToken ausentes',
      );
    }
    return OrganizationSessionModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      organizationId: json['organizationId'] as String? ?? '',
      organizationName: json['organizationName'] as String? ?? '',
    );
  }
}
