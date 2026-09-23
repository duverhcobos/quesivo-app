# Propuesta: Capa personal + selección de quesera

Integra el contrato de auth de las propuestas backend **064–066** en la app:

- `POST /auth/login` / `register` → **token personal** (`{sub, sid, email}` — sin org ni roles) + `name`. Auth pura.
- `GET /auth/me` → perfil + `organizations[]` — **única fuente** del listado de queseras.
- `POST /auth/select-organization` → par de tokens **org-scoped** (`{+organizationId, +roles}`) + `organizationId`/`organizationName`. Consume la sesión personal que lo llamó.

## Flujo resultante

```
login → tokens personales → GET /me → home personal (/queseras, cards)
  → tap card → select-organization → tokens org-scoped → /home (shell actual)
  → drawer "Cambiar quesera" → /queseras → tap otra card → select-org → entrar
```

**Hallazgo que simplifica**: `checkSession()` ya hace `getMe()` + merge — el
code path `login → /me` ya existe. Y el reset de estado org-scoped es gratis:
los cubits de módulo (`UsersListCubit`, etc.) son `registerFactory` que nacen
y mueren con su pantalla — entrar a otra quesera carga fresco solo. El único
estado global es `AuthCubit.user`, que se reemplaza entero.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/entities/organization_summary.dart` | Nuevo — entidad de una quesera del listado |
| `lib/features/auth/domain/entities/user.dart` | Agregar `organizations` |
| `lib/features/auth/data/models/user_model.dart` | Parsear `organizations[]` |
| `lib/features/auth/data/models/organization_session_model.dart` | Nuevo — response de select-organization |
| `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart` | + `selectOrganization` |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | Implementar `POST /auth/select-organization` |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | + `selectOrganization` |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Implementar (saveTokens + errores) |
| `lib/features/auth/domain/use_cases/select_organization_use_case.dart` | Nuevo |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | Extraer `_loadSession()` sin delay + `refreshSession()` público |
| `lib/features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart` | Persistir `organizations` en el perfil cacheado |
| `lib/features/queseras/presentation/cubit/quesera_selection_cubit.dart` + `_state.dart` | Nuevo — cubit del tap en card |
| `lib/features/queseras/presentation/screens/queseras_screen.dart` | Nuevo — home personal |
| `lib/features/queseras/presentation/widgets/quesera_card.dart` | Nuevo — card de quesera |
| `lib/core/routes/auth_guard.dart` | + `queserasRoute` + regla "sin org → /queseras" |
| `lib/core/routes/app_router.dart` | + `GoRoute /queseras` fuera del shell |
| `lib/features/shell/presentation/widgets/drawer/drawer_menu_list.dart` | + ítem "Cambiar quesera" |
| `lib/features/auth/presentation/screens/login_screen.dart` / `register_screen.dart` | Listener: `checkSession()` → `refreshSession()` (sin delay) |
| `lib/core/di/setup_di.dart` | Registrar use case + cubit |
| `lib/l10n/app_{es,en,pt}.arb` | Claves nuevas |
| `test/` | Specs de cubit, repo, datasource, guard, widgets |
| `../documentacion/api/auth/006-post-select-organization.md` | Marcar ✅ integrado |
| `../Design/quesivo-design-system.yaml` | Bump + spec de `QueseraCard`/home personal |

---

## 1. `organization_summary.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/entities/organization_summary.dart`

```dart
import 'package:equatable/equatable.dart';

/// Una quesera a la que el usuario pertenece (ítem de `organizations[]`
/// de `GET /auth/me`, propuestas backend 050+066).
///
/// SOLID (SRP): representa el resumen de membresía — el rol vive acá,
/// no en el User, porque es por-organización.
class OrganizationSummary extends Equatable {
  final String id;
  final String name;
  final String role;

  const OrganizationSummary({
    required this.id,
    required this.name,
    required this.role,
  });

  @override
  List<Object?> get props => [id, name, role];
}
```

## 2. `user.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/domain/entities/user.dart`

**Antes:**
```dart
  /// Estado de la cuenta según `GET /auth/me`: `active`,
  /// `pending_verification` o `suspended`. Null en respuestas que no lo
  /// traen (login/register no lo incluyen) — nunca asumirlo "active".
  final String? status;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.token,
    this.refreshToken,
    this.organizationId,
    this.organizationName,
    this.roles = const [],
    this.status,
  });
```

**Después:**
```dart
  /// Estado de la cuenta según `GET /auth/me`: `active`,
  /// `pending_verification` o `suspended`. Null en respuestas que no lo
  /// traen (login/register no lo incluyen) — nunca asumirlo "active".
  final String? status;

  /// Queseras del usuario — solo llegan de `GET /auth/me` (propuesta
  /// backend 066). Con token personal `organizationId` es null: el user
  /// está autenticado pero fuera de toda quesera (capa personal).
  final List<OrganizationSummary> organizations;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.token,
    this.refreshToken,
    this.organizationId,
    this.organizationName,
    this.roles = const [],
    this.status,
    this.organizations = const [],
  });
```

Y en `props` agregar `organizations` (al final de la lista). Agregar el
import de `organization_summary.dart` arriba.

## 3. `user_model.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/models/user_model.dart`

**Antes:**
```dart
      roles:
          (json['roles'] as List?)?.map((e) => e as String).toList() ??
          const [],
      status: json['status'],
    );
  }
```

**Después:**
```dart
      roles:
          (json['roles'] as List?)?.map((e) => e as String).toList() ??
          const [],
      status: json['status'],
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

En `toJson()` agregar `'organizations': organizations.map((o) => {'id': o.id, 'name': o.name, 'role': o.role}).toList(),`
y el import de `organization_summary.dart`. Constructor: `super.organizations`.

## 4. `organization_session_model.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/data/models/organization_session_model.dart`

```dart
/// Response de `POST /auth/select-organization`
/// (`documentacion/api/auth/006-post-select-organization.md`):
/// par de tokens org-scoped + contexto de la quesera entrante.
/// La sesión personal que lo llamó queda consumida server-side —
/// el par viejo se descarta al persistir este.
class OrganizationSessionModel {
  final String accessToken;
  final String refreshToken;
  final String organizationId;
  final String organizationName;

  const OrganizationSessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.organizationId,
    required this.organizationName,
  });

  factory OrganizationSessionModel.fromJson(Map<String, dynamic> json) {
    return OrganizationSessionModel(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      organizationId: json['organizationId'] ?? '',
      organizationName: json['organizationName'] ?? '',
    );
  }
}
```

## 5. `i_remote_auth_datasource.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart`

**Después** (agregar al final de la interfaz, antes del cierre):

```dart
  /// Emite un par de tokens ligado a la membresía de otra quesera
  /// (`POST /auth/select-organization`, doc 006). Con token personal
  /// consume esa sesión; con token org-scoped la sesión anterior queda
  /// viva (multi-org legítimo). 401 = no sos miembro activo de esa org.
  Future<OrganizationSessionModel> selectOrganization(String organizationId);
```

Import: `../../models/organization_session_model.dart`.

## 6. `remote_auth_datasource_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

**Después** (al final de la clase):

```dart
  @override
  Future<OrganizationSessionModel> selectOrganization(
    String organizationId,
  ) async {
    // Real en todos los entornos (propuesta backend 064) — contrato
    // documentacion/api/auth/006-post-select-organization.md. El Bearer
    // actual lo inyecta AuthInterceptor; el backend valida la membresía.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/select-organization',
      data: {'organizationId': organizationId},
    );
    return OrganizationSessionModel.fromJson(responseData);
  }
```

Import del modelo nuevo.

## 7. `i_auth_repository.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/domain/repositories/i_auth_repository.dart`

**Después** (antes de `logout`):

```dart
  /// Entra a otra quesera: pide el par de tokens org-scoped y lo
  /// persiste reemplazando el actual. El perfil/org context se
  /// refrescan aparte vía `checkAuthStatus()` (única fuente = /me).
  Future<Either<AuthFailure, void>> selectOrganization(
    String organizationId,
  );
```

## 8. `auth_repository_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Después** (antes de `logout`):

```dart
  @override
  Future<Either<AuthFailure, void>> selectOrganization(
    String organizationId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final session = await remoteDataSource.selectOrganization(
        organizationId,
      );
      // CRÍTICO: reemplaza el par completo — con token personal la
      // sesión quedó CONSUMIDA server-side; reusar su refresh token
      // dispara TOKEN_REUSE_DETECTED y revoca TODAS las sesiones
      // (doc 006). Con token org-scoped la sesión vieja sigue viva
      // pero este dispositivo solo conserva la nueva.
      await localDataSource.saveTokens(
        token: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return const Right(null);
    } on UnauthorizedException catch (e, stackTrace) {
      // 401: membresía inexistente/suspendida o rol no-ADMIN — la
      // quesera ya no es accesible; el caller refresca /me para que
      // desaparezca de la lista.
      logger.warning(
        'select-organization rechazado',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(InvalidCredentialsFailure());
    } on RestApiException catch (e, stackTrace) {
      logger.error(
        'Error de API al seleccionar organización',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al seleccionar organización',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }
```

Además en `checkAuthStatus()` — el `merged` debe conservar `organizations`:

**Antes:**
```dart
      final merged = UserModel(
        id: fresh.id,
        email: fresh.email,
        name: fresh.name,
        token: liveToken,
        refreshToken: liveRefreshToken,
        organizationId: fresh.organizationId,
        organizationName: fresh.organizationName,
        roles: fresh.roles,
        status: fresh.status,
      );
```

**Después:**
```dart
      final merged = UserModel(
        id: fresh.id,
        email: fresh.email,
        name: fresh.name,
        token: liveToken,
        refreshToken: liveRefreshToken,
        organizationId: fresh.organizationId,
        organizationName: fresh.organizationName,
        roles: fresh.roles,
        status: fresh.status,
        organizations: fresh.organizations,
      );
```

## 9. `select_organization_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/select_organization_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Emite el par de tokens ligado a la membresía de la quesera tocada
/// (propuesta backend 064). El perfil y `organizations[]` se recargan
/// después vía `CheckAuthStatusUseCase` — `/auth/me` es la única fuente.
class SelectOrganizationUseCase {
  final IAuthRepository repository;

  SelectOrganizationUseCase(this.repository);

  Future<Either<AuthFailure, void>> call(String organizationId) {
    return repository.selectOrganization(organizationId);
  }
}
```

## 10. `auth_cubit.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/presentation/cubit/auth_cubit.dart`

**Antes:**
```dart
  Future<void> checkSession() async {
    emit(const AuthLoading());

    // Agregamos un delay intencional de 2 segundos para que la UI
    // del Splash Screen sea visible humanamente. Sin esto, leer el storage
    // nativo es tan rápido (milisegundos) que hace parpadear la pantalla.
    await Future.delayed(const Duration(seconds: 2));

    final result = await _checkAuthStatusUseCase();
    result.fold(
      (failure) => emit(
        const AuthInitial(),
      ), // Si falla, vuelve al estado inicial (Login Screen)
      (user) => emit(AuthSuccess(user)),
    );
  }
```

**Después:**
```dart
  Future<void> checkSession() async {
    emit(const AuthLoading());

    // Agregamos un delay intencional de 2 segundos para que la UI
    // del Splash Screen sea visible humanamente. Sin esto, leer el storage
    // nativo es tan rápido (milisegundos) que hace parpadear la pantalla.
    await Future.delayed(const Duration(seconds: 2));

    await _loadSession();
  }

  /// Recarga la sesión SIN el delay del splash — para los triggers
  /// post-login/register y post-select-organization, donde el usuario
  /// ya está adentro y 2s de espera sería fricción. Misma fuente:
  /// `GET /auth/me` vía `CheckAuthStatusUseCase` (propuesta backend 066).
  Future<void> refreshSession() async {
    emit(const AuthLoading());
    await _loadSession();
  }

  Future<void> _loadSession() async {
    final result = await _checkAuthStatusUseCase();
    result.fold(
      (failure) => emit(
        const AuthInitial(),
      ), // Si falla, vuelve al estado inicial (Login Screen)
      (user) => emit(AuthSuccess(user)),
    );
  }
```

## 11. `secure_local_auth_datasource_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart`

**Antes:**
```dart
    final profileOnly = UserModel(
      id: user.id,
      email: user.email,
      name: user.name,
      organizationId: user.organizationId,
      organizationName: user.organizationName,
      roles: user.roles,
      status: user.status,
    );
```

**Después:**
```dart
    final profileOnly = UserModel(
      id: user.id,
      email: user.email,
      name: user.name,
      organizationId: user.organizationId,
      organizationName: user.organizationName,
      roles: user.roles,
      status: user.status,
      organizations: user.organizations,
    );
```

Y en `getUserSession()` el `UserModel` reconstruido agrega
`organizations: profile.organizations,`.

## 12. `quesera_selection_state.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/cubit/quesera_selection_state.dart`

```dart
import 'package:equatable/equatable.dart';

/// Estado del tap en una quesera de la capa personal.
/// `selectingId` = qué card está resolviendo select-organization
/// (muestra su spinner y bloquea los demás taps).
class QueseraSelectionState extends Equatable {
  final String? selectingId;
  final String? errorMessage;

  const QueseraSelectionState({this.selectingId, this.errorMessage});

  bool get isSelecting => selectingId != null;

  QueseraSelectionState copyWith({
    String? selectingId,
    String? errorMessage,
    bool clearSelection = false,
    bool clearError = false,
  }) {
    return QueseraSelectionState(
      selectingId: clearSelection ? null : (selectingId ?? this.selectingId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [selectingId, errorMessage];
}
```

## 13. `quesera_selection_cubit.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/cubit/quesera_selection_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/use_cases/select_organization_use_case.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import 'quesera_selection_state.dart';

/// Orquesta el tap en una card de quesera (capa personal, propuesta §55).
///
/// SOLID (SRP): no decide navegación — eso es del `AuthGuard`/router vía
/// el `AuthSuccess` que emite `AuthCubit` tras `refreshSession()`. Este
/// cubit solo resuelve `POST /auth/select-organization` y reporta
/// loading/error por card.
class QueseraSelectionCubit extends Cubit<QueseraSelectionState> {
  final SelectOrganizationUseCase _selectOrganization;
  final AuthCubit _authCubit;

  QueseraSelectionCubit(this._selectOrganization, this._authCubit)
    : super(const QueseraSelectionState());

  /// Devuelve `true` si la quesera quedó activa (tokens org-scoped
  /// guardados + sesión recargada). La UI navega a /home solo entonces.
  Future<bool> select(String organizationId) async {
    if (state.isSelecting) return false;
    emit(
      state.copyWith(selectingId: organizationId, clearError: true),
    );

    final result = await _selectOrganization(organizationId);

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            clearSelection: true,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) async {
        // Los tokens nuevos ya están en storage; /me rehidrata el User
        // con organizationId + organizations frescas (la membresía
        // muerta desaparece sola de la lista si fue ese el error).
        await _authCubit.refreshSession();
        if (isClosed) return false;
        emit(state.copyWith(clearSelection: true));
        return true;
      },
    );
  }
}
```

## 14. `quesera_card.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/widgets/quesera_card.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/organization_summary.dart';

/// Card de una quesera en el home personal (§55). Muestra nombre, chip
/// de rol y chevron; si es la org activa del JWT lleva el badge
/// "Actual" y el tap es navegación gratis (sin select-organization).
/// Cuando `loading` está activo muestra spinner y bloquea el tap.
class QueseraCard extends StatelessWidget {
  const QueseraCard({
    super.key,
    required this.organization,
    required this.isActive,
    required this.loading,
    required this.enabled,
    required this.activeLabel,
    required this.roleLabel,
    required this.onTap,
  });

  final OrganizationSummary organization;
  final bool isActive;
  final bool loading;
  final bool enabled;
  final String activeLabel;
  final String roleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.quesivoWhite,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.quesivoBorder),
          ),
          child: Row(
            children: [
              // Ícono de marca: quesera en círculo navy suave.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.quesivoNavy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business_outlined,
                  color: AppColors.quesivoNavy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.quesivoTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.quesivoTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.quesivoYellow.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.quesivoTextSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 15. `queseras_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/screens/queseras_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/organization_summary.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/quesera_selection_cubit.dart';
import '../cubit/quesera_selection_state.dart';
import '../widgets/quesera_card.dart';
import '../../../shell/presentation/widgets/drawer/drawer_logout_dialog.dart';

/// Home personal — capa personal (§55). La pantalla a la que cae el
/// login con token personal (sin org) y adonde vuelve el usuario con
/// "Cambiar quesera". Muestra las queseras de `GET /auth/me` como
/// cards: tap sobre la activa = navegación gratis; tap sobre otra =
/// `select-organization` + refresh de sesión.
///
/// Vive FUERA del `StatefulShellRoute`: no lleva `ShellHeader` ni
/// `QuesivoNavBar` (ese chrome es del contexto quesera). Su encabezado
/// es propio: imagotipo + saludo con el nombre del usuario, sin org.
class QueserasScreen extends StatelessWidget {
  const QueserasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<QueseraSelectionCubit>(),
      child: const _QueserasView(),
    );
  }
}

class _QueserasView extends StatelessWidget {
  const _QueserasView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    final user = context
        .select<
          AuthCubit,
          (String, String?, List<OrganizationSummary>)
        >(
          (cubit) => cubit.state is AuthSuccess
              ? (
                  (cubit.state as AuthSuccess).user.name,
                  (cubit.state as AuthSuccess).user.organizationId,
                  (cubit.state as AuthSuccess).user.organizations,
                )
              : ('', null, const <OrganizationSummary>[]),
        );

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: SafeArea(
        child: BlocConsumer<QueseraSelectionCubit, QueseraSelectionState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
              // El /me ya refrescó la lista en el camino de error.
            }
          },
          builder: (context, selection) {
            final orgs = user.$3;
            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.075,
                vertical: 16,
              ),
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/imagotipo_quesivo.png',
                      height: 56,
                    ),
                    const Spacer(),
                    // Logout de la capa personal — mismo diálogo del drawer.
                    IconButton(
                      tooltip: l10n.logoutTooltip,
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        final authCubit = context.read<AuthCubit>();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => const DrawerLogoutDialog(),
                        );
                        if (confirmed == true && context.mounted) {
                          authCubit.logout();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.personalGreeting(user.$1),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quesivoNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.myQueserasTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.quesivoTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (orgs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        l10n.noQueserasAvailable,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.quesivoTextSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  for (final org in orgs) ...[
                    QueseraCard(
                      organization: org,
                      isActive: org.id == user.$2,
                      loading: selection.selectingId == org.id,
                      enabled: !selection.isSelecting,
                      activeLabel: l10n.queseraActiveBadge,
                      roleLabel: l10n.roleLabelFor(org.role),
                      onTap: () => _onQueseraTap(context, org.id),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _onQueseraTap(BuildContext context, String orgId) async {
    final cubit = context.read<QueseraSelectionCubit>();
    final router = GoRouter.of(context);

    final user = context.read<AuthCubit>().state;
    final currentOrgId = user is AuthSuccess ? user.user.organizationId : null;

    if (orgId == currentOrgId) {
      // Ya es la org del JWT — navegación gratis, cero llamadas.
      router.go(AuthGuard.homeRoute);
      return;
    }

    final entered = await cubit.select(orgId);
    if (entered && context.mounted) {
      router.go(AuthGuard.homeRoute);
    }
  }
}
```

## 16. `auth_guard.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

**Antes:**
```dart
  static const String splashRoute = '/splash';
  static const String homeRoute = '/home';
```

**Después:**
```dart
  static const String splashRoute = '/splash';
  static const String homeRoute = '/home';
  // Capa personal (§55): home con las queseras del user. Accesible con
  // cualquier token válido; es la ÚNICA ruta alcanzable con token
  // personal (sin organizationId).
  static const String queserasRoute = '/queseras';
```

**Antes:**
```dart
    // Si la sesión es válida (AuthSuccess)
    if (authState is AuthSuccess) {
      // Si está logueado, no tiene por qué estar merodeando en Login o Recuprar Contraseña
      if (isGoingToPublicRoute || isGoingToSplash) {
        logger.info(
          'AuthGuard -> Acción: $homeRoute (Redirigiendo usuario logueado)',
        );
        return homeRoute;
      }
    }
```

**Después:**
```dart
    // Si la sesión es válida (AuthSuccess)
    if (authState is AuthSuccess) {
      final hasOrgContext = authState.user.organizationId != null;

      // Token personal (sin org): solo la capa personal es alcanzable —
      // los módulos del shell necesitan el JWT org-scoped que emite
      // select-organization. Desde /queseras se queda quieto.
      if (!hasOrgContext) {
        if (location != queserasRoute) {
          logger.info(
            'AuthGuard -> Acción: $queserasRoute (token sin org, capa personal)',
          );
          return queserasRoute;
        }
        return null;
      }

      // Si está logueado, no tiene por qué estar merodeando en Login o Recuprar Contraseña
      if (isGoingToPublicRoute || isGoingToSplash) {
        logger.info(
          'AuthGuard -> Acción: $homeRoute (Redirigiendo usuario logueado)',
        );
        return homeRoute;
      }
    }
```

## 17. `app_router.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Después** (agregar como GoRoute top-level, antes del `StatefulShellRoute`):

```dart
      // Capa personal (§55): FUERA del StatefulShellRoute — no lleva
      // ShellHeader ni QuesivoNavBar; su chrome es propio. Accesible con
      // token personal (post-login) y con org-scoped ("Cambiar quesera").
      GoRoute(
        path: AuthGuard.queserasRoute,
        pageBuilder: (context, state) => CustomTransitions.fade(
          context: context,
          state: state,
          child: const QueserasScreen(),
        ),
      ),
```

Import: `../../features/queseras/presentation/screens/queseras_screen.dart`.

## 18. `drawer_menu_list.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/drawer/drawer_menu_list.dart`

Agregar el ítem **antes** del bloque destructivo del logout (dentro del
mismo `stagger` que envuelve Divider + logout). Como primer hijo de esa
Column:

**Antes:**
```dart
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Divider que marca la "zona destructiva" — separa el
                // logout del resto del menú sin agregar ruido.
                const Divider(height: 1, color: AppColors.quesivoBorder),
                const SizedBox(height: 12),
```

**Después:**
```dart
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Divider que marca la "zona destructiva" — separa el
                // logout del resto del menú sin agregar ruido.
                const Divider(height: 1, color: AppColors.quesivoBorder),
                const SizedBox(height: 12),
                // §55 — Cambiar de quesera: vuelve a la capa personal.
                // Solo tiene sentido con la lista cargada (siempre
                // viene de /me); con 1 sola quesera también sirve como
                // salida al home personal.
                DrawerMenuItemRow(
                  icon: Icons.swap_horiz_outlined,
                  label: l10n.changeQuesera,
                  showChevron: false,
                  onTap: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.go(AuthGuard.queserasRoute);
                  },
                ),
                const SizedBox(height: 4),
```

## 19. Listeners post-auth (archivos existentes — actualización)

**Rutas:** `lib/features/auth/presentation/screens/login_screen.dart`,
`register_screen.dart`

**Antes:**
```dart
                  context.read<AuthCubit>().checkSession();
```

**Después:**
```dart
                  context.read<AuthCubit>().refreshSession();
```

(En ambos: el delay de 2s del splash ya no aplica — el usuario acaba de
interactuar; `/me` decide adónde cae vía `AuthGuard`.)

## 20. `setup_di.dart` (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

En la sección de use cases de auth agregar:

```dart
  locator.registerLazySingleton(
    () => SelectOrganizationUseCase(locator<IAuthRepository>()),
  );
```

En la sección de cubits factory agregar:

```dart
  // Capa personal (§55): cubit del tap en card de quesera — factory,
  // nace y muere con QueserasScreen.
  locator.registerFactory(
    () => QueseraSelectionCubit(
      locator<SelectOrganizationUseCase>(),
      locator<AuthCubit>(),
    ),
  );
```

Imports correspondientes.

## 21. l10n (`app_es.arb` / `app_en.arb` / `app_pt.arb`)

Claves nuevas (ejecutar `flutter gen-l10n` tras editar los `.arb`):

| Clave | es | en | pt |
|-------|----|----|-----|
| `personalGreeting` | `Hola, {name}` | `Hi, {name}` | `Olá, {name}` |
| `myQueserasTitle` | `Tus queseras` | `Your cheese factories` | `Suas queijarias` |
| `changeQuesera` | `Cambiar quesera` | `Switch factory` | `Trocar queijaria` |
| `queseraActiveBadge` | `Actual` | `Current` | `Atual` |
| `noQueserasAvailable` | `No tenés queseras disponibles.` | `No factories available.` | `Nenhuma queijaria disponível.` |
| `queseraSelectError` | `No se pudo entrar a la quesera.` | `Could not enter the factory.` | `Não foi possível entrar na queijaria.` |

Reusar las claves de rol existentes del módulo users si existen
(`roleAdmin` etc.); si el mapeo rol→label no existe como helper, agregar
en `app_localizations` un método/extension `roleLabelFor(String role)`
que mapee `ADMIN`/`OPERATOR`/`COLLECTOR`/`PRODUCER` a sus claves. Verificar
nombres reales de las claves al aplicar.

## 22. `documentacion/api/auth/006-post-select-organization.md`

Actualizar el encabezado de estado a ✅ integrado (referenciando esta
propuesta §55).

## 23. `Design/quesivo-design-system.yaml`

Bump de versión + spec nuevo: `QueserasScreen` (capa personal — chrome
propio sin shell), `QueseraCard` (radio 16, ícono navy 8%, badge amarillo
"Actual", chevron/spinner trailing). Entrada en changelog.

## 24. Tests

- `test/features/auth/data/models/user_model_test.dart` — `organizations[]`
  parsea; ausente → `[]`.
- `test/features/auth/data/repositories/auth_repository_impl_test.dart` —
  `selectOrganization` persiste ambos tokens vía `saveTokens` y NO el perfil;
  401 → failure.
- `test/features/auth/data/datasources/remote_auth_datasource_impl_test.dart` —
  POST a `/auth/select-organization` con el body correcto.
- `test/features/queseras/presentation/cubit/quesera_selection_cubit_test.dart`
  (bloc_test) — éxito: emite selecting → llama refreshSession → clear;
  error: emite errorMessage; doble tap ignorado.
- `test/core/routes/auth_guard_test.dart` — `AuthSuccess` sin
  `organizationId` → `/queseras` desde cualquier ruta; con org →
  comportamiento actual intacto + `/queseras` permitida.
- Widget test de `QueseraCard` (badge activo, loading bloquea tap) y de
  `QueserasScreen` (lista, estado vacío, tap en activa = navegación sin
  llamar al cubit).

---

## Orden de aplicación

1. `organization_summary.dart` + `user.dart` + `user_model.dart` (entidad → parseo).
2. `organization_session_model.dart` + datasource interface + impl + repo interface + impl.
3. `select_organization_use_case.dart`.
4. `auth_cubit.dart` (`_loadSession`/`refreshSession`) + `secure_local_auth_datasource_impl.dart`.
5. `quesera_selection_{state,cubit}.dart`.
6. `quesera_card.dart` + `queseras_screen.dart`.
7. `auth_guard.dart` (constante + regla) + `app_router.dart` (ruta) — hot restart obligatorio al probar.
8. `drawer_menu_list.dart` (ítem) + listeners login/register.
9. `setup_di.dart` + `.arb` ×3 + `flutter gen-l10n`.
10. Doc 006 → ✅ integrado + `design-system.yaml` bump.
11. Tests + `flutter analyze` + `flutter test`.
