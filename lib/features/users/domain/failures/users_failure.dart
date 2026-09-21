import 'package:equatable/equatable.dart';

/// Base de fallos del módulo Usuarios — espejo de `AuthFailure` (OCP:
/// abierta a extensión, cerrada a modificación). La UI mapea el TIPO
/// concreto a su key l10n; `message` queda como fallback para logs.
abstract class UsersFailure extends Equatable {
  final String message;

  const UsersFailure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Sin conectividad al momento de la llamada (`INetworkInfo`).
class UsersNetworkFailure extends UsersFailure {
  const UsersNetworkFailure() : super('No se pudo conectar al servidor.');
}

/// `409 + MEMBERSHIP_ALREADY_EXISTS` — el email ya tiene membresía en
/// ESTA organización (doc 007-post-users).
class MembershipAlreadyExistsFailure extends UsersFailure {
  const MembershipAlreadyExistsFailure()
    : super('Ese correo ya pertenece a esta organización.');
}

/// `409 + USER_SUSPENDED` — el email existe globalmente pero la cuenta
/// está suspendida: no se vincula (doc 007-post-users).
class LinkedUserSuspendedFailure extends UsersFailure {
  const LinkedUserSuspendedFailure()
    : super('Esa cuenta está suspendida — no se puede vincular.');
}

/// `409 + EMAIL_ALREADY_EXISTS` (create) — el email ya tiene cuenta
/// global; la vinculación es otra acción (doc 007 post-058).
class EmailAlreadyExistsFailure extends UsersFailure {
  const EmailAlreadyExistsFailure()
    : super('Ese correo ya tiene cuenta — vinculalo como existente.');
}

/// `404 + USER_NOT_FOUND` (link) — el email no tiene cuenta global;
/// crear es la otra acción.
class UserNotFoundFailure extends UsersFailure {
  const UserNotFoundFailure()
    : super('Ese correo no tiene cuenta — crealo desde "Crear usuario".');
}

/// `409 + USER_IS_OWNER` (link) — dueño de otra org no es vinculable
/// (propuesta backend 056).
class UserIsOwnerFailure extends UsersFailure {
  const UserIsOwnerFailure()
    : super('Ese correo es dueño de otra quesera — no puede vincularse.');
}

/// `403` — el JWT no trae rol `ADMIN`. Defensivo: la gestión solo se
/// muestra a admins, pero el rol pudo cambiar desde otro cliente.
class UsersForbiddenFailure extends UsersFailure {
  const UsersForbiddenFailure()
    : super('No tenés permisos para gestionar usuarios.');
}

/// `429` — rate limit del endpoint (10 req/min).
class UsersRateLimitFailure extends UsersFailure {
  const UsersRateLimitFailure()
    : super('Demasiados intentos. Esperá un momento e intentalo de nuevo.');
}

/// Validación local del use case — la sheet ya bloquea el submit con
/// datos inválidos; esta es la segunda línea defensiva del dominio.
class InvalidMemberDataFailure extends UsersFailure {
  const InvalidMemberDataFailure() : super('Revisá los datos del formulario.');
}

/// Cualquier otro error del servidor/red no clasificado.
class UsersServerFailure extends UsersFailure {
  const UsersServerFailure([String? message])
    : super(message ?? 'Ocurrió un error en el servidor. Intentalo más tarde.');
}
