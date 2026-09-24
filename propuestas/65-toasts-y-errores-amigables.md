# §65 — Cero SnackBar + errores de servidor amigables

Documento retroactivo: surgió de un hallazgo en vivo — con el backend
caído el usuario veía un `SnackBar` con `Internal server error` en
inglés.

## Problema

1. **SnackBars vivos**: la migración a `QuesivoToast` (pill flotante
   arriba, §46 en adelante) había quedado a medias — quedaban 6 sitios
   con `ScaffoldMessenger.showSnackBar`.
2. **Mensaje crudo del backend en la UI**: los repos pasaban
   `ServerFailure(e.message)` para statuses no mapeados. Todos los
   mensajes de dominio del backend son **en inglés**
   (`'Cannot suspend your own membership'`, `'Internal server error'`)
   — el copy amigable en español vive en los `*Failure` tipados. Con el
   server caído el request no tiene respuesta → `ServerException`
   (500/'Internal server error') → el usuario leía inglés técnico.

## Cambio

### A. SnackBar → `QuesivoToast` (6 sitios)

| Pantalla | Feedback |
|---|---|
| `login_screen` | `AuthError` + `LoginState.failure` → `error` |
| `register_screen` | `AuthError` + `RegisterState.failure` → `error` |
| `forgot_password_screen` | failure → `error` |
| `reset_password_screen` | failure → `error`, success → `success` |
| `quesera_hero_carousel` | error de `select-organization` → `error` |
| `quesivo_nav_bar` | hint "Elegí tu quesera" → `info` |

### B. `e.message` nunca llega a la UI

`auth_repository_impl` — helper `_mapUnmappedError(RestApiException)`:

- `ServerException` (request **sin respuesta**: server caído, timeout,
  body ilegible) → `NetworkFailure` → *"No se pudo conectar al
  servidor."*
- Cualquier otro status no mapeado → `ServerFailure()` default →
  *"Ocurrió un error en el servidor. Inténtalo más tarde."*

`users_repository_impl._mapError` — misma regla: `ServerException` →
`UsersNetworkFailure`; codes/status no mapeados → `UsersServerFailure()`
default. El detalle real queda en el `logger` (ya lo hacía).

Se aplica en login, register, select-organization y resetPassword + en
todos los paths de gestión de usuarios.

## Lo que NO cambia

- Los `errorCode` de dominio conocidos siguen mapeando a sus failures
  tipados (`MEMBERSHIP_ALREADY_EXISTS`, `LAST_ADMIN`, `ROLE_NOT_ALLOWED`,
  403/409/429…) — copy español intacto.
- `NetworkFailure` de `networkInfo.isConnected == false` (sin internet
  real): mismo canal, mismo mensaje.

## Tests

- Repo auth + users: asserts `Failure(e.message)` → failure default;
  tests nuevos `ServerException → Network` en login,
  select-organization y createUser.
- `quesivo_nav_bar_test`: el hint ahora es toast — se drena su
  auto-dismiss (~2.6s) con `pump(3s)` (convención del módulo).
