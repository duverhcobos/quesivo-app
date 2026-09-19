# Propuesta: Integrar `POST /auth/users` — creación real de miembros

Primera integración endpoint-a-endpoint del módulo Usuarios. El `NewUserSheet`
deja de fabricar un `OrgMember` sintético: valida con VOs de dominio, dispara
`CreateUserCubit.submit()` y devuelve el miembro **real** que responde el
backend (uuid, `status`, `linked`). El dataset sigue siendo el local de 54 —
`GET /auth/users` lo reemplaza en la próxima propuesta.

Contrato: `documentacion/api/auth/007-post-users.md`

- Body: `{ email, name, password, role }` — la organización **nunca** viaja:
  la infiere el backend del JWT del admin (IDOR).
- `201` → `{id,email,name,role,status,organizationId,linked}`. `linked:true`
  = el email ya existía globalmente y solo se creó la membresía (la app
  muestra feedback distinto: "entra con su contraseña actual").
- Errores mapeados: `403` (no ADMIN) · `409 + MEMBERSHIP_ALREADY_EXISTS` ·
  `409 + USER_SUSPENDED` · `429` (10 req/min). El `401` lo resuelve
  transparente el `RefreshTokenInterceptor` (ya verificado en físico).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/users/domain/failures/users_failure.dart` | **nuevo** — jerarquía `UsersFailure` |
| `lib/features/users/domain/value_objects/member_name.dart` | **nuevo** — VO nombre no vacío |
| `lib/features/users/domain/value_objects/member_email.dart` | **nuevo** — VO email (espejo del de auth) |
| `lib/features/users/domain/value_objects/temp_password.dart` | **nuevo** — VO política temporal + predicados del checklist |
| `lib/features/users/domain/repositories/i_users_repository.dart` | **nuevo** — interfaz |
| `lib/features/users/domain/use_cases/create_user_use_case.dart` | **nuevo** — valida con VOs + delega |
| `lib/features/users/domain/entities/org_member.dart` | +`linked` (default `false`), `MemberStatus` gana `apiValue`/`fromApi` |
| `lib/features/users/data/models/org_member_model.dart` | **nuevo** — `fromJson` del contrato 007 |
| `lib/features/users/data/datasources/interfaces/i_remote_users_datasource.dart` | **nuevo** — interfaz |
| `lib/features/users/data/datasources/implementations/remote_users_datasource_impl.dart` | **nuevo** — `networkService.post('/auth/users')` |
| `lib/features/users/data/repositories/users_repository_impl.dart` | **nuevo** — orquesta + mapea excepción→failure |
| `lib/features/users/presentation/cubit/create_user_state.dart` | **nuevo** — `status`/`createdMember`/`failure` |
| `lib/features/users/presentation/cubit/create_user_cubit.dart` | **nuevo** — solo orquesta el submit |
| `lib/features/auth/data/exceptions/auth_exceptions.dart` | `RestApiException` gana `errorCode` opcional |
| `lib/core/network/implementations/dio_network_service_impl.dart` | extrae `errorCode` del body de error |
| `lib/core/network/implementations/http_network_service_impl.dart` | ídem (paridad — mismo contrato) |
| `lib/core/widgets/quesivo_primary_button.dart` | +`isLoading` (spinner navy, deshabilita) |
| `lib/core/widgets/quesivo_text_field.dart` | +`enabled` (bloquear campos durante el submit) |
| `lib/features/users/presentation/widgets/new_user_sheet.dart` | valida con VOs, submit vía cubit, loading + error inline |
| `lib/features/users/presentation/screens/users_screen.dart` | snackbar distingue `linked` vs creado |
| `lib/core/di/setup_di.dart` | registros del feature |
| `lib/l10n/app_es.arb` / `app_en.arb` / `app_pt.arb` | 6 keys nuevas + `flutter gen-l10n` |
| `test/features/users/...` | 3 specs nuevos + 2 actualizados |
| `../Design/quesivo-design-system.yaml` | `isLoading` del primario + nota integración → `1.10.1` |

Decisiones de diseño:

- **`CreateUserCubit` solo orquesta el submit** — los campos quedan en el
  `State` del sheet (la checklist necesita el valor por keystroke de todos
  modos) pero **la validación migra a VOs de dominio**: desaparecen los
  regexes del widget (regla SOLID 2). Es el punto medio entre "todo en el
  widget" y el patrón `LoginCubit` full-formz — deliberado para no
  reescribir la UX aprobada de §44.
- **Error del backend se muestra inline** dentro del sheet (no snackbar):
  el snackbar sobre un modal es raro y el form debe quedar abierto para
  corregir — ej. `MEMBERSHIP_ALREADY_EXISTS` invita a cambiar el email.
- **`RestApiException.errorCode`** es la vía para distinguir los dos 409 —
  el backend ya lo emite (`DomainExceptionFilter`). Campo opcional: cero
  impacto en los callers actuales.
- **Seam de test**: `NewUserSheet.show(..., {cubit})` — los tests pasan un
  mock directo; la screen no pasa nada y se resuelve por `locator`.

---

## 1. `users_failure.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/failures/users_failure.dart`

```dart
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
  const InvalidMemberDataFailure()
    : super('Revisá los datos del formulario.');
}

/// Cualquier otro error del servidor/red no clasificado.
class UsersServerFailure extends UsersFailure {
  const UsersServerFailure([String? message])
    : super(message ?? 'Ocurrió un error en el servidor. Intentalo más tarde.');
}
```

## 2. `member_name.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/value_objects/member_name.dart`

```dart
import 'package:formz/formz.dart';

enum MemberNameValidationError { empty }

/// VO del nombre del miembro a crear — el backend pide `MaxLength(255)`
/// (doc 007); el único rechazo útil en UI es el vacío tras trim.
class MemberName extends FormzInput<String, MemberNameValidationError> {
  const MemberName.pure() : super.pure('');
  const MemberName.dirty([super.value = '']) : super.dirty();

  @override
  MemberNameValidationError? validator(String value) {
    return value.trim().isEmpty ? MemberNameValidationError.empty : null;
  }
}
```

## 3. `member_email.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/value_objects/member_email.dart`

```dart
import 'package:formz/formz.dart';

enum MemberEmailValidationError { empty, invalid }

/// VO del email del miembro — espejo deliberado del `Email` de auth:
/// importarlo acoplaría users→auth (misma razón por la que
/// `PasswordRequirementsChecklist` vive en core y no se comparte el VO).
/// El backend normaliza `trim` + `lowercase` (doc 007 §Notas).
class MemberEmail extends FormzInput<String, MemberEmailValidationError> {
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  const MemberEmail.pure() : super.pure('');
  const MemberEmail.dirty([super.value = '']) : super.dirty();

  @override
  MemberEmailValidationError? validator(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return MemberEmailValidationError.empty;
    if (!_emailRegex.hasMatch(normalized)) {
      return MemberEmailValidationError.invalid;
    }
    return null;
  }
}
```

## 4. `temp_password.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/value_objects/temp_password.dart`

```dart
import 'package:formz/formz.dart';

enum TempPasswordValidationError { weak }

/// VO de la contraseña temporal que el admin define para el miembro —
/// misma política que `RegisterPassword` de auth y `RegisterDto` del
/// backend (doc 007: min 8 + minúscula + mayúscula + dígito).
///
/// Los predicados por regla alimentan el checklist vivo del sheet —
/// reemplazan los regexes espejo que la UI-phase dejó en el widget.
class TempPassword extends FormzInput<String, TempPasswordValidationError> {
  static final _hasLower = RegExp(r'[a-z]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasDigit = RegExp(r'\d');

  const TempPassword.pure() : super.pure('');
  const TempPassword.dirty([super.value = '']) : super.dirty();

  bool get hasMinLength => value.length >= 8;
  bool get hasLowercase => _hasLower.hasMatch(value);
  bool get hasUppercase => _hasUpper.hasMatch(value);
  bool get hasDigit => _hasDigit.hasMatch(value);

  @override
  TempPasswordValidationError? validator(String value) {
    final ok = hasMinLength && hasLowercase && hasUppercase && hasDigit;
    return ok ? null : TempPasswordValidationError.weak;
  }
}
```

## 5. `i_users_repository.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/repositories/i_users_repository.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../failures/users_failure.dart';

/// Repositorio del módulo Usuarios — administración de membresías de la
/// organización activa. La org la infiere el backend del JWT del admin:
/// nunca viaja en el body (IDOR, doc 007).
abstract class IUsersRepository {
  /// `POST /auth/users` — crea el usuario o lo vincula si el email ya
  /// existe globalmente (`OrgMember.linked` distingue ambos casos).
  Future<Either<UsersFailure, OrgMember>> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
}
```

## 6. `create_user_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/users/domain/use_cases/create_user_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/org_member.dart';
import '../entities/user_role.dart';
import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';
import '../value_objects/member_email.dart';
import '../value_objects/member_name.dart';
import '../value_objects/temp_password.dart';

/// Caso de Uso: crear o vincular un miembro de la organización
/// (`POST /auth/users`, doc 007). Re-valida con los VOs como única
/// fuente de verdad — la sheet ya valida, pero el dominio no confía en
/// la UI (mismo patrón que `LoginUseCase` con `Password.dirty`).
class CreateUserUseCase {
  final IUsersRepository repository;

  const CreateUserUseCase(this.repository);

  Future<Either<UsersFailure, OrgMember>> call({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) {
    final valid =
        MemberName.dirty(name).isValid &&
        MemberEmail.dirty(email).isValid &&
        TempPassword.dirty(password).isValid;
    if (!valid) {
      return Future.value(const Left(InvalidMemberDataFailure()));
    }

    // Normalización espejo del backend (trim + lowercase) — enviar ya
    // normalizado hace la UI consistente con lo que persiste la API.
    return repository.createUser(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      password: password,
      role: role,
    );
  }
}
```

## 7. `org_member.dart` (archivo existente — actualización)

**Ruta:** `lib/features/users/domain/entities/org_member.dart`

**Antes:**

```dart
/// Estado de la membresía en la organización (`status` del contrato).
enum MemberStatus { active, suspended }
```

**Después:**

```dart
/// Estado de la membresía en la organización (`status` del contrato).
enum MemberStatus {
  active('active'),
  suspended('suspended');

  const MemberStatus(this.apiValue);

  /// Valor del contrato del backend.
  final String apiValue;

  /// Parse del string del API; `active` como fallback defensivo — el
  /// catálogo es cerrado y lo controla el backend.
  static MemberStatus fromApi(String? value) => MemberStatus.values
      .firstWhere((s) => s.apiValue == value, orElse: () => MemberStatus.active);
}
```

**Antes:**

```dart
  final UserRole role;
  final MemberStatus status;
  final String organizationId;

  const OrgMember({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.organizationId,
  });
```

**Después:**

```dart
  final UserRole role;
  final MemberStatus status;
  final String organizationId;

  /// `true` cuando el email ya existía globalmente y `POST /auth/users`
  /// solo creó la membresía (doc 007) — el usuario conserva su password
  /// y el admin no tiene contraseña temporal que compartir.
  final bool linked;

  const OrgMember({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.organizationId,
    this.linked = false,
  });
```

**Antes:**

```dart
  OrgMember copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    MemberStatus? status,
    String? organizationId,
  }) => OrgMember(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    role: role ?? this.role,
    status: status ?? this.status,
    organizationId: organizationId ?? this.organizationId,
  );

  @override
  List<Object?> get props => [id, email, name, role, status, organizationId];
```

**Después:**

```dart
  OrgMember copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    MemberStatus? status,
    String? organizationId,
    bool? linked,
  }) => OrgMember(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    role: role ?? this.role,
    status: status ?? this.status,
    organizationId: organizationId ?? this.organizationId,
    linked: linked ?? this.linked,
  );

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    role,
    status,
    organizationId,
    linked,
  ];
```

## 8. `org_member_model.dart` (archivo nuevo)

**Ruta:** `lib/features/users/data/models/org_member_model.dart`

```dart
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';

/// Modelo de `OrgMember` — única responsable de parsear el JSON del API
/// (shape de `POST /auth/users` → 201, doc 007; el mismo shape repite
/// `GET /auth/users` por ítem).
///
/// SOLID (SRP): la entidad no sabe parsear JSON — igual que
/// `UserModel extends User` en auth.
class OrgMemberModel extends OrgMember {
  const OrgMemberModel({
    required super.id,
    required super.email,
    required super.name,
    required super.role,
    required super.status,
    required super.organizationId,
    super.linked,
  });

  /// Contrato: `{id,email,name,role,status,organizationId,linked}`.
  /// Defaults defensivos: `role`/`status` son catálogos cerrados del
  /// backend — un valor desconocido cae a operator/active en vez de
  /// romper el flujo completo.
  factory OrgMemberModel.fromJson(Map<String, dynamic> json) {
    return OrgMemberModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: UserRole.fromApi(json['role'] as String?),
      status: MemberStatus.fromApi(json['status'] as String?),
      organizationId: json['organizationId']?.toString() ?? '',
      linked: json['linked'] == true,
    );
  }
}
```

## 9. `i_remote_users_datasource.dart` (archivo nuevo)

**Ruta:** `lib/features/users/data/datasources/interfaces/i_remote_users_datasource.dart`

```dart
import '../../../domain/entities/user_role.dart';
import '../../models/org_member_model.dart';

/// DataSource remoto del módulo Usuarios — habla con el API vía
/// `INetworkService` (con auth/refresh ya cableados en el Dio principal).
abstract class IRemoteUsersDataSource {
  /// `POST /auth/users` — lanza `RestApiException`/`UnauthorizedException`
  /// según el status; el repository los mapea a `UsersFailure`.
  Future<OrgMemberModel> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
}
```

## 10. `remote_users_datasource_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/users/data/datasources/implementations/remote_users_datasource_impl.dart`

```dart
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../../domain/entities/user_role.dart';
import '../../models/org_member_model.dart';
import '../interfaces/i_remote_users_datasource.dart';

/// `POST /auth/users` real — contrato doc 007. La organización NO viaja
/// en el body: la infiere el backend del JWT del admin (IDOR).
class RemoteUsersDataSourceImpl implements IRemoteUsersDataSource {
  final INetworkService networkService;

  RemoteUsersDataSourceImpl(this.networkService);

  @override
  Future<OrgMemberModel> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final data = await networkService.post<Map<String, dynamic>>(
      '/auth/users',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role.apiValue,
      },
    );
    return OrgMemberModel.fromJson(data);
  }
}
```

## 11. `users_repository_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/users/data/repositories/users_repository_impl.dart`

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/logging/interfaces/i_logger_service.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../../auth/data/exceptions/auth_exceptions.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/users_failure.dart';
import '../../domain/repositories/i_users_repository.dart';
import '../datasources/interfaces/i_remote_users_datasource.dart';

/// Implementación del repositorio de Usuarios.
///
/// SOLID (SRP): orquesta datasources y mapea excepciones de
/// infraestructura a `UsersFailure` — la UI nunca ve excepciones crudas
/// (mismo patrón que `AuthRepositoryImpl`).
class UsersRepositoryImpl implements IUsersRepository {
  final IRemoteUsersDataSource remoteDataSource;
  final INetworkInfo networkInfo;
  final ILoggerService logger;

  UsersRepositoryImpl(this.remoteDataSource, this.networkInfo, this.logger);

  @override
  Future<Either<UsersFailure, OrgMember>> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }

    try {
      final member = await remoteDataSource.createUser(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      return Right(member);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado creando usuario',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }

  /// Un 401 que llega hasta acá ya pasó por el RefreshTokenInterceptor:
  /// si el refresh también falló, la sesión se está cerrando vía
  /// SessionExpiredNotifier — se reporta genérico, no hay acción de UI.
  UsersFailure _mapError(RestApiException e, StackTrace stackTrace) {
    switch (e.statusCode) {
      case 403:
        return const UsersForbiddenFailure();
      case 409:
        return switch (e.errorCode) {
          'MEMBERSHIP_ALREADY_EXISTS' => const MembershipAlreadyExistsFailure(),
          'USER_SUSPENDED' => const LinkedUserSuspendedFailure(),
          _ => UsersServerFailure(e.message),
        };
      case 429:
        return const UsersRateLimitFailure();
      default:
        logger.error(
          'Error de API al crear usuario',
          error: e,
          stackTrace: stackTrace,
        );
        return UsersServerFailure(e.message);
    }
  }
}
```

## 12. `create_user_state.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/cubit/create_user_state.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/entities/org_member.dart';
import '../../domain/failures/users_failure.dart';

/// Estado del sheet de creación — solo orquesta el submit: los campos
/// viven en el `State` del widget (validados por los VOs de dominio).
/// Sin `copyWith`: cada transición emite el estado completo (3 campos).
class CreateUserState extends Equatable {
  final FormzSubmissionStatus status;
  final OrgMember? createdMember;
  final UsersFailure? failure;

  const CreateUserState({
    this.status = FormzSubmissionStatus.initial,
    this.createdMember,
    this.failure,
  });

  @override
  List<Object?> get props => [status, createdMember, failure];
}
```

## 13. `create_user_cubit.dart` (archivo nuevo)

**Ruta:** `lib/features/users/presentation/cubit/create_user_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/entities/user_role.dart';
import '../../domain/use_cases/create_user_use_case.dart';
import 'create_user_state.dart';

/// Cubit del `NewUserSheet` — orquesta SOLO el submit contra
/// `POST /auth/users` (registerFactory: muere con el sheet). La
/// validación de campos es de la sheet vía VOs; acá solo llega el
/// comando ya válido.
class CreateUserCubit extends Cubit<CreateUserState> {
  final CreateUserUseCase _createUser;

  CreateUserCubit(this._createUser) : super(const CreateUserState());

  Future<void> submit({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    // Anti doble-tap: un submit en vuelo ignora los siguientes.
    if (state.status.isInProgress) return;

    emit(const CreateUserState(status: FormzSubmissionStatus.inProgress));
    final result = await _createUser(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    result.fold(
      (failure) => emit(
        CreateUserState(
          status: FormzSubmissionStatus.failure,
          failure: failure,
        ),
      ),
      (member) => emit(
        CreateUserState(
          status: FormzSubmissionStatus.success,
          createdMember: member,
        ),
      ),
    );
  }
}
```

## 14. `auth_exceptions.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/exceptions/auth_exceptions.dart`

**Antes:**

```dart
class RestApiException implements Exception {
  final int statusCode;
  final String message;

  RestApiException({required this.statusCode, required this.message});
}
```

**Después:**

```dart
class RestApiException implements Exception {
  final int statusCode;
  final String message;

  /// Código estable de dominio del backend — `DomainExceptionFilter` lo
  /// emite cuando la excepción lo trae (ej. `MEMBERSHIP_ALREADY_EXISTS`,
  /// `USER_SUSPENDED`, `INVALID_REFRESH_TOKEN`). Permite distinguir
  /// errores que comparten el mismo status HTTP.
  final String? errorCode;

  RestApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
  });
}
```

## 15. `dio_network_service_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/core/network/implementations/dio_network_service_impl.dart`

**Antes:**

```dart
      throw RestApiException(
        statusCode: statusCode,
        message:
            _extractErrorMessage(e.response!.data) ??
            e.response!.statusMessage ??
            'Error desconocido',
      );
```

**Después:**

```dart
      throw RestApiException(
        statusCode: statusCode,
        message:
            _extractErrorMessage(e.response!.data) ??
            e.response!.statusMessage ??
            'Error desconocido',
        errorCode: _extractErrorCode(e.response!.data),
      );
```

Y al final de la clase, junto a `_extractErrorMessage`:

```dart
  /// `errorCode` estable del DomainExceptionFilter (ej. los dos 409 de
  /// POST /auth/users) — ausente en errores de guard/validación.
  String? _extractErrorCode(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final code = data['errorCode'];
    return code is String ? code : null;
  }
```

## 16. `http_network_service_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/core/network/implementations/http_network_service_impl.dart`

**Antes:**

```dart
      throw RestApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response.body),
      );
```

**Después:**

```dart
      throw RestApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response.body),
        errorCode: _extractErrorCode(response.body),
      );
```

Y junto a `_extractErrorMessage`:

```dart
  /// Paridad con el servicio Dio — mismo campo `errorCode` del
  /// DomainExceptionFilter.
  String? _extractErrorCode(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) return null;
      final code = data['errorCode'];
      return code is String ? code : null;
    } catch (_) {
      return null;
    }
  }
```

## 17. `quesivo_primary_button.dart` (archivo existente — actualización)

**Ruta:** `lib/core/widgets/quesivo_primary_button.dart`

**Antes:**

```dart
  const QuesivoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
```

**Después:**

```dart
  const QuesivoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// `true`: el label se reemplaza por un spinner navy y el botón queda
  /// deshabilitado — el alto de 64px se conserva (no salta el layout).
  final bool isLoading;
```

**Antes:**

```dart
    final button = ElevatedButton(
      onPressed: onPressed,
```

**Después:**

```dart
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
```

**Antes:**

```dart
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
```

**Después:**

```dart
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.quesivoNavy,
              ),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1),
            ),
```

## 18. `quesivo_text_field.dart` (archivo existente — actualización)

**Ruta:** `lib/core/widgets/quesivo_text_field.dart`

Agregar el parámetro `enabled` (default `true`) al constructor/campo y
pasarlo al `TextFormField` interno como `enabled: enabled` — la sheet lo
usa para bloquear los campos mientras el submit está en vuelo.

## 19. `new_user_sheet.dart` (archivo existente — actualización)

**Ruta:** `lib/features/users/presentation/widgets/new_user_sheet.dart`

Cambios, en orden:

**a) Firma de `show` + BlocProvider:**

```dart
  /// Abre el sheet y devuelve el miembro creado por el backend, o `null`
  /// si se canceló/falló. [cubit] es seam de tests — en producción se
  /// resuelve por `locator`.
  static Future<OrgMember?> show(
    BuildContext context, {
    double topInset = 0,
    CreateUserCubit? cubit,
  }) {
    return showModalBottomSheet<OrgMember>(
      // ... igual que hoy (useRootNavigator, isScrollControlled,
      // backgroundColor, shape, constraints) ...
      builder: (_) => BlocProvider(
        create: (_) => cubit ?? locator<CreateUserCubit>(),
        child: const NewUserSheet(),
      ),
    );
  }
```

**b) Se borran** los regexes espejo (`_emailRegex`, `_hasLower`,
`_hasUpper`, `_hasDigit`) y `_validPassword` — la validación migra a los
VOs de §2-4 (regla SOLID 2: no regex en UI).

**c) `_submit` delega en el cubit:**

```dart
  void _submit() {
    final name = _name.trim();
    final email = _email.trim().toLowerCase();
    setState(() {
      _nameError = !MemberName.dirty(name).isValid;
      _emailError = !MemberEmail.dirty(email).isValid;
      _passwordError = !TempPassword.dirty(_password).isValid;
      _roleError = _role == null;
    });
    if (_nameError || _emailError || _passwordError || _roleError) return;

    context.read<CreateUserCubit>().submit(
      name: name,
      email: email,
      password: _password,
      role: _role!,
    );
  }
```

**d) El contenido scrolleable se envuelve en `BlocConsumer`:**

- `listenWhen`: `p.status != c.status && c.status.isSuccess` →
  `Navigator.of(context).pop(state.createdMember)` (devuelve el miembro
  REAL del backend — con uuid y `linked`).
- `builder`: `isSubmitting = state.status.isInProgress` →
  - campos: `enabled: !isSubmitting`
  - ghost Cancelar: `onPressed: isSubmitting ? null : () => pop()`
  - primario: `QuesivoPrimaryButton(label: ..., isLoading: isSubmitting,
    onPressed: _submit)`
- `PasswordRequirementsChecklist` evalúa `TempPassword.dirty(_password)`
  y sus predicados `hasMinLength/hasUppercase/hasLowercase/hasDigit`.
- Error del backend **inline** sobre el par de acciones (no snackbar —
  el form queda abierto para corregir):

```dart
  if (state.status.isFailure) ...[
    const SizedBox(height: 8),
    Text(
      _failureText(l10n, state.failure),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  ],
```

```dart
  String _failureText(AppLocalizations l10n, UsersFailure? failure) =>
      switch (failure) {
        MembershipAlreadyExistsFailure() => l10n.membershipExistsError,
        LinkedUserSuspendedFailure() => l10n.linkedUserSuspendedError,
        UsersForbiddenFailure() => l10n.usersForbiddenError,
        UsersRateLimitFailure() => l10n.tooManyAttemptsError,
        _ => l10n.genericError,
      };
```

**e) Doc comment:** se actualiza — ya no "solo UI"; el submit pega al
endpoint real y el sheet devuelve el `OrgMember` del backend.

## 20. `users_screen.dart` (archivo existente — actualización)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

**Antes:**

```dart
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.memberCreatedFeedback),
      ),
    );
```

**Después:**

```dart
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          // linked: el email ya existía globalmente — solo se creó la
          // membresía y no hay contraseña temporal que compartir.
          created.linked
              ? AppLocalizations.of(context)!.memberLinkedFeedback(
                  created.name,
                )
              : AppLocalizations.of(context)!.memberCreatedFeedback,
        ),
      ),
    );
```

Y el doc comment del método/pantalla: la creación ya pega a
`POST /auth/users` real; el insert local sigue siendo el reflejo
optimista hasta la propuesta de `GET /auth/users`.

## 21. `setup_di.dart` (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

Al final del bloque de auth (después de `RegisterCubit`), nuevo bloque:

```dart
  // ── Módulo Usuarios ──
  locator.registerLazySingleton<IRemoteUsersDataSource>(
    () => RemoteUsersDataSourceImpl(locator<INetworkService>()),
  );
  locator.registerLazySingleton<IUsersRepository>(
    () => UsersRepositoryImpl(
      locator<IRemoteUsersDataSource>(),
      locator<INetworkInfo>(),
      locator<ILoggerService>(),
    ),
  );
  locator.registerLazySingleton(
    () => CreateUserUseCase(locator<IUsersRepository>()),
  );
  // Cubit de sheet: factory — nace y muere con cada apertura.
  locator.registerFactory(() => CreateUserCubit(locator<CreateUserUseCase>()));
```

## 22. i18n — keys nuevas

`lib/l10n/app_es.arb`:

```json
"memberLinkedFeedback": "{name} ya tenía cuenta — quedó vinculado y entra con su contraseña actual",
"@memberLinkedFeedback": { "placeholders": { "name": { "type": "String" } } },
"membershipExistsError": "Ese correo ya pertenece a esta organización",
"linkedUserSuspendedError": "Esa cuenta está suspendida — no se puede vincular",
"usersForbiddenError": "No tenés permisos para gestionar usuarios",
"tooManyAttemptsError": "Demasiados intentos — esperá un momento",
"genericError": "Ocurrió un error — intentalo de nuevo",
```

`app_en.arb`:

```json
"memberLinkedFeedback": "{name} already had an account — linked and signs in with their current password",
"membershipExistsError": "That email already belongs to this organization",
"linkedUserSuspendedError": "That account is suspended — it can't be linked",
"usersForbiddenError": "You don't have permission to manage users",
"tooManyAttemptsError": "Too many attempts — wait a moment",
"genericError": "Something went wrong — try again",
```

`app_pt.arb`:

```json
"memberLinkedFeedback": "{name} já tinha conta — ficou vinculado e entra com a senha atual",
"membershipExistsError": "Esse e-mail já pertence a esta organização",
"linkedUserSuspendedError": "Essa conta está suspensa — não pode ser vinculada",
"usersForbiddenError": "Você não tem permissão para gerenciar usuários",
"tooManyAttemptsError": "Muitas tentativas — aguarde um momento",
"genericError": "Ocorreu um erro — tente novamente",
```

Después: `flutter gen-l10n`.

## 23. Tests

**Nuevos:**

- `test/features/users/domain/use_cases/create_user_use_case_test.dart` —
  repo mockeado (mocktail): datos inválidos → `InvalidMemberDataFailure`
  sin tocar el repo (caso por campo); válidos → passthrough del
  `Right(member)`/`Left(failure)`; verifica normalización email
  (trim+lowercase) al llamar al repo.
- `test/features/users/data/repositories/users_repository_impl_test.dart`
  — mocks de `IRemoteUsersDataSource`/`INetworkInfo`/`ILoggerService`:
  offline → `UsersNetworkFailure`; 403 → `UsersForbiddenFailure`;
  `409+MEMBERSHIP_ALREADY_EXISTS` → `MembershipAlreadyExistsFailure`;
  `409+USER_SUSPENDED` → `LinkedUserSuspendedFailure`; `409` sin
  errorCode → `UsersServerFailure`; 429 → `UsersRateLimitFailure`; 500 →
  `UsersServerFailure`; excepción no-RestApi → `UsersServerFailure`.
- `test/features/users/presentation/cubit/create_user_cubit_test.dart` —
  `blocTest`: submit OK → `[inProgress, success+member]`; failure →
  `[inProgress, failure+f]`; doble submit en vuelo → ignorado (use case
  llamado una vez).
- `test/features/users/data/models/org_member_model_test.dart` —
  `fromJson` del shape 007: campos completos, `linked` ausente → false,
  `role`/`status` desconocidos → operator/active.

**Actualizados:**

- `test/features/users/presentation/widgets/new_user_sheet_test.dart` —
  `show(..., cubit: mockCubit)`: casos existentes adaptados; nuevos:
  submit válido llama al cubit con los valores normalizados; estado
  `inProgress` → spinner y botones deshabilitados; `success` → pop con
  el miembro; `failure` → texto inline y el sheet sigue abierto.
- `test/features/users/presentation/screens/users_screen_test.dart` —
  `setUp`: `locator.registerFactory<CreateUserCubit>(() => mock)`;
  `tearDown`: `locator.reset()`. Nuevo: snackbar de `linked` cuando el
  miembro devuelto trae `linked: true`.

## 24. Design system

`Design/quesivo-design-system.yaml` → `1.10.1`: `QuesivoPrimaryButton`
gana `isLoading` (spinner navy 22px); `new_user_sheet` documenta el
submit async (campos bloqueados + error inline); `member_actions`/página
anota que la creación ya pega a `POST /auth/users` real con feedback
`created`/`linked`. Changelog correspondiente.

---

## Orden de aplicación

1. `auth_exceptions.dart` (+`errorCode`) → `dio_network_service_impl.dart`
   → `http_network_service_impl.dart` (plomería de errores primero).
2. Dominio: `users_failure.dart` → VOs → `org_member.dart` (+`linked`,
   `MemberStatus.fromApi`) → `i_users_repository.dart` →
   `create_user_use_case.dart`.
3. Data: `org_member_model.dart` → datasource I + impl →
   `users_repository_impl.dart`.
4. Presentation: `create_user_state.dart` → `create_user_cubit.dart`.
5. Widgets core: `quesivo_primary_button.dart` (+`isLoading`) →
   `quesivo_text_field.dart` (+`enabled`).
6. `new_user_sheet.dart` → `users_screen.dart`.
7. ARBs → `flutter gen-l10n`.
8. `setup_di.dart` (registros — al final para no resolver algo que aún
   no existe).
9. Tests (nuevos + actualizados).
10. `dart format` en archivos tocados → `flutter analyze` →
    `flutter test test/features/users test/features/auth test/core`.
11. Design-system yaml → `1.10.1`.

## Verificación manual esperada

Con el backend arriba: FAB → llenar el form → "Crear usuario" muestra
spinner → `POST /auth/users 201` en el backend → la card aparece al tope
con snackbar "Usuario creado". Repetir con el mismo email → `409` →
mensaje inline "ya pertenece a esta organización" y el sheet NO se
cierra. Crear con el email de una cuenta global existente (otra org) →
`201 linked:true` → snackbar de vinculación.
