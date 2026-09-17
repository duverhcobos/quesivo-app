// lib/features/auth/data/models/user_model.dart
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
    };
  }
}
