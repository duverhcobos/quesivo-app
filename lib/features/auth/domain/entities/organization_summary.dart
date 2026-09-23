import 'package:equatable/equatable.dart';

/// Una quesera a la que el usuario pertenece (ítem de `organizations[]`
/// de `GET /auth/me`, propuestas backend 050+066).
///
/// SOLID (SRP): representa el resumen de membresía — el rol vive acá,
/// no en el User, porque es por-organización.
class OrganizationSummary extends Equatable {
  final String id;
  final String name;
  final String role;

  const OrganizationSummary({
    required this.id,
    required this.name,
    required this.role,
  });

  @override
  List<Object?> get props => [id, name, role];
}
