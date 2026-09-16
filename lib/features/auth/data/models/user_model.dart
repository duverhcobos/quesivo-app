// lib/features/auth/data/models/user_model.dart
import '../../domain/entities/user.dart';

/// Modelo de Usuario que extiende la Entidad (Entity).
///
/// SOLID (SRP): Esta clase se encarga ÚNICAMENTE de la transformación/serialización
/// de datos provenientes de la fuente externa (ej. un JSON) hacia objetos manejables.
/// La Entidad User no necesita saber cómo se parsea un JSON.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    super.token,
    super.refreshToken,
  });

  /// Factory Data constructor
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // La API ficticia DummyJSON devuelve 'id' como entero y el nombre en 'firstName'
    // Esta clase absorbe ese acoplamiento externo para que el Entity quede puro.
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      token: json['token'] ?? json['accessToken'], // Soporta variantes
      refreshToken: json['refreshToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'token': token,
      'refreshToken': refreshToken,
    };
  }
}
