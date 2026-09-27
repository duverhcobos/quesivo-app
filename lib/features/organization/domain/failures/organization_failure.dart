import 'package:equatable/equatable.dart';

/// Base de fallos del módulo Organization — espejo de `AuthFailure`/
/// `UsersFailure` (OCP: abierta a extensión, cerrada a modificación).
/// La UI mapea el TIPO concreto a su key l10n; `message` queda como
/// fallback para logs.
abstract class OrganizationFailure extends Equatable {
  final String message;

  const OrganizationFailure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Sin conectividad al momento del PATCH (`INetworkInfo`) o request sin
/// respuesta (server caído/timeout — `ServerException` de la capa de red).
class OrganizationNetworkFailure extends OrganizationFailure {
  const OrganizationNetworkFailure()
    : super('No se pudo conectar al servidor.');
}

/// 401/403 — el JWT no trae rol `ADMIN` o es un token personal (doc
/// organizations/001). Defensivo: la pantalla de nombrado solo la ve el
/// admin que acaba de crear la org (`isNewSignup` tras el signup).
class OrganizationForbiddenFailure extends OrganizationFailure {
  const OrganizationForbiddenFailure()
    : super('No tienes permisos para renombrar la quesera.');
}

/// Cualquier otro error del PATCH (400 de validación, 429, 5xx) o una
/// falla de storage al actualizar la sesión cacheada.
class OrganizationUpdateFailure extends OrganizationFailure {
  const OrganizationUpdateFailure([String? message])
    : super(message ?? 'No se pudo guardar el nombre. Inténtalo más tarde.');
}
