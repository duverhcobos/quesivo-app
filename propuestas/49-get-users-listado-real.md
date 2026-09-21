# Propuesta 49 — `GET /auth/users`: listado real con paginación server-side + badge Dueño

**Estado:** Propuesta — pendiente de implementación
**Fecha:** 2026-09-20
**Depende de:** propuesta backend **059** — `GET /auth/users` gana
`?search=&role=&status=` (decisión del usuario: paginación real, no
"cargar todo y filtrar local").

## Contexto

`UsersScreen` pinta `generateSampleOrgMembers()` (54 sintéticos) con
búsqueda/filtro/chunking local. El backend sirve `GET
/auth/users?page=&limit=` → `{items: [{id,email,name,role,status,
lastLoginAt,isOwner}], meta:{page,limit,total,totalPages}}`, org del
JWT, orden `created_at ASC` + tiebreaker `id`.

Con la 059, la búsqueda y el chip de rol viajan en el query — el
scroll sigue cargando páginas reales.

## Modelo de estado

`UsersListCubit` + `UsersListState` (nuevos — espejo del patrón del
módulo):

```dart
enum UsersListStatus { initial, loading, loaded, error }

class UsersListState extends Equatable {
  final UsersListStatus status;
  final List<OrgMember> members;   // páginas acumuladas
  final int total;                 // meta.total (refleja filtros)
  final int page;                  // última página cargada
  final bool hasMore;              // page < totalPages
  final bool isLoadingMore;        // fetch de página N+1 en vuelo
  final String query;              // search activo
  final UserRole? roleFilter;      // rol activo
  final UsersFailure? failure;     // error de carga inicial
  const UsersListState({...});
}
```

`UsersListCubit`:

- `load()` — reset a página 1 con `query`/`roleFilter` actuales
  (guard anti doble-call + `isClosed`).
- `loadMore()` — si `hasMore && !isLoadingMore`: fetch `page+1`,
  append a `members` (dedup por `id` defensivo).
- `setQuery(String)` — la screen la llama con debounce ~350ms;
  guarda el query y relanza `load()`.
- `setRole(UserRole?)` — guarda y relanza `load()`.
- `refresh()` — pull-to-refresh → `load()` (mismo query/filtro).
- `prependMember(OrgMember)` — insert optimista tras crear/vincular
  (transitorio: el orden real es `created_at ASC`; tras un refresh el
  nuevo aparece al final).
- `updateMember(OrgMember)` — reemplaza por `id` (status flip local
  hasta la 50; luego recibe el ítem del PATCH).
- `total` para los stats = `meta.total` del último response — con
  filtro activo muestra el total filtrado (correcto: "N miembros" que
  coinciden con la vista).

## Cambios por archivo

### Entidad/modelos

**`org_member.dart`** — `+ final bool isOwner` (default false, en
`props`/`copyWith`); doc de `linked` aclara que solo viene en
create/link (los ítems del GET no lo traen).

**`org_member_model.dart`** — `+ isOwner` (`json['isOwner'] == true`);
`organizationId` queda `''` en ítems de lista (el GET no lo devuelve —
la org es la del JWT); doc aclarado.

**`lib/features/users/data/models/users_page_model.dart`** (nuevo) —
`{items: List<OrgMemberModel>, page, limit, total, totalPages}` +
`hasMore => page < totalPages`; `fromJson` del shape `{items, meta}`.

**`lib/features/users/domain/entities/users_page.dart`** (nuevo) —
entidad de dominio homónima (el repo devuelve `UsersPage`, no el
model — mismo patrón model/entity del módulo; el model extiende o el
repo mapea — elegir lo que mejor siga `OrgMemberModel extends OrgMember`:
`UsersPageModel extends UsersPage`).

### Cadena de capas

**`i_remote_users_datasource.dart`**:
```dart
/// `GET /auth/users?page=&limit=&search=&role=` (doc 008 + backend 059).
Future<UsersPageModel> getUsers({
  required int page,
  required int limit,
  String? search,
  UserRole? role,
});
```

**`remote_users_datasource_impl.dart`** — `GET $base/auth/users` con
`queryParameters` (solo los params presentes) → `UsersPageModel.fromJson`.

**`i_users_repository.dart`**:
```dart
/// Una página del listado (doc 008): el backend pagina y filtra —
/// `search` matchea nombre/email, `role` el rol de la membresía.
Future<Either<UsersFailure, UsersPage>> getUsers({
  required int page,
  required int limit,
  String? search,
  UserRole? role,
});
```

**`users_repository_impl.dart`** — `getUsers` con el mismo try/catch +
`_mapError` (403/429/network); `INetworkInfo` antes del call.

**`list_users_use_case.dart`** (nuevo) — thin: `call({page, limit,
search, role}) → repo.getUsers(...)`.

### Pantalla (`users_screen.dart`)

- `_allMembers`/sample data → `BlocProvider` de `UsersListCubit` +
  `load()` al init. La lista, `total` y `hasMore` salen del state.
- `_filteredMembers`, `_roleFilter`, `_query`, `_visibleCount`,
  `_loadToken` → **se van** — filtrar/paginar local murió con la
  paginación real.
- `_searchController` queda (el field es TextEditingController) —
  `onChanged` → debounce 350ms (`Timer`) → `cubit.setQuery`.
- `RoleFilterChips` → `cubit.setRole`.
- `_onScroll` → `cubit.loadMore()` al acercarse al final (mismo
  threshold de 200px); `isLoadingMore` del state evita doble-call —
  `_isLoadingMore` local se va.
- Footer loader: `users_list_footer_loader.dart` existente muestra el
  spinner de página siguiente — se muestra si `state.isLoadingMore` o
  `hasMore` (revisar su API actual).
- Estados del body:
  - `initial`/`loading` → `CircularProgressIndicator` de marca centrado.
  - `error` → `usersLoadError` + botón `retryButton` → `load()`.
  - `loaded` + vacío → `UsersEmptyState` (existente — con filtro activo
    el mensaje "Sin resultados" ya lo maneja? verificar y reusar).
- `RefreshIndicator` sobre el `ListView` → `cubit.refresh()` (colores
  de marca).
- `_openNewUserSheet`/`_openLinkUserSheet` → `cubit.prependMember`
  (mismo toast).
- `_setMemberStatus` → `cubit.updateMember` (sigue local — la 50 lo
  conecta al PATCH).
- Stats: `state.total` ("N miembros").

### Card

**`org_member_card.dart`**:
- `member.isOwner` → badge **"Dueño"** (pill con borde navy 1px + texto
  navy 11px w600 — junto al status chip).
- `member.isOwner` → el ⋮ `MemberActionsMenu` **no se renderiza**
  (suspender/reset son `OWNER_*` en backend — ofrecerlos siempre falla).

### DI

`setup_di.dart` — `ListUsersUseCase` (lazySingleton) + `UsersListCubit`
(factory — efímero como los demás del módulo).

### Sample data

`sample_org_members.dart` — el screen deja de usarlo; si algún test lo
referencia queda como fixture, si no se borra (verificar al
implementar).

### l10n (es/en/pt)

```json
// es
"ownerBadge": "Dueño",
"usersLoadError": "No se pudo cargar el listado — revisá tu conexión",
"retryButton": "Reintentar",
// en
"ownerBadge": "Owner",
"usersLoadError": "Couldn't load the list — check your connection",
"retryButton": "Retry",
// pt
"ownerBadge": "Dono",
"usersLoadError": "Não foi possível carregar a lista — verifique sua conexão",
"retryButton": "Tentar novamente",
```

### Design yaml

Bump `1.10.8 → 1.10.9`: `member_list` documenta paginación real
server-side (scroll → página siguiente, debounce de búsqueda 350ms,
`RefreshIndicator`, estados loading/error), `org_member_card` gana
`owner_badge` + "⋮ oculto en dueño", changelog.

### Tests

- `list_users_use_case_test` (nuevo) — passthrough de page/limit/
  search/role + propagación de failure.
- `users_list_cubit_test` (nuevo) — loading→loaded, error→retry,
  `loadMore` append+dedup+hasMore, `setQuery`/`setRole` resetean a
  página 1, `prependMember`, `updateMember`, anti doble-call.
- `users_repository_impl_test` — `getUsers` manda los query params
  (assert del call al datasource), parse de `meta`, 403/429/network.
- `users_screen_test` — cubit mockeado: loading→spinner, error→retry,
  lista renderiza, scroll carga página 2 (append), búsqueda → debounce
  → `setQuery`, chip → `setRole`, `isOwner` muestra badge y **oculta
  ⋮**, pull-to-refresh → `refresh`, create/link insertan al tope.

## Fuera de alcance

- `PATCH /auth/users/:id/status` + `/password` reales → propuesta 50.
- `?status=` existe en backend (059) — un toggle "ocultar suspendidos"
  puede usarlo después si hace falta.
- `lastLoginAt` — el DTO lo trae; la card no lo muestra.

## Orden de implementación

1. Entidad + modelos → datasource → repo → use case → cubit.
2. DI → screen (estados, scroll, debounce, RefreshIndicator) → card.
3. ARBs → `flutter pub get`.
4. Tests → yaml → `flutter analyze` + `flutter test`.
