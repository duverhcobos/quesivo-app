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
///
/// `enteredOrg` (§57) es estado de SESIÓN DE APP, no del JWT: nace en
/// `false` en toda carga de sesión y solo se prende con
/// `AuthCubit.enterOrganization()` tras el tap en una quesera. Así el
/// selector arranca siempre limpio aunque el token guardado sea
/// org-scoped — mismo flujo en login fresco y en sesión restaurada.
class AuthSuccess extends AuthState {
  final User user;
  final bool enteredOrg;

  const AuthSuccess(this.user, {this.enteredOrg = false});

  @override
  List<Object> get props => [user, enteredOrg];
}

/// Estado de error. Pasa el mensaje literal para mostrar en un toast.
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}
