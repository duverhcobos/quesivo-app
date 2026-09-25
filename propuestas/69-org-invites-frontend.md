# Propuesta: Invitaciones a organización — aceptar/rechazar (capa personal) + cancelar (admin)

Compañera frontend del backend **072** (`link` → membresía `invited`,
consentimiento con sesión). Cubre las 4 piezas que faltan en la app:

1. **`/me.pendingInvites[]`** parseado al `User` — hoy el campo del
   backend se descarta en el modelo.
2. **Sección "Invitaciones" en la capa personal** (`/home`, arriba del
   selector de queseras): cards con Aceptar / Rechazar —
   `POST /auth/me/org-invites/:orgId/accept|decline`. Sin token en el
   mail: la membresía `invited` ES el estado.
3. **`MemberStatus.invited`** + ⋮ del listado con "Cancelar
   invitación" (`DELETE /auth/users/:id`) — solo invitaciones
   pendientes; suspend/rol/password se ocultan sobre `invitePending`
   (el backend los rechaza con 409 `MEMBERSHIP_INVITED`/`NOT_INVITED`
   de todos modos — la UI deja de ofrecer errores garantizados).
4. **Copy del flujo de vinculación**: `POST /users/link` ya no
   "vincula" — envía una invitación que el otro debe aceptar. El
   sheet, el speed dial y el toast reflejan la nueva semántica.
5. **Deep link `quesivo://org-invites`** (página `org-invite/` del
   mail) → `/home` — ahí vive la sección de invitaciones. No es una
   GoRoute real: el alias vive en `AuthGuard` y el service lo mapea.

## Decisiones de diseño

- **Sin `GET /me` extra tras aceptar/rechazar**: el backend ya mutó el
  estado — `AuthCubit` actualiza el `User` en el lugar
  (`applyOrgInviteAccepted`/`Declined` hacen `copyWith` sobre
  `organizations`/`pendingInvites`). Cero roundtrips, cero flash de
  `AuthLoading` (el `refreshSession` emitiría loading → el carousel
  vería estado vacío → flash de "no tenés queseras").
- **"Cancelable" = `invitePending`** (la unión del backend): membresía
  `invited` (link) O artefacto `pending_verification`+passwordless
  (alta invite). El ⋮ no distingue — el DELETE del backend cubre ambos
  (072: sobre el artefacto también borra la cuenta si era su única
  membresía).
- **Invitados en la lista**: `MemberStatus.invited` nuevo — el chip
  muestra "Invitado" (ámbar) en vez de parsear a `active` por el
  fallback. El badge ámbar "Invitación pendiente" se reserva al
  artefacto (membresía `active` + cuenta sin aceptar) — sobre invited
  sería redundante con el chip.
- **`INetworkService.delete`**: la capa de red no tiene DELETE — se
  agrega en las dos impls (dio + http) con el mismo molde de `patch`.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/network/interfaces/i_network_service.dart` | `delete<T>` |
| `lib/core/network/implementations/dio_network_service_impl.dart` | impl |
| `lib/core/network/implementations/http_network_service_impl.dart` | impl |
| `lib/features/auth/domain/entities/org_invite.dart` | **nuevo** — ítem de `pendingInvites[]` |
| `lib/features/auth/domain/entities/user.dart` | `pendingInvites` + copyWith/props |
| `lib/features/auth/data/models/user_model.dart` | parse + toJson |
| `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart` | `acceptOrgInvite`/`declineOrgInvite` |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | impl (POST sin body) |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | firma Either |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | impl + mapa de errores |
| `lib/features/auth/domain/failures/auth_failure.dart` | `OrgInviteNotFoundFailure` |
| `lib/features/auth/domain/use_cases/accept_org_invite_use_case.dart` | **nuevo** |
| `lib/features/auth/domain/use_cases/decline_org_invite_use_case.dart` | **nuevo** |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | `applyOrgInviteAccepted/Declined` |
| `lib/features/queseras/presentation/cubit/org_invites_cubit.dart` | **nuevo** |
| `lib/features/queseras/presentation/cubit/org_invites_state.dart` | **nuevo** |
| `lib/features/queseras/presentation/widgets/org_invite_card.dart` | **nuevo** |
| `lib/features/queseras/presentation/widgets/org_invites_section.dart` | **nuevo** — va en `home_tab` |
| `lib/features/home/presentation/screens/home_tab.dart` | inserta la sección |
| `lib/core/routes/auth_guard.dart` | `orgInvitesRoute` const |
| `lib/core/deeplink/app_links_deep_link_service_impl.dart` | alias → `/home` |
| `lib/features/users/domain/entities/org_member.dart` | `MemberStatus.invited` |
| `lib/features/users/presentation/widgets/member_status_chip.dart` | chip "Invitado" |
| `lib/features/users/presentation/widgets/member_actions_menu.dart` | cancel + gating invited |
| `lib/features/users/presentation/widgets/org_member_card.dart` | plumb `onCancelInvite` + badge solo en artefacto |
| `lib/features/users/presentation/widgets/users_list_body.dart` | plumb |
| `lib/features/users/presentation/screens/users_screen.dart` | `_cancelInvite` + toast |
| `lib/features/users/presentation/cubit/users_list_cubit.dart` | `cancelInvite` + `removeMember` |
| `lib/features/users/domain/use_cases/remove_org_member_use_case.dart` | **nuevo** |
| `lib/features/users/domain/repositories/i_users_repository.dart` | `removeMember` |
| `lib/features/users/data/repositories/users_repository_impl.dart` | impl + `MEMBERSHIP_NOT_INVITED` 409 |
| `lib/features/users/data/datasources/interfaces/i_remote_users_datasource.dart` | `removeMember` |
| `lib/features/users/data/datasources/implementations/remote_users_datasource_impl.dart` | impl DELETE |
| `lib/features/users/domain/failures/users_failure.dart` | `MemberNotInvitedFailure` |
| `lib/core/di/setup_di.dart` | use cases + `OrgInvitesCubit` + arg nuevo en `UsersListCubit` |
| `lib/l10n/app_es.arb` / `app_en.arb` / `app_pt.arb` | keys nuevas + reword del link |
| `Design/quesivo-design-system.yaml` (backend `Design/`) | spec de invite card + menú invited |

---

## 1. `INetworkService.delete` (actualización)

**Ruta:** `lib/core/network/interfaces/i_network_service.dart`

**Después** (tras `patch`):

```dart
  Future<T> patch<T>(String path, {Map<String, dynamic>? data});

  /// Sin body — el identificador viaja en el path (ej. `DELETE
  /// /auth/users/:id`, backend 072). Devuelve el body parseado si lo hay
  /// (los 204 llegan como null → `delete<void>`).
  Future<T> delete<T>(String path);
}
```

## 2. `DioNetworkServiceImpl.delete` (actualización)

**Ruta:** `lib/core/network/implementations/dio_network_service_impl.dart`

**Después** (tras `patch`, mismo molde):

```dart
  @override
  Future<T> delete<T>(String path) async {
    try {
      final response = await dio.delete<T>(path);
      return response.data as T;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw ServerException();
    }
  }
```

## 3. `HttpNetworkServiceImpl.delete` (actualización)

**Ruta:** `lib/core/network/implementations/http_network_service_impl.dart`

**Después** (tras `patch`):

```dart
  @override
  Future<T> delete<T>(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await client.delete(uri);
      return _processResponse<T>(response);
    } catch (e) {
      if (e is RestApiException) rethrow;
      throw ServerException();
    }
  }
```

> Nota: `_processResponse` hace `jsonDecode(response.body)` — un 204 con
> body vacío rompería el decode. Ajustar el guard arriba de la función:
>
> **Antes:**
> ```dart
>   T _processResponse<T>(http.Response response) {
>     if (response.statusCode >= 200 && response.statusCode < 300) {
>       return jsonDecode(response.body) as T;
> ```
>
> **Después:**
> ```dart
>   T _processResponse<T>(http.Response response) {
>     if (response.statusCode >= 200 && response.statusCode < 300) {
>       // 204 sin body (DELETE /users/:id, resend-invite) — decode del
>       // string vacío lanza FormatException; el caller pide void/null.
>       if (response.body.isEmpty) return null as T;
>       return jsonDecode(response.body) as T;
> ```

## 4. `org_invite.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/entities/org_invite.dart`

```dart
import 'package:equatable/equatable.dart';

/// Invitación pendiente a una organización — ítem de `pendingInvites[]`
/// de `GET /auth/me` (propuesta backend 072): alguien te vinculó con
/// `POST /auth/users/link` y tu membresía quedó `invited` hasta que la
/// aceptes o la rechaces con sesión (consentimiento — un typo de email
/// del admin ya no te mete adentro sin autorización).
///
/// `id` es el de la MEMBRESÍA; `organizationId` el path param de
/// accept/decline (`/auth/me/org-invites/:orgId/*`, docs 019/020).
class OrgInvite extends Equatable {
  final String id;
  final String organizationId;
  final String organizationName;
  final String role;

  const OrgInvite({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.role,
  });

  @override
  List<Object?> get props => [id, organizationId, organizationName, role];
}
```

## 5. `User.pendingInvites` (actualización)

**Ruta:** `lib/features/auth/domain/entities/user.dart`

**Antes:**

```dart
import 'package:equatable/equatable.dart';

import 'organization_summary.dart';
```

**Después:**

```dart
import 'package:equatable/equatable.dart';

import 'org_invite.dart';
import 'organization_summary.dart';
```

**Antes:**

```dart
  /// Queseras del usuario — solo llegan de `GET /auth/me` (propuesta
  /// backend 066). Con token personal `organizationId` es null: el user
  /// está autenticado pero fuera de toda quesera (capa personal).
  final List<OrganizationSummary> organizations;
```

**Después:**

```dart
  /// Queseras del usuario — solo llegan de `GET /auth/me` (propuesta
  /// backend 066). Con token personal `organizationId` es null: el user
  /// está autenticado pero fuera de toda quesera (capa personal).
  final List<OrganizationSummary> organizations;

  /// Invitaciones a queseras pendientes de responder — `pendingInvites`
  /// de `GET /auth/me` (backend 072): membresías `invited` que alguien
  /// creó con `POST /auth/users/link`. La capa personal las muestra como
  /// cards con Aceptar/Rechazar; al aceptar la org aparece en
  /// `organizations`.
  final List<OrgInvite> pendingInvites;
```

Constructor + copyWith + props: agregar `pendingInvites` con default
`const []` en el constructor, `List<OrgInvite>? pendingInvites` en
copyWith, y `pendingInvites` al final de `props` (mismo patrón que
`organizations`).

## 6. `UserModel` — parse de `pendingInvites` (actualización)

**Ruta:** `lib/features/auth/data/models/user_model.dart`

**Antes:**

```dart
      organizations:
          (json['organizations'] as List?)
              ?.map(
                (e) => OrganizationSummary(
                  id: e['id']?.toString() ?? '',
                  name: e['name'] ?? '',
                  role: e['role'] ?? '',
                ),
              )
              .toList() ??
          const [],
    );
  }
```

**Después:**

```dart
      organizations:
          (json['organizations'] as List?)
              ?.map(
                (e) => OrganizationSummary(
                  id: e['id']?.toString() ?? '',
                  name: e['name'] ?? '',
                  role: e['role'] ?? '',
                ),
              )
              .toList() ??
          const [],
      // Backend 072 — invitaciones a orgs pendientes (membresías
      // `invited`). Ausente en respuestas que no lo traen → [].
      pendingInvites:
          (json['pendingInvites'] as List?)
              ?.map(
                (e) => OrgInvite(
                  id: e['id']?.toString() ?? '',
                  organizationId: e['organizationId']?.toString() ?? '',
                  organizationName: e['organizationName']?.toString() ?? '',
                  role: e['role']?.toString() ?? '',
                ),
              )
              .toList() ??
          const [],
    );
  }
```

Y en `toJson`, tras `'organizations'`:

```dart
      'pendingInvites': pendingInvites
          .map(
            (i) => {
              'id': i.id,
              'organizationId': i.organizationId,
              'organizationName': i.organizationName,
              'role': i.role,
            },
          )
          .toList(),
```

+ `import '../../domain/entities/org_invite.dart';` arriba.

## 7. `IRemoteAuthDataSource` — accept/decline (actualización)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart`

**Después** (tras `resendVerification`):

```dart
  /// Reenvía el correo de verificación (`POST /auth/resend-verification`,
  /// doc 016). Siempre 200 — anti-enumeración.
  Future<void> resendVerification(String email);

  /// Acepta la invitación a una organización (`POST
  /// /auth/me/org-invites/:orgId/accept`, doc 019 — backend 072): la
  /// membresía `invited` pasa a `active` y la org aparece en
  /// `organizations` del próximo `/me`. 404 = ya no está pendiente
  /// (la declinaste o el admin la canceló — dato stale).
  Future<void> acceptOrgInvite(String organizationId);

  /// Rechaza la invitación (`POST /auth/me/org-invites/:orgId/decline`,
  /// doc 020 — backend 072): borra la membresía `invited` — el typo de
  /// email del admin se resuelve solo. 404 = idem accept.
  Future<void> declineOrgInvite(String organizationId);
}
```

## 8. `RemoteAuthDataSourceImpl` — impl (actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

**Después** (tras `resendVerification`):

```dart
  @override
  Future<void> acceptOrgInvite(String organizationId) async {
    // Contrato real (documentacion/api/auth/019-post-me-org-invites-
    // accept.md — backend 072): sesión personal u org-scoped — el
    // consentimiento es el JWT, sin token en el mail. 200 con body
    // {organizationId, organizationName, role} que la UI no necesita
    // (ya tiene la invitación completa en `pendingInvites`).
    await networkService.post<void>(
      '/auth/me/org-invites/$organizationId/accept',
    );
  }

  @override
  Future<void> declineOrgInvite(String organizationId) async {
    // Doc 020 — borra la membresía invited (204 sin body).
    await networkService.post<void>(
      '/auth/me/org-invites/$organizationId/decline',
    );
  }
}
```

## 9. `IAuthRepository` (actualización)

**Ruta:** `lib/features/auth/domain/repositories/i_auth_repository.dart`

**Después** (tras `resendVerification`):

```dart
  /// Reenvía el correo de verificación (`POST /auth/resend-verification`,
  /// doc 016). Siempre 200 — anti-enumeración.
  Future<Either<AuthFailure, void>> resendVerification(String email);

  /// `POST /auth/me/org-invites/:orgId/accept` (doc 019 — backend 072):
  /// activa la membresía `invited`. Errores: `OrgInviteNotFoundFailure`
  /// (404 — ya no está pendiente), `TooManyAttemptsFailure` (429),
  /// `NetworkFailure` sin conexión.
  Future<Either<AuthFailure, void>> acceptOrgInvite(String organizationId);

  /// `POST /auth/me/org-invites/:orgId/decline` (doc 020): borra la
  /// membresía `invited`. Mismos errores que accept.
  Future<Either<AuthFailure, void>> declineOrgInvite(String organizationId);
}
```

## 10. `AuthFailure` — `OrgInviteNotFoundFailure` (actualización)

**Ruta:** `lib/features/auth/domain/failures/auth_failure.dart`

**Después** (junto a `InvalidOrExpiredTokenFailure`):

```dart
/// La invitación a la org ya no existe (404 `ORG_INVITE_NOT_FOUND`,
/// backend 072): la declinaste/cancelaron entre el load y el tap —
/// dato stale; la UI refresca `pendingInvites` y muestra un toast.
class OrgInviteNotFoundFailure extends AuthFailure {
  const OrgInviteNotFoundFailure() : super('La invitación ya no existe.');
}
```

(Verificar la firma del constructor de `AuthFailure` — sigue el patrón
de las demás clases del archivo.)

## 11. `AuthRepositoryImpl` — accept/decline (actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Después** (tras `resendVerification`):

```dart
  @override
  Future<Either<AuthFailure, void>> acceptOrgInvite(
    String organizationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.acceptOrgInvite(organizationId);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      // 404 ORG_INVITE_NOT_FOUND — la invitación ya no está pendiente
      // (la declinaste en otro device o el admin la canceló): dato
      // stale, la sección se refresca tras el toast.
      if (e.statusCode == 404) {
        return const Left(OrgInviteNotFoundFailure());
      }
      if (e.statusCode == 429) {
        return const Left(TooManyAttemptsFailure());
      }
      logger.error(
        'Error de API al aceptar invitación de organización',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al aceptar invitación de organización',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, void>> declineOrgInvite(
    String organizationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.declineOrgInvite(organizationId);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      if (e.statusCode == 404) {
        return const Left(OrgInviteNotFoundFailure());
      }
      if (e.statusCode == 429) {
        return const Left(TooManyAttemptsFailure());
      }
      logger.error(
        'Error de API al rechazar invitación de organización',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al rechazar invitación de organización',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }
}
```

## 12. `accept_org_invite_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/accept_org_invite_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: aceptar la invitación a una organización (`POST
/// /auth/me/org-invites/:orgId/accept`, doc 019 — backend 072). La
/// membresía `invited` pasa a `active`; la UI actualiza el `User` en
/// el lugar (la org aparece como card "Entrar" sin `GET /me` extra).
class AcceptOrgInviteUseCase {
  final IAuthRepository repository;

  const AcceptOrgInviteUseCase(this.repository);

  Future<Either<AuthFailure, void>> call(String organizationId) {
    return repository.acceptOrgInvite(organizationId);
  }
}
```

## 13. `decline_org_invite_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/decline_org_invite_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: rechazar la invitación a una organización (`POST
/// /auth/me/org-invites/:orgId/decline`, doc 020 — backend 072). Borra
/// la membresía `invited` — el typo de email del admin se resuelve
/// desde el lado del invitado.
class DeclineOrgInviteUseCase {
  final IAuthRepository repository;

  const DeclineOrgInviteUseCase(this.repository);

  Future<Either<AuthFailure, void>> call(String organizationId) {
    return repository.declineOrgInvite(organizationId);
  }
}
```

## 14. `AuthCubit` — update en el lugar tras accept/decline (actualización)

**Ruta:** `lib/features/auth/presentation/cubit/auth_cubit.dart`

Importar `../../domain/entities/org_invite.dart`. Después de
`exitOrganization`:

```dart
  /// El usuario aceptó la invitación de una org (backend 072 — doc
  /// 019): la membresía quedó `active` server-side; acá se mueve la
  /// invitación de `pendingInvites` a `organizations` en el lugar —
  /// la card "Entrar" aparece sin `GET /me` extra ni flash de
  /// `AuthLoading` (el storage cacheado queda stale solo hasta el
  /// próximo /me natural — el backend ya mutó, no hay drift real).
  void applyOrgInviteAccepted(OrgInvite invite) {
    final current = state;
    if (current is! AuthSuccess) return;
    emit(
      AuthSuccess(
        current.user.copyWith(
          organizations: [
            ...current.user.organizations,
            OrganizationSummary(
              id: invite.organizationId,
              name: invite.organizationName,
              role: invite.role,
            ),
          ],
          pendingInvites: current.user.pendingInvites
              .where((i) => i.id != invite.id)
              .toList(),
        ),
        enteredOrg: current.enteredOrg,
      ),
    );
  }

  /// Decline (doc 020): la membresía `invited` se borró server-side —
  /// la invitación sale de `pendingInvites` en el lugar.
  void applyOrgInviteDeclined(OrgInvite invite) {
    final current = state;
    if (current is! AuthSuccess) return;
    emit(
      AuthSuccess(
        current.user.copyWith(
          pendingInvites: current.user.pendingInvites
              .where((i) => i.id != invite.id)
              .toList(),
        ),
        enteredOrg: current.enteredOrg,
      ),
    );
  }
```

Verificar `AuthSuccess` — si el constructor no recibe `enteredOrg` con
ese nombre ajustar al real (`AuthSuccess(user, enteredOrg: ...)` según
`enterOrganization`).

## 15. `org_invites_cubit.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/cubit/org_invites_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/org_invite.dart';
import '../../../auth/domain/use_cases/accept_org_invite_use_case.dart';
import '../../../auth/domain/use_cases/decline_org_invite_use_case.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import 'org_invites_state.dart';

/// Orquesta Aceptar/Rechazar sobre una card de invitación de la capa
/// personal (backend 072). Mismo molde que `QueseraSelectionCubit`:
/// no decide navegación — resuelve el POST y reporta loading/error por
/// card; en éxito el `AuthCubit` mueve el ítem entre `pendingInvites`
/// y `organizations` en el lugar (sin `GET /me` extra).
class OrgInvitesCubit extends Cubit<OrgInvitesState> {
  final AcceptOrgInviteUseCase _acceptOrgInvite;
  final DeclineOrgInviteUseCase _declineOrgInvite;
  final AuthCubit _authCubit;

  OrgInvitesCubit(this._acceptOrgInvite, this._declineOrgInvite, this._authCubit)
    : super(const OrgInvitesState());

  /// POST /auth/me/org-invites/:orgId/accept → invited pasa a active.
  /// Devuelve `true` si quedó aceptada (la sección muestra el toast de
  /// "ya sos parte de X"); error → `errorMessage` para el listener.
  Future<bool> accept(OrgInvite invite) async {
    if (state.isResponding) return false;
    emit(state.copyWith(respondingId: invite.id, clearError: true));

    final result = await _acceptOrgInvite(invite.organizationId);
    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(
          state.copyWith(clearResponding: true, errorMessage: failure.message),
        );
        return false;
      },
      (_) {
        _authCubit.applyOrgInviteAccepted(invite);
        emit(state.copyWith(clearResponding: true));
        return true;
      },
    );
  }

  /// POST /auth/me/org-invites/:orgId/decline → borra la membresía
  /// invited (el typo del admin se resuelve desde acá). En éxito la
  /// card desaparece — sin toast de "éxito" en una negativa, la
  /// desaparición ES el feedback.
  Future<bool> decline(OrgInvite invite) async {
    if (state.isResponding) return false;
    emit(state.copyWith(respondingId: invite.id, clearError: true));

    final result = await _declineOrgInvite(invite.organizationId);
    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(
          state.copyWith(clearResponding: true, errorMessage: failure.message),
        );
        return false;
      },
      (_) {
        _authCubit.applyOrgInviteDeclined(invite);
        emit(state.copyWith(clearResponding: true));
        return true;
      },
    );
  }
}
```

## 16. `org_invites_state.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/cubit/org_invites_state.dart`

```dart
import 'package:equatable/equatable.dart';

/// Estado de las cards de invitación (capa personal, backend 072).
/// `respondingId` = qué card está resolviendo accept/decline (spinner
/// en su botón y resto inerte); `errorMessage` dispara el toast de la
/// sección vía listener.
class OrgInvitesState extends Equatable {
  final String? respondingId;
  final String? errorMessage;

  const OrgInvitesState({this.respondingId, this.errorMessage});

  bool get isResponding => respondingId != null;

  OrgInvitesState copyWith({
    String? respondingId,
    String? errorMessage,
    bool clearResponding = false,
    bool clearError = false,
  }) {
    return OrgInvitesState(
      respondingId: clearResponding
          ? null
          : (respondingId ?? this.respondingId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [respondingId, errorMessage];
}
```

## 17. `org_invite_card.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/widgets/org_invite_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../auth/domain/entities/org_invite.dart';
import 'role_label_for.dart';

/// Card de una invitación pendiente a una quesera (backend 072) — la
/// capa personal la lista en `OrgInvitesSection`. Lenguaje de la card
/// "Entrar" (crema + chip de rol navy + borde amarillo suave) pero con
/// acciones explícitas en vez de tap-en-toda-la-card: "Aceptar" (pill
/// amarillo navy) y "Rechazar" (texto secundario — negativa no
/// destructiva, sin rojo: no es suspender, es "no gracias").
/// `responding` muestra loader y bloquea ambos botones; `enabled` cae
/// a false mientras OTRA invitación responde (una a la vez).
class OrgInviteCard extends StatelessWidget {
  const OrgInviteCard({
    super.key,
    required this.invite,
    required this.responding,
    required this.enabled,
    required this.onAccept,
    required this.onDecline,
  });

  final OrgInvite invite;

  /// Esta card está resolviendo accept/decline.
  final bool responding;

  /// false mientras cualquier card está respondiendo.
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.quesivoCream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.quesivoYellow.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.orgInviteCardTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.quesivoTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invite.organizationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.quesivoNavy,
                      ),
                    ),
                  ],
                ),
              ),
              // Mismo chip de rol navy+punto-amarillo de la card Entrar.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.quesivoNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.quesivoYellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.roleLabelFor(invite.role),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.quesivoWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (responding)
            const Center(child: QuesivoLoader(size: 22))
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: enabled ? onDecline : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.quesivoIconSurface,
                      foregroundColor: AppColors.quesivoNavy,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.orgInviteDeclineCta, maxLines: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: enabled ? onAccept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.quesivoYellow,
                      foregroundColor: AppColors.quesivoNavy,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.orgInviteAcceptCta, maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

## 18. `org_invites_section.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/widgets/org_invites_section.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../../../auth/domain/entities/org_invite.dart';
import '../../../auth/domain/failures/auth_failure.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/org_invites_cubit.dart';
import '../cubit/org_invites_state.dart';
import 'org_invite_card.dart';

/// Sección "Invitaciones" de la capa personal (`/home` sin quesera
/// activa ni entrando): lista las `pendingInvites` del `User` como
/// `OrgInviteCard` con Aceptar/Rechazar (backend 072). Se auto-oculta
/// cuando la lista está vacía — el /home del admin sin invitaciones no
/// cambia en nada.
///
/// El cubit es factory y vive acá — nace y muere con la sección (mismo
/// criterio que `QueseraSelectionCubit` en el carousel). En éxito el
/// `AuthCubit` actualiza el `User` en el lugar → la card desaparece
/// (decline) o la org aparece como "Entrar" en el selector (accept);
/// en 404 la lista también se refresca — la invitación ya no existía.
class OrgInvitesSection extends StatelessWidget {
  const OrgInvitesSection({super.key});

  String _errorText(AppLocalizations l10n, OrgInvitesState state) {
    // 404 = la invitación ya no existe (dato stale — declinada en otro
    // device o cancelada por el admin). El mensaje viene del failure;
    // los demás caen al genérico de la card.
    return state.errorMessage ?? l10n.genericError;
  }

  @override
  Widget build(BuildContext context) {
    final invites = context.select<AuthCubit, List<OrgInvite>>(
      (c) => c.state is AuthSuccess
          ? (c.state as AuthSuccess).user.pendingInvites
          : const <OrgInvite>[],
    );
    if (invites.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => locator<OrgInvitesCubit>(),
      child: BlocConsumer<OrgInvitesCubit, OrgInvitesState>(
        listenWhen: (p, c) => c.errorMessage != null,
        listener: (context, state) {
          QuesivoToast.error(context, message: _errorText(l10n, state));
          // El 404 ya resolvió server-side (la membresía ya no existe) —
          // el refresh del próximo /me la saca; sin acción extra acá.
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.orgInvitesSectionTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quesivoNavy,
                  ),
                ),
                const SizedBox(height: 10),
                for (final invite in invites) ...[
                  OrgInviteCard(
                    invite: invite,
                    responding: state.respondingId == invite.id,
                    enabled: !state.isResponding,
                    onAccept: () async {
                      final ok = await context
                          .read<OrgInvitesCubit>()
                          .accept(invite);
                      if (ok && context.mounted) {
                        QuesivoToast.success(
                          context,
                          message: l10n.orgInviteAcceptedFeedback(
                            invite.organizationName,
                          ),
                        );
                      }
                    },
                    onDecline: () =>
                        context.read<OrgInvitesCubit>().decline(invite),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
```

> Si el lint marca `use_build_context_synchronously` en `onAccept` por
> el toast tras el `await`, capturar `final cubit = context.read<…>()`
> antes del await y hacer el toast con el `context` del builder externo
> (la sección sigue montada — `invites` vive en `AuthCubit`, no en el
> cubit efímero). Ajustar en implementación según el warning real.

## 19. `home_tab.dart` — insertar la sección (actualización)

**Ruta:** `lib/features/home/presentation/screens/home_tab.dart`

**Antes:**

```dart
        const SizedBox(height: 20),
        const QueseraHeroCarousel(),
        const SizedBox(height: 24),
```

**Después:**

```dart
        const SizedBox(height: 20),
        // §69 — invitaciones pendientes primero (accionables): aceptar
        // hace aparecer la card "Entrar" en el selector de abajo.
        const OrgInvitesSection(),
        const QueseraHeroCarousel(),
        const SizedBox(height: 24),
```

+ `import '../../../queseras/presentation/widgets/org_invites_section.dart';`

## 20. `AuthGuard.orgInvitesRoute` (actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

**Después** (junto a `acceptInviteRoute`):

```dart
  // Aceptación de invitación por correo (Email-C, propuesta 68 — doc
  // 017): el link del email abre acá con `?token=…&email=…`.
  static const String acceptInviteRoute = '/accept-invite';
  // Deep link del mail de invitación a organización (backend 072):
  // `quesivo://org-invites` → la sección de invitaciones vive en /home
  // — no es una GoRoute real, el deep-link service la mapea a homeRoute
  // y el guard ya bota al login si no hay sesión.
  static const String orgInvitesRoute = '/org-invites';
```

NO va en `publicRoutes` — no es una ruta navegable, solo el alias del
deep link.

## 21. Deep link service — alias `org-invites` (actualización)

**Ruta:** `lib/core/deeplink/app_links_deep_link_service_impl.dart`

**Antes:**

```dart
    const knownRoutes = {
      AuthGuard.resetPasswordRoute,
      AuthGuard.verifyEmailRoute,
      AuthGuard.acceptInviteRoute,
    };
    if (!knownRoutes.contains(path)) {
      _logger.warning('Deep link con ruta desconocida ignorado: $path');
      return;
    }

    final target = uri.query.isEmpty ? path : '$path?${uri.query}';
    router.go(target);
```

**Después:**

```dart
    const knownRoutes = {
      AuthGuard.resetPasswordRoute,
      AuthGuard.verifyEmailRoute,
      AuthGuard.acceptInviteRoute,
      AuthGuard.orgInvitesRoute,
    };
    if (!knownRoutes.contains(path)) {
      _logger.warning('Deep link con ruta desconocida ignorado: $path');
      return;
    }

    // `/org-invites` es alias, no ruta real: las invitaciones viven en
    // la sección de la capa personal — el mail del org-invite aterriza
    // en /home (sin sesión el guard bota a welcome/login igual).
    if (path == AuthGuard.orgInvitesRoute) {
      router.go(AuthGuard.homeRoute);
      return;
    }

    final target = uri.query.isEmpty ? path : '$path?${uri.query}';
    router.go(target);
```

## 22. `MemberStatus.invited` (actualización)

**Ruta:** `lib/features/users/domain/entities/org_member.dart`

**Antes:**

```dart
enum MemberStatus {
  active('active'),
  suspended('suspended');
```

**Después:**

```dart
enum MemberStatus {
  active('active'),
  suspended('suspended'),
  // Backend 072: membresía de vinculación sin aceptar — el ⋮ solo
  // ofrece reenviar/cancelar y el chip muestra "Invitado" (ámbar).
  invited('invited');
```

Y en el docstring de `status` del `OrgMember`: "active/suspended/
invited (backend 072)".

## 23. `member_status_chip.dart` — chip "Invitado" (actualización)

**Ruta:** `lib/features/users/presentation/widgets/member_status_chip.dart`

**Antes:**

```dart
    final (color, label) = switch (status) {
      MemberStatus.active => (
        AppColors.quesivoSuccess,
        l10n.memberStatusActive,
      ),
      MemberStatus.suspended => (
        AppColors.quesivoError,
        l10n.memberStatusSuspended,
      ),
    };
```

**Después:**

```dart
    final (color, label, textColor) = switch (status) {
      MemberStatus.active => (
        AppColors.quesivoSuccess,
        l10n.memberStatusActive,
        AppColors.quesivoSuccess,
      ),
      MemberStatus.suspended => (
        AppColors.quesivoError,
        l10n.memberStatusSuspended,
        AppColors.quesivoError,
      ),
      // §69 — backend 072: tinte ámbar + texto amber-deep (la lectura
      // sobre el tinte claro exige el deep, no el warning puro — mismo
      // criterio del _PendingInviteBadge).
      MemberStatus.invited => (
        AppColors.quesivoWarning,
        l10n.memberStatusInvited,
        AppColors.quesivoAmberDeep,
      ),
    };
```

y usar `textColor` en el `Text(label)` (el punto sigue con `color`).

## 24. `member_actions_menu.dart` — cancelar + gating invited (actualización)

**Ruta:** `lib/features/users/presentation/widgets/member_actions_menu.dart`

- Constructor: nuevo `required this.onCancelInvite` (`VoidCallback`).
- Doc comment: §69 — sobre `invitePending` el menú solo ofrece
  Reenviar/Cancelar (suspend/rol/password son errores garantizados:
  `MEMBERSHIP_INVITED`/`NOT_INVITED` en backend).
- `_onSelected`: nuevo caso `'cancel'` que abre un confirm dialog
  (destructiva suave — la invitación se borra):

```dart
      case 'cancel':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.quesivoWhite,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(l10n.cancelInviteConfirmTitle),
            content: Text(l10n.cancelInviteConfirmBody(member.email)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancelAction),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  l10n.cancelInviteAction,
                  style: const TextStyle(color: AppColors.quesivoError),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) onCancelInvite();
```

- `itemBuilder`: sobre `member.invitePending` SOLO "Reenviar
  invitación" + "Cancelar invitación"; los ítems status/role/password
  quedan `if (!member.invitePending)`. La cancelación va con ícono
  `Icons.cancel_outlined` en `quesivoError` (es la única acción
  destructiva del modo invitado):

```dart
      itemBuilder: (context) => [
        // §68 — reenvío (gate unión: link-invited O artefacto pending).
        if (member.invitePending)
          PopupMenuItem<String>(
            value: 'invite',
            child: /* igual que hoy */,
          ),
        // §69 — cancelación: solo con invitación pendiente; destructiva
        // suave (rojo) con confirmación — borra la membresía invited o
        // el artefacto completo si era su única membresía (backend 072).
        if (member.invitePending)
          PopupMenuItem<String>(
            value: 'cancel',
            child: Row(
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  size: 20,
                  color: AppColors.quesivoError,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.cancelInviteAction,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.quesivoError,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // §69 — suspend/rol/password NO sobre invitaciones pendientes:
        // el backend rechaza invited con 409 (MEMBERSHIP_INVITED) y
        // sobre el artefacto no tienen sentido (nunca logueó).
        if (!member.invitePending) ...[
          PopupMenuItem<String>(value: 'status', child: /* igual que hoy */),
          PopupMenuItem<String>(value: 'role', child: /* igual que hoy */),
          PopupMenuItem<String>(value: 'password', child: /* igual que hoy */),
        ],
      ],
```

## 25. `org_member_card.dart` — plumb + badge solo artefacto (actualización)

**Ruta:** `lib/features/users/presentation/widgets/org_member_card.dart`

- Constructor + param: `required this.onCancelInvite` (`VoidCallback`)
  → pásalo al `MemberActionsMenu`.
- Badge: `if (member.invitePending && member.status != MemberStatus.invited)`
  — sobre membresía `invited` el chip "Invitado" ya dice lo mismo (un
  solo marcador ámbar por fila).

## 26. `users_list_body.dart` — plumb (actualización)

**Ruta:** `lib/features/users/presentation/widgets/users_list_body.dart`

- Param `required this.onCancelInvite` (`ValueChanged<OrgMember>`) +
  doc.
- En la card: `onCancelInvite: () => onCancelInvite(member)`.

## 27. `users_list_cubit.dart` — `cancelInvite` + `removeMember` (actualización)

**Ruta:** `lib/features/users/presentation/cubit/users_list_cubit.dart`

- Constructor: `RemoveOrgMemberUseCase` quinto dep (registrar en DI).
- `removeMember(String id)` — splice local + `total - 1`:

```dart
  /// Saca la fila del dataset (DELETE 204 — §69): la invitación
  /// cancelada desaparece del listado sin refetch; `total - 1` mantiene
  /// el contador del header consistente.
  void removeMember(String id) {
    if (isClosed) return;
    final before = state.members.length;
    final members = state.members.where((m) => m.id != id).toList();
    if (members.length == before) return;
    emit(
      state.copyWith(
        members: members,
        total: state.total > 0 ? state.total - 1 : 0,
      ),
    );
  }
```

- `cancelInvite(OrgMember)` — mismo contrato que `resendInvite`
  (busy + Either a la screen), pero en éxito llama `removeMember`:

```dart
  /// `DELETE /auth/users/:id` real (§69, doc 021): cancela la
  /// invitación pendiente — cubre ambos casos de `invitePending`
  /// (membresía invited y artefacto pending+passwordless). En éxito la
  /// fila sale del listado vía `removeMember`.
  Future<Either<UsersFailure, void>> cancelInvite(OrgMember member) async {
    if (state.busyMemberIds.contains(member.id)) {
      return const Right(null);
    }
    emit(state.copyWith(busyMemberIds: {...state.busyMemberIds, member.id}));
    final result = await _removeOrgMember(userId: member.id);
    if (isClosed) return result;
    emit(
      state.copyWith(
        busyMemberIds: {...state.busyMemberIds}..remove(member.id),
      ),
    );
    switch (result) {
      case Right():
        removeMember(member.id);
      case Left():
        break;
    }
    return result;
  }
```

## 28. `remove_org_member_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/use_cases/remove_org_member_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Caso de Uso: cancelar la invitación pendiente de un miembro
/// (`DELETE /auth/users/:id`, doc 021 — backend 072). Cubre la unión
/// `invitePending`: membresía `invited` (link) o artefacto
/// pending+passwordless (alta por correo). Sobre el artefacto también
/// cae la cuenta si era su única membresía.
class RemoveOrgMemberUseCase {
  final IUsersRepository repository;

  const RemoveOrgMemberUseCase(this.repository);

  Future<Either<UsersFailure, void>> call({required String userId}) {
    return repository.removeMember(userId: userId);
  }
}
```

## 29. `IUsersRepository.removeMember` (actualización)

**Ruta:** `lib/features/users/domain/repositories/i_users_repository.dart`

**Después** (tras `resendInvite`):

```dart
  /// `DELETE /auth/users/:id` — cancela la invitación pendiente (doc
  /// 021, backend 072). Errores: `MemberNotFoundFailure` (404 — IDOR
  /// o ya declinada), `MemberNotInvitedFailure` (409 — ya no es una
  /// invitación pendiente; para sacar acceso se suspende), 403/429/red.
  Future<Either<UsersFailure, void>> removeMember({required String userId});
```

## 30. `MemberNotInvitedFailure` (actualización)

**Ruta:** `lib/features/users/domain/failures/users_failure.dart`

**Después** (junto a `InviteNotPendingFailure`):

```dart
/// `DELETE /auth/users/:id` sobre una membresía que ya no es una
/// invitación pendiente (409 `MEMBERSHIP_NOT_INVITED`, backend 072) —
/// llega solo con data stale (aceptó o ya se canceló en otro lado).
class MemberNotInvitedFailure extends UsersFailure {
  const MemberNotInvitedFailure();
}
```

(Verificar constructor base de `UsersFailure` — seguir el patrón del
archivo.)

## 31. `IRemoteUsersDataSource.removeMember` (actualización)

**Ruta:** `lib/features/users/data/datasources/interfaces/i_remote_users_datasource.dart`

```dart
  /// `DELETE /auth/users/:id` real (doc 021) — 204 sin body.
  Future<void> removeMember({required String userId});
```

## 32. `RemoteUsersDataSourceImpl.removeMember` (actualización)

**Ruta:** `lib/features/users/data/datasources/implementations/remote_users_datasource_impl.dart`

```dart
  /// `DELETE /auth/users/:id` real (doc 021 — backend 072): cancela la
  /// invitación pendiente; la org la infiere el backend del JWT.
  @override
  Future<void> removeMember({required String userId}) async {
    await networkService.delete<void>('/auth/users/$userId');
  }
```

## 33. `UsersRepositoryImpl.removeMember` + mapa 409 (actualización)

**Ruta:** `lib/features/users/data/repositories/users_repository_impl.dart`

```dart
  /// `DELETE /auth/users/:id` — doc 021 (backend 072): cancela la
  /// invitación pendiente (unión invitePending). 204 sin body;
  /// `MEMBERSHIP_NOT_INVITED` (409) si ya no está pendiente — llega
  /// solo con data stale.
  @override
  Future<Either<UsersFailure, void>> removeMember({
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }
    try {
      await remoteDataSource.removeMember(userId: userId);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado cancelando invitación',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }
```

Y en el switch 409 de `_mapError`:

```dart
          'MEMBERSHIP_NOT_INVITED' => const MemberNotInvitedFailure(),
```

## 34. `users_screen.dart` — `_cancelInvite` (actualización)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

```dart
  /// §69 — cancelación REAL vía `DELETE /auth/users/:id`: el ⋮ ya pidió
  /// confirmación (CancelInviteDialog del menú); el cubit pone la card
  /// en busy, en 204 la fila sale del listado y el toast avisa.
  Future<void> _cancelInvite(OrgMember member) async {
    final result = await context.read<UsersListCubit>().cancelInvite(member);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (result) {
      case Left(value: final failure):
        QuesivoToast.error(
          context,
          message: _memberActionErrorText(l10n, failure),
        );
      case Right():
        QuesivoToast.success(
          context,
          message: l10n.inviteCancelledFeedback,
        );
    }
  }
```

- En `_memberActionErrorText`: `MemberNotInvitedFailure() => l10n.memberNotInvitedError`.
- En el `UsersListBody`: `onCancelInvite: _cancelInvite`.
- Doc comment de `_openLinkUserSheet`: el 201 ya no "vinculó" — envió
  la invitación (`linked:true` sigue marcando "cuenta existente"); el
  toast pasa a `inviteLinkSentFeedback`.

**Antes:**

```dart
    QuesivoToast.info(
      context,
      message: AppLocalizations.of(context)!.memberLinkedFeedback(linked.name),
    );
```

**Después:**

```dart
    QuesivoToast.info(
      context,
      message: AppLocalizations.of(context)!.inviteLinkSentFeedback(linked.name),
    );
```

## 35. `setup_di.dart` (actualización)

**Ruta:** `lib/core/di/setup_di.dart`

```dart
  // §69 — invitaciones de org (backend 072): accept/decline de la capa
  // personal + cancelación admin.
  locator.registerLazySingleton(
    () => AcceptOrgInviteUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => DeclineOrgInviteUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => RemoveOrgMemberUseCase(locator<IUsersRepository>()),
  );
```

- `QueseraSelectionCubit` sigue igual; registrar `OrgInvitesCubit`
  factory junto a él:

```dart
  // §69 — cards de invitación de la capa personal: factory, nace y
  // muere con OrgInvitesSection.
  locator.registerFactory(
    () => OrgInvitesCubit(
      locator<AcceptOrgInviteUseCase>(),
      locator<DeclineOrgInviteUseCase>(),
      locator<AuthCubit>(),
    ),
  );
```

- `UsersListCubit` gana el quinto dep:

```dart
  locator.registerFactory(
    () => UsersListCubit(
      locator<ListUsersUseCase>(),
      locator<UpdateUserStatusUseCase>(),
      locator<UpdateUserRoleUseCase>(),
      locator<ResendInviteUseCase>(),
      locator<RemoveOrgMemberUseCase>(),
    ),
  );
```

(Verificar la firma actual del registerFactory de `UsersListCubit` —
puede ya tener args extra; insertar el nuevo al final.)

+ imports: `OrgInvitesCubit`, `AcceptOrgInviteUseCase`,
  `DeclineOrgInviteUseCase`, `RemoveOrgMemberUseCase`.

## 36. i18n — ARB ×3

**Rutas:** `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_pt.arb`

Nuevas keys:

```json
  "orgInvitesSectionTitle": "Invitaciones",
  "orgInviteCardTitle": "Te invitaron a unirte",
  "orgInviteAcceptCta": "Aceptar",
  "orgInviteDeclineCta": "Rechazar",
  "orgInviteAcceptedFeedback": "Ya sos parte de {org}",
  "@orgInviteAcceptedFeedback": { "placeholders": { "org": {} } },
  "orgInviteGoneError": "La invitación ya no existe — actualizá y revisá de nuevo",
  "memberStatusInvited": "Invitado",
  "cancelInviteAction": "Cancelar invitación",
  "cancelInviteConfirmTitle": "¿Cancelar la invitación?",
  "cancelInviteConfirmBody": "{email} no va a recibir ni usar esta invitación — si vuelve a intentarlo, generá una nueva.",
  "@cancelInviteConfirmBody": { "placeholders": { "email": {} } },
  "memberNotInvitedError": "Ya no hay una invitación pendiente para este usuario",
  "inviteCancelledFeedback": "Invitación cancelada",
  "inviteLinkSentFeedback": "Invitación enviada — {name} entra cuando la acepte",
  "@inviteLinkSentFeedback": { "placeholders": { "name": {} } },
```

en:

```json
  "orgInvitesSectionTitle": "Invitations",
  "orgInviteCardTitle": "You were invited to join",
  "orgInviteAcceptCta": "Accept",
  "orgInviteDeclineCta": "Decline",
  "orgInviteAcceptedFeedback": "You're now part of {org}",
  "orgInviteGoneError": "The invitation no longer exists — refresh and check again",
  "memberStatusInvited": "Invited",
  "cancelInviteAction": "Cancel invitation",
  "cancelInviteConfirmTitle": "Cancel the invitation?",
  "cancelInviteConfirmBody": "{email} won't be able to use this invitation — if they try again, send a new one.",
  "memberNotInvitedError": "There's no pending invitation for this user anymore",
  "inviteCancelledFeedback": "Invitation cancelled",
  "inviteLinkSentFeedback": "Invitation sent — {name} gets in once they accept",
```

pt:

```json
  "orgInvitesSectionTitle": "Convites",
  "orgInviteCardTitle": "Você foi convidado para",
  "orgInviteAcceptCta": "Aceitar",
  "orgInviteDeclineCta": "Recusar",
  "orgInviteAcceptedFeedback": "Agora você faz parte de {org}",
  "orgInviteGoneError": "O convite não existe mais — atualize e verifique de novo",
  "memberStatusInvited": "Convidado",
  "cancelInviteAction": "Cancelar convite",
  "cancelInviteConfirmTitle": "Cancelar o convite?",
  "cancelInviteConfirmBody": "{email} não poderá usar este convite — se tentar de novo, envie um novo.",
  "memberNotInvitedError": "Não há mais um convite pendente para este usuário",
  "inviteCancelledFeedback": "Convite cancelado",
  "inviteLinkSentFeedback": "Convite enviado — {name} entra quando aceitar",
```

Reword de keys existentes (link ya no vincula — invita):

| Key | es antes | es nuevo |
|-----|----------|----------|
| `fabLinkUser` | "Vincular existente" | "Invitar existente" |
| `linkUserSheetTitle` | "Vincular usuario" | "Invitar usuario existente" |
| `linkUserSheetHint` | "El correo ya tiene cuenta en Quesivo — se vincula a tu quesera y conserva su contraseña actual" | "El correo ya tiene cuenta en Quesivo — le llega una invitación por mail y entra a tu quesera cuando la acepte" |
| `linkUserSubmit` | "Vincular" | "Enviar invitación" |

(en/pt: traducir el mismo sentido — "Invite existing" / "Convidar
existente" etc.) `memberLinkedFeedback` muere (reemplazada por
`inviteLinkSentFeedback`) — borrarla de los 3 ARB si no quedan
referencias.

Ejecutar `flutter gen-l10n` al final.

## 37. Design system

Actualizar `Design/quesivo-design-system.yaml` (raíz del backend, spec
compartido): nueva spec `org-invite-card` + `org-invites-section`
(zona de la capa personal, arriba del selector), el menú ⋮ en modo
invitado (solo reenviar/cancelar), chip "Invitado" ámbar, y el reword
del link sheet. Bump de versión + changelog siguiendo la convención
del archivo.

## 38. Tests

- `user_model` — `pendingInvites` parsea y toJson lo roundtrippea.
- `org_member_model` — `status: 'invited'` → `MemberStatus.invited`.
- `org_invites_cubit` — accept ok → `applyOrgInviteAccepted` llamado,
  `respondingId` limpio; accept falla → errorMessage; decline idem;
  `isResponding` bloquea el segundo tap.
- `users_list_cubit.cancelInvite` — 204 → `removeMember` sacó la fila;
  409 → failure y la fila sigue.
- `users_repository_impl.removeMember` — 409 `MEMBERSHIP_NOT_INVITED`
  → `MemberNotInvitedFailure`.
- `member_actions_menu` — sobre `invitePending` solo reenviar+cancelar;
  cancel pide confirmación antes de notificar.
- `org_invites_section` — vacío → `SizedBox.shrink`; con invites →
  cards con org name + rol.
- deep link — `quesivo://org-invites` → `router.go('/home')`.

---

## Orden de aplicación

1. Base de red: `i_network_service` + 2 impls (`delete`) + guard 204.
2. `org_invite.dart` → `user.dart` → `user_model.dart` (`pendingInvites`).
3. Stack auth: datasource interface + impl → repository interface +
   impl → `OrgInviteNotFoundFailure` → use cases → `auth_cubit`.
4. Stack queseras: `org_invites_state` → `org_invites_cubit` →
   `org_invite_card` → `org_invites_section` → `home_tab`.
5. Deep link: `auth_guard` const + service alias.
6. Stack users: `MemberStatus.invited` → chip → menú → card → body →
   screen → cubit (+`removeMember`) → repo interface/impl → datasource
   interface/impl → `RemoveOrgMemberUseCase` → `MemberNotInvitedFailure`.
7. `setup_di` (registrations + `UsersListCubit` arg).
8. ARB ×3 + `flutter gen-l10n` + reword link sheet.
9. Tests + `dart format` + `flutter analyze` + `flutter test`.
10. Design yaml.
