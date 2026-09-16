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

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.token,
    this.refreshToken,
  });

  @override
  List<Object?> get props => [id, email, name, token, refreshToken];
}
