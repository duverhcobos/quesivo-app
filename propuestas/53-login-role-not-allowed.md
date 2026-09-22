# Propuesta 53 — Mensaje propio para `ROLE_NOT_ALLOWED` en login

El backend 062 cerró el login a roles no-ADMIN (`403` + `errorCode:
ROLE_NOT_ALLOWED`). Hoy el frontend mapea **cualquier** 403 a
`AccountSuspendedFailure` → un OPERATOR con credenciales correctas vería
"Tu cuenta está suspendida" — mensaje incorrecto (no está suspendido,
la app es solo para admins).

`RestApiException` ya expone `errorCode` (extraído del body en ambos
network services) — solo hay que usarlo.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/failures/auth_failure.dart` | `RoleNotAllowedFailure` nuevo (mensaje inline — convención del archivo, los failures de auth llevan el texto) |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | el branch 403 distingue por `errorCode` |
| `test/features/auth/data/repositories/auth_repository_impl_test.dart` | caso nuevo: 403 + `ROLE_NOT_ALLOWED` → `RoleNotAllowedFailure`; el 403 pelado sigue → `AccountSuspendedFailure` |

---

## 1. `auth_failure.dart` — failure nuevo

**Ruta:** `lib/features/auth/domain/failures/auth_failure.dart`

Después de `AccountSuspendedFailure`:

```dart
/// La cuenta existe y el password es correcto, pero la membresía tiene
/// rol distinto a ADMIN (HTTP 403 + errorCode ROLE_NOT_ALLOWED — backend
/// propuesta 062). El MVP solo tiene UI de administrador.
class RoleNotAllowedFailure extends AuthFailure {
  const RoleNotAllowedFailure()
    : super(
        'Esta app es solo para administradores. Tu cuenta está activa pero no tiene ese rol en la organización.',
      );
}
```

## 2. `auth_repository_impl.dart` — distinguir por errorCode

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Antes:**

```dart
    } on RestApiException catch (e, stackTrace) {
      // Contrato real (api/auth/002): 403 = cuenta suspendida, 429 =
      // rate limit — ambos merecen mensaje propio, no el crudo del body.
      if (e.statusCode == 403) {
        return const Left(AccountSuspendedFailure());
      }
```

**Después:**

```dart
    } on RestApiException catch (e, stackTrace) {
      // Contrato real (api/auth/002): 403 = cuenta suspendida O rol
      // no-ADMIN (propuesta 062 — se distinguen por errorCode: el de
      // suspendida viaja sin código), 429 = rate limit — ambos merecen
      // mensaje propio, no el crudo del body.
      if (e.statusCode == 403) {
        if (e.errorCode == 'ROLE_NOT_ALLOWED') {
          return const Left(RoleNotAllowedFailure());
        }
        return const Left(AccountSuspendedFailure());
      }
```

## 3. Spec — cubrir los dos 403

**Ruta:** `test/features/auth/data/repositories/auth_repository_impl_test.dart`

- Nuevo caso junto al existente de 403: `RestApiException(statusCode: 403, message: 'x', errorCode: 'ROLE_NOT_ALLOWED')` → `Left(RoleNotAllowedFailure())`.
- El caso existente (403 sin errorCode → `AccountSuspendedFailure`) queda igual — fija que la suspensión sigue mapeando.

---

## No toca

- `AccountSuspendedFailure` — el 403 sin errorCode sigue significando
  "suspendida" (el backend `UserSuspendedException` no manda código).
- `login_cubit` — emite `failure.message` directo; el texto nuevo fluye
  solo, sin cambios de UI ni l10n (los failures de auth llevan el
  mensaje inline — convención del archivo, distinta del módulo users).
- Selector multi-org — un user con orgs admin+no-admin entra por las
  admin; el backend ya filtró la lista.

## Verificación

`flutter analyze` + `flutter test` (spec del repo con el caso nuevo).
En vivo: login `miembro10@quesera.dev` / `Temporal123` (OPERATOR) →
debe mostrar el mensaje de "solo administradores", no "suspendida".
