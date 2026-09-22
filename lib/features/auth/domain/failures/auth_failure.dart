// lib/features/auth/domain/failures/auth_failure.dart
import 'package:equatable/equatable.dart';

/// Base class para manejar fallos en la capa de Domain.
///
/// SOLID (OCP - Open/Closed Principle):
/// AuthFailure está abierta a la extensión (podemos crear nuevas clases
/// como NetworkFailure, CredentialsFailure) pero cerrada a la modificación.
abstract class AuthFailure extends Equatable {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure() : super('Correo o contraseña incorrectos.');
}

/// Ocurre cuando el email ya está registrado (HTTP 409 del backend).
class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure()
    : super('Ya existe una cuenta con ese correo.');
}

/// Ocurre cuando la cuenta existe pero está suspendida (HTTP 403 del
/// backend — §3.2: el backend lo evalúa tras verificar el password).
class AccountSuspendedFailure extends AuthFailure {
  const AccountSuspendedFailure()
    : super(
        'Tu cuenta está suspendida. Contacta al administrador de tu organización.',
      );
}

/// La cuenta existe y el password es correcto, pero la membresía tiene
/// rol distinto a ADMIN (HTTP 403 + errorCode ROLE_NOT_ALLOWED — backend
/// propuesta 062). El MVP solo tiene UI de administrador.
class RoleNotAllowedFailure extends AuthFailure {
  const RoleNotAllowedFailure()
    : super(
        'Esta app es solo para administradores. Tu cuenta está activa pero no tiene ese rol en la organización.',
      );
}

/// Ocurre cuando el rate limit del backend rechaza el intento (HTTP 429).
class TooManyAttemptsFailure extends AuthFailure {
  const TooManyAttemptsFailure()
    : super('Demasiados intentos. Espera un momento e inténtalo de nuevo.');
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure() : super('No se pudo conectar al servidor.');
}

/// Ocurre cuando hay un error en el servidor o de red.
class ServerFailure extends AuthFailure {
  const ServerFailure([String? message])
    : super(message ?? 'Ocurrió un error en el servidor. Inténtalo más tarde.');
}

/// Ocurre cuando no existe una sesión válida persistida localmente.
/// No es un error del usuario: simplemente aún no inició sesión (o expiró).
class NoSessionFailure extends AuthFailure {
  const NoSessionFailure() : super('No hay una sesión activa.');
}

/// Ocurre cuando falla una operación de almacenamiento local
/// (lectura/escritura/borrado en el secure storage).
class CacheFailure extends AuthFailure {
  const CacheFailure([String? message])
    : super(message ?? 'Error de almacenamiento local.');
}

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure(super.message);
}
