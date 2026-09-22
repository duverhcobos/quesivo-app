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

/// `400 + SELF_SUSPENSION` — el admin intentó suspender su propia
/// membresía (doc 009). Defensivo: la card propia no muestra ⋮.
class SelfSuspensionFailure extends UsersFailure {
  const SelfSuspensionFailure()
    : super('No podés suspender tu propia membresía.');
}

/// `400 + OWNER_SUSPENSION` — el target es dueño de la org (doc 009,
/// propuesta backend 056). Defensivo: la card del dueño no muestra ⋮.
class OwnerSuspensionFailure extends UsersFailure {
  const OwnerSuspensionFailure()
    : super('No se puede suspender al dueño de la organización.');
}

/// `400 + LAST_ADMIN` — suspenderlo dejaría la org sin administrador
/// activo (doc 009, decisión 004 §6.4).
class LastAdminFailure extends UsersFailure {
  const LastAdminFailure()
    : super('Es el último administrador activo — nombrá otro admin antes.');
}

/// `400 + OWNER_PASSWORD_RESET` — resetear el password del dueño es un
/// takeover de su cuenta global (doc 010, propuesta backend 057).
/// Defensivo: la card del dueño no muestra ⋮.
class OwnerPasswordResetFailure extends UsersFailure {
  const OwnerPasswordResetFailure()
    : super('No se puede restablecer la contraseña del dueño.');
}

/// `400 + SELF_ROLE_CHANGE` — el admin intentó cambiar su propio rol
/// (doc 012, propuesta backend 063). Defensivo: la card propia no
/// muestra ⋮.
class SelfRoleChangeFailure extends UsersFailure {
  const SelfRoleChangeFailure() : super('No podés cambiar tu propio rol.');
}

/// `400 + OWNER_ROLE_CHANGE` — el target es dueño de la org: quitarle
/// el rol ADMIN equivale a un takeover (doc 012, propuesta backend
/// 063). Defensivo: la card del dueño no muestra ⋮.
class OwnerRoleChangeFailure extends UsersFailure {
  const OwnerRoleChangeFailure()
    : super('No se puede cambiar el rol del dueño de la organización.');
}

/// `404 + MEMBERSHIP_NOT_FOUND` — el target ya no tiene membresía en la
/// org (card stale: la acción llegó después de que salió — ej. otro
/// cliente la modificó). Distinto de `UserNotFoundFailure` (link).
class MemberNotFoundFailure extends UsersFailure {
  const MemberNotFoundFailure()
    : super('El usuario ya no pertenece a esta organización.');
}

/// `403` — el JWT no trae rol `ADMIN`. Defensivo: la gestión solo se
/// muestra a admins, pero el rol pudo cambiar desde otro cliente.
class UsersForbiddenFailure extends UsersFailure {
  const UsersForbiddenFailure()
    : super('No tenés permisos para gestionar usuarios.');
}

/// `429` — rate limit del endpoint (varía por ruta — backend 060).
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
