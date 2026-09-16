# Propuesta 037 — Login: mapeo de errores según contrato real (002)

## Contexto

`loginWithEmailPassword` ya pega al backend real desde la propuesta 036
(comparte datasource/base URL con register). Lo que falta es el mapeo
correcto de los status codes del contrato `documentacion/api/auth/002-post-login.md`:

| Status | Hoy | Debería |
|--------|-----|---------|
| 401 `INVALID_CREDENTIALS` | `UnauthorizedException` → `InvalidCredentialsFailure` ✅ | igual |
| 403 `USER_SUSPENDED` | `RestApiException` → `ServerFailure("Forbidden")` — statusMessage HTTP crudo | `AccountSuspendedFailure` con mensaje útil |
| 400 validación | **BUG**: mapeado a `UnauthorizedException` → "Correo o contraseña incorrectos" | `ServerFailure` con el `message` real del body |
| 429 throttle | genérico | `TooManyAttemptsFailure` |
| sin respuesta | `ServerException` → `ServerFailure` | igual |

Además `_handleDioError` usa `e.response!.statusMessage` (reason phrase
HTTP, ej. "Forbidden") en vez del `message` del body NestJS
(`{statusCode, message: string|string[], error}`) — hay que extraer el
mensaje real.

## Cambios

1. **`core/network/implementations/dio_network_service_impl.dart`** —
   `_handleDioError`: extraer `data['message']` (string o primer elemento
   si es array) como mensaje; 401 → `UnauthorizedException`; resto →
   `RestApiException(statusCode, mensaje real)`. El `400 → Unauthorized`
   se elimina.
2. **`core/network/implementations/http_network_service_impl.dart`** —
   mismo fix de `400` para paridad (está comentado en DI pero sigue
   shipped).
3. **`domain/failures/auth_failure.dart`** — +`AccountSuspendedFailure`
   ("Tu cuenta está suspendida. Contacta al administrador de tu
   organización.") y +`TooManyAttemptsFailure` ("Demasiados intentos.
   Espera un momento e inténtalo de nuevo.").
4. **`auth_repository_impl.dart`** — en `loginWithEmailPassword`, sobre
   `RestApiException`: `403 → AccountSuspendedFailure`,
   `429 → TooManyAttemptsFailure`, resto → `ServerFailure(e.message)`.
5. **Specs** — actualizar los existentes que asuman `400 → Unauthorized`
   y agregar casos 403/429 del repo.

## Fuera de alcance

`refresh`/`logout`/`me` (propuesta siguiente — el interceptor ya existe),
Google login (sin endpoint backend aún), forgot/reset (sin backend).

## Verificación

`flutter analyze` + `flutter test`. Manual: suspender la cuenta en BD
(`UPDATE users SET status='suspended'`) → login muestra el mensaje de
suspendida, no "Forbidden".
