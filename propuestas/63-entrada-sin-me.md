# §63 — Entrada a quesera sin GET /auth/me extra

## Problema

Cada tap en una card de quesera hace **dos** requests seguidos:

1. `POST /auth/select-organization` → tokens org-scoped
2. `GET /auth/me` → rehidrata el `UserModel` (lo llama `AuthCubit.refreshSession()` desde `QueseraSelectionCubit.select`)

El segundo es redundante: `select-organization` ya devuelve `organizationId` + `organizationName`, y la lista de `organizations` (membresías) **no cambia** al entrar a una quesera — es la misma que trajo el `/auth/me` del login. Costo medido en dev: ~600ms extra por entrada.

## Cambio

Reconstruir el `User` localmente tras el select exitoso, sin `/auth/me`:

1. **`IAuthRepository.selectOrganization`**: `Either<AuthFailure, void>` → `Either<AuthFailure, OrganizationSessionModel>` — devuelve la sesión para que el cubit arme el user (la firma del use-case cambia igual).
2. **`User` (entity)**: agregar `copyWith` — hoy no existe y hace falta para el update en lugar.
3. **`AuthCubit`**: método nuevo `enterOrganizationWithSession(OrganizationSessionModel session)` — emite `AuthSuccess` con el user actual `copyWith`:
   - `token`/`refreshToken` = los del response (ya están en storage; el entity los refleja)
   - `organizationId`/`organizationName` = del response
   - `roles` = `[organizations.firstWhere(o => o.id == orgId).role]` — el rol de ESA quesera (si la org no está en la lista, se conservan los roles actuales)
   - `enteredOrg = true` (unifica con `enterOrganization()`)
   - `id`, `email`, `name`, `status`, `organizations` = sin cambio
4. **`QueseraSelectionCubit.select`**: en el success llamar `enterOrganizationWithSession(session)` en vez de `refreshSession()` + `enterOrganization()`. El camino "gratis" (JWT ya traía esa org) queda igual.

## Lo que NO cambia

- El POST `select-organization` sigue siendo el checkpoint de membresía (suspendida → 401 → la card reporta error; si la membresía murió, el próximo `/auth/me` natural la saca de la lista).
- `refreshSession()`/`getMe` siguen existiendo para login, restore y refresh de sesión — solo deja de llamarse en el select.
- Backend: cero cambios.

## Tests

- `quesera_selection_cubit_test`: select exitoso → `AuthSuccess` con org nueva + `enteredOrg` + rol de la org; verificar que NO se llamó refresh/getMe (mock del cubit o del repo según el harness actual).
- `auth_cubit_test`: `enterOrganizationWithSession` actualiza token/org/roles y prende `enteredOrg`.
- Ajustar specs del repo por el nuevo tipo de retorno.
