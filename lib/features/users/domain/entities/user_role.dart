/// Rol de una membresía dentro de la organización — catálogo fijo del
/// backend (`role` en `/auth/users`, §docs api/auth/007-008).
/// El label visible se resuelve en presentation vía l10n; `apiValue` se
/// usa al serializar hacia el API.
enum UserRole {
  admin('ADMIN'),
  operator('OPERATOR'),
  collector('COLLECTOR'),
  producer('PRODUCER');

  const UserRole(this.apiValue);

  /// Valor del contrato del backend.
  final String apiValue;

  /// Parse del string del API; `operator` como fallback defensivo — el
  /// catálogo es cerrado y lo controla el backend.
  static UserRole fromApi(String? value) => UserRole.values.firstWhere(
    (r) => r.apiValue == value,
    orElse: () => UserRole.operator,
  );
}
