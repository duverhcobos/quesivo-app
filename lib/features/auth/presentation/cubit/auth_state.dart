// lib/features/auth/presentation/cubit/auth_state.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

/// Define todos los posibles estados de Autenticación.
///
/// SOLID (OCP): La UI está cerrada para modificar cómo gestiona los datos de
/// la base pero abierta a expandir nuevos estados (ej. EmailVerificationRequired).
/// Usamos Equatable para optimizar reconstrucciones de UI al evitar emitir
/// dos estados con los mismos valores (verificación por valor, no referencia).
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

/// Estado inicial, antes de interacciones del usuario.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Estado en progreso, se muestra el "Loading Spinner".
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Estado de éxito. Pasa el User hacia la UI para navegación y guardado.
class AuthSuccess extends AuthState {
  final User user;

  const AuthSuccess(this.user);

  @override
  List<Object> get props => [user];
}

/// Estado de error. Pasa el mensaje literal para mostrar en un SnackBar.
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}
