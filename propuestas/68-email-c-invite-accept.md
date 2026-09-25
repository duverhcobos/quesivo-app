# Propuesta 68 — Email-C: invitación por correo (frontend completo)

## Problema

El backend ya implementó Email-C (propuesta 070 + compañera 071):

- `POST /auth/users` sin `password` → crea user `pending_verification` y
  envía correo con link `accept-invite`.
- `POST /auth/accept-invite` (doc 017) → `{token, password, deviceId?,
  deviceName?}` → consume el token `invite`, setea el primer password,
  activa la cuenta y **auto-loguea** (`AuthResponseDto`, igual que
  verify-email).
- `POST /auth/users/:id/resend-invite` (doc 018) → 204, ADMIN, reenvía el
  mail; `400 INVITE_NOT_PENDING` si ya aceptó.
- `GET /auth/users` (071) → cada ítem trae `userStatus` (global) además
  de `status` (membresía).
- `POST /auth/resend-verification` → para un invitado pendiente sin
  password reenvía el mail de **invitación** (no el de verificación).

En la app falta todo: la pantalla que abre el link del correo, el modo
invitación en el sheet de crear usuario, y el reenvío desde el ⋮.

## Flujo objetivo

```
admin crea invitación (sheet, sin password)
  → correo "Te invitaron a <org>" al email del invitado
  → link https://…/accept-invite?token=…&email=…  (Pages → quesivo://)
  → app abre /accept-invite: email + form password+confirm
  → POST /auth/accept-invite → sesión guardada → /home (selector)

⋮ sobre un miembro con userStatus=pending_verification:
  → "Reenviar invitación" → POST resend-invite → toast
```

## Decisiones de diseño

1. **El sheet de creación gana un toggle** "Invitar por correo" (default) /
   "Contraseña manual" — invitar es el camino recomendado (el invitado elige
   su password; no circula un temporal en claro). Modo manual se conserva
   (caso real: operario sin correo propio, compartido a mano).
2. **Sin password ⇒ invite** — el `password` del body se omite cuando es
   `null`; es lo que dispara el modo invite en el backend (070).
3. **`accept-invite` reutiliza `ResendVerificationUseCase`** para "pedir
   link nuevo" en el estado de link inválido — el backend ya detecta el
   invitado pendiente y le manda el mail de invitación correcto.
4. **`invitePending` (071 post-auditoría) es el gate** del badge
   "Invitación pendiente" y del ítem "Reenviar invitación" del ⋮ — la
   regla exacta del backend es `pending_verification` + sin password (un
   auto-registrado sin verificar también es `pending_verification` pero
   tiene password → `userStatus` solo daría falsos positivos). El ítem
   también trae `userStatus` (dato crudo, no se usa para gatear). Sin el
   campo (backend viejo) el badge no aparece — degradación limpia.
5. El invitado acepta como **sesión personal** (sin org) — igual que
   verify-email/login: `AuthCubit.refreshSession()` y el guard rutea a
   `/home` con el selector de queseras. Un OPERATOR invitado verá su
   membresía en el selector y `select-organization` le dará
   `ROLE_NOT_ALLOWED` (gate MVP — comportamiento esperado).

## Archivos NUEVOS (código completo)

### 1. `lib/features/auth/domain/use_cases/accept_invite_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: aceptar la invitación con el `token` del correo + el
/// primer password (Email-C, backend 070 — doc 017). Éxito = cuenta
/// activa + sesión guardada (auto-login, mismo contrato que verify-email).
class AcceptInviteUseCase {
  final IAuthRepository repository;

  const AcceptInviteUseCase(this.repository);

  Future<Either<AuthFailure, User>> call({
    required String token,
    required String password,
  }) {
    return repository.acceptInvite(token: token, password: password);
  }
}
```

### 2. `lib/features/auth/presentation/cubit/accept_invite_state.dart`

Mismo molde que `ResetPasswordState` + `email` y `resendStatus` de
`VerifyEmailState`:

```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/register_password.dart';

/// Estado de la pantalla accept-invite: `status` = el submit del form
/// (initial → inProgress → success/failure); `resendStatus` = el reenvío
/// del link desde el estado de link inválido. `email` viene del query
/// param (se muestra y alimenta el reenvío).
class AcceptInviteState extends Equatable {
  final String email;
  final RegisterPassword password;
  final ConfirmPassword confirmPassword;
  final FormzSubmissionStatus status;
  final FormzSubmissionStatus resendStatus;
  final String? errorMessage;
  final bool isValid;

  const AcceptInviteState({
    required this.email,
    this.password = const RegisterPassword.pure(),
    this.confirmPassword = const ConfirmPassword.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.resendStatus = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isValid = false,
  });

  AcceptInviteState copyWith({
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
    FormzSubmissionStatus? status,
    FormzSubmissionStatus? resendStatus,
    String? errorMessage,
    bool? isValid,
  }) {
    return AcceptInviteState(
      email: email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      status: status ?? this.status,
      resendStatus: resendStatus ?? this.resendStatus,
      errorMessage: errorMessage,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    confirmPassword,
    status,
    resendStatus,
    errorMessage,
    isValid,
  ];
}
```

### 3. `lib/features/auth/presentation/cubit/accept_invite_cubit.dart`

Fusión de `ResetPasswordCubit` (form + token + submit) y `VerifyEmailCubit`
(resend). El submit NO corre solo — espera el form completo:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/use_cases/accept_invite_use_case.dart';
import '../../domain/use_cases/resend_verification_use_case.dart';
import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/register_password.dart';
import 'accept_invite_state.dart';

/// Cubit de accept-invite: recibe `token` + `email` del deep link
/// (inyectados por `AppRouter` desde el query). A diferencia de
/// verify-email no hay llamada al entrar — el submit espera el password
/// del invitado. Éxito → la sesión ya quedó guardada por el repo y el
/// listener llama `AuthCubit.refreshSession()`.
class AcceptInviteCubit extends Cubit<AcceptInviteState> {
  final AcceptInviteUseCase _acceptInvite;
  final ResendVerificationUseCase _resendVerification;
  final String _token;

  AcceptInviteCubit(
    this._acceptInvite,
    this._resendVerification, {
    required String token,
    required String email,
  }) : _token = token,
       super(AcceptInviteState(email: email));

  bool _validate({
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
  }) {
    return Formz.validate([
      password ?? state.password,
      confirmPassword ?? state.confirmPassword,
    ]);
  }

  void passwordChanged(String value) {
    // Igual que ResetPasswordCubit: al cambiar el password se re-evalúa
    // la confirmación (su regla depende del valor actualizado).
    final password = RegisterPassword.dirty(value);
    final confirmPassword = state.confirmPassword.isPure
        ? state.confirmPassword
        : ConfirmPassword.dirty(
            password: password.value,
            value: state.confirmPassword.value,
          );
    emit(
      state.copyWith(
        password: password,
        confirmPassword: confirmPassword,
        isValid: _validate(
          password: password,
          confirmPassword: confirmPassword,
        ),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  void confirmPasswordChanged(String value) {
    final confirmPassword = ConfirmPassword.dirty(
      password: state.password.value,
      value: value,
    );
    emit(
      state.copyWith(
        confirmPassword: confirmPassword,
        isValid: _validate(confirmPassword: confirmPassword),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  Future<void> submit() async {
    if (!state.isValid || state.status.isInProgress) return;

    // Deep link sin `?token=` — mismo criterio que ResetPasswordCubit:
    // es un link inválido, no un error de red.
    if (_token.isEmpty) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: const InvalidOrExpiredTokenFailure().message,
        ),
      );
      return;
    }

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _acceptInvite(
      token: _token,
      password: state.password.value,
    );

    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: FormzSubmissionStatus.success)),
    );
  }

  /// "Pedir link nuevo" desde el estado inválido: el backend detecta al
  /// invitado pendiente sin password y le manda el mail de INVITACIÓN
  /// (no el de verificación — propuesta backend 070).
  Future<void> resend() async {
    if (state.resendStatus.isInProgress || state.email.isEmpty) return;

    emit(state.copyWith(resendStatus: FormzSubmissionStatus.inProgress));

    final result = await _resendVerification(state.email);

    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          resendStatus: FormzSubmissionStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(
        state.copyWith(resendStatus: FormzSubmissionStatus.success),
      ),
    );
  }
}
```

### 4. `lib/features/auth/presentation/screens/accept_invite_screen.dart`

Estructura = `VerifyEmailScreen` (backdrop + brand header + BlocListener
de success → `refreshSession`) con el form de `ResetPasswordScreen`
(password + confirm + checklist) en el estado inicial. Dos vistas:

- **Form** (`status` initial/inProgress): AuthHeading
  (`acceptInviteTitle`/`acceptInviteDescription` con el email interpolado),
  `QuesivoTextField` password + confirm (obscure, mismos formatters de
  reset), `PasswordRequirementsChecklist` sobre `RegisterPassword`, botón
  `acceptInviteButton` (habilitado por `isValid`, spinner en inProgress).
  Error de submit (no-token): `QuesivoToast.error` vía listener + el form
  queda para reintentar — EXCEPTO `InvalidOrExpiredTokenFailure` que
  cambia a la vista de link inválido.
- **Link inválido** (`status` failure Y `errorMessage` ==
  `InvalidOrExpiredTokenFailure().message`, o token vacío): misma vista de
  verify-email — `AuthHeading` invalid + botón "Pedir link nuevo"
  (`acceptInviteResendButton`) si `email` no vacío → `resend()` → success
  muestra `ForgotPasswordInfoCard` (`resendVerificationSuccess*` keys
  existentes) + link "Iniciar sesión" → `/login`.

Guía: copiar `VerifyEmailScreen` como esqueleto (mismo backdrop
`topCircleFraction: 0.68`), cambiar el builder: form mientras `status` no
sea failure-de-token; el listener llama `refreshSession()` en success.
Campos del form = los de `ResetPasswordScreen` (labels `newPasswordLabel`,
`confirmPasswordLabel`, checklist `passwordReq*` — keys existentes).
Password visible por defecto NO — copiar la obscure-treatment de
reset-password (los invitados eligen password propio, a diferencia del
temporal del admin que era visible).

### 5. `lib/features/users/domain/use_cases/resend_invite_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../failures/users_failure.dart';
import '../repositories/i_users_repository.dart';

/// Caso de Uso: reenviar el correo de invitación a un miembro pendiente
/// (`POST /auth/users/:id/resend-invite`, doc 018 — Email-C 070). Solo
/// aplica a `userStatus == pending_verification`; un activo da
/// `InviteNotPendingFailure` (el ⋮ no lo ofrece — llega solo por data
/// stale).
class ResendInviteUseCase {
  final IUsersRepository repository;

  const ResendInviteUseCase(this.repository);

  Future<Either<UsersFailure, void>> call({required String userId}) {
    return repository.resendInvite(userId: userId);
  }
}
```

### 6. Tests nuevos

- `test/features/auth/presentation/cubit/accept_invite_cubit_test.dart` —
  bloc_test: validación del form (confirm mismatch → isValid false),
  submit inProgress→success, `INVALID_OR_EXPIRED_TOKEN` → failure con
  mensaje de token, token vacío → failure sin llamar al use case, resend
  inProgress→success. Mocks con mocktail (mismo estilo que
  `verify_email_cubit_test.dart` / `reset_password_cubit_test.dart`).
- `test/features/auth/data/datasources/remote_auth_datasource_impl_test.dart`
  — caso `acceptInvite`: endpoint `/auth/accept-invite` + body
  `{token,password,deviceId,deviceName}` (mismo patrón del test de
  verifyEmail).
- `test/features/auth/data/repositories/auth_repository_impl_test.dart` —
  `acceptInvite`: éxito persiste sesión (`saveUserSession` llamado), 400
  INVALID_OR_EXPIRED_TOKEN → `InvalidOrExpiredTokenFailure`, 400
  INVALID_PASSWORD → `WeakPasswordFailure`, sin red → `NetworkFailure`.
- `test/core/deeplink/app_links_deep_link_service_impl_test.dart` — caso
  `quesivo://accept-invite?token=…&email=…` → `/accept-invite` con query
  preservado (mismo patrón que verify-email).
- `test/features/users/data/repositories/users_repository_impl_test.dart`
  — `resendInvite`: éxito void, 400 INVITE_NOT_PENDING →
  `InviteNotPendingFailure`, 404 → `MemberNotFoundFailure`.
- `org_member_model` test (si existe el archivo de model tests — si no,
  cubrir el parse en el repo test): `invitePending: true` en ambos
  factories (listado y create); ausente → `false`.
- Widget test `accept_invite_screen_test.dart` — render del form, submit
  habilitado solo con form válido, vista inválida con token error.

## Archivos MODIFICADOS (fragmentos)

### 7. `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart`

```dart
  /// Acepta la invitación con el `token` del correo + el primer password
  /// (Email-C, doc 017): consume el código `invite`, activa la cuenta y
  /// devuelve la sesión emitida — auto-login igual que `verifyEmail`.
  Future<UserModel> acceptInvite({
    required String token,
    required String password,
  });
```

### 8. `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

```dart
  @override
  Future<UserModel> acceptInvite({
    required String token,
    required String password,
  }) async {
    // Contrato real (documentacion/api/auth/017-post-accept-invite.md):
    // la sesión emitida es PERSONAL (sin org) — igual que verifyEmail.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/accept-invite',
      data: {
        'token': token,
        'password': password,
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );
    return UserModel.fromJson(responseData);
  }
```

### 9. `lib/features/auth/domain/repositories/i_auth_repository.dart`

```dart
  /// Acepta la invitación con el token del correo (Email-C, backend 070)
  /// — deep link `quesivo://accept-invite?token=…`. Éxito = cuenta activa
  /// + sesión guardada (auto-login, igual que `verifyEmail`).
  Future<Either<AuthFailure, User>> acceptInvite({
    required String token,
    required String password,
  });
```

### 10. `lib/features/auth/data/repositories/auth_repository_impl.dart`

```dart
  @override
  Future<Either<AuthFailure, User>> acceptInvite({
    required String token,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      // Auto-login (backend 070): la sesión emitida se guarda igual que
      // en verifyEmail — el listener llama refreshSession() y el guard
      // rutea a /home.
      final userModel = await remoteDataSource.acceptInvite(
        token: token,
        password: password,
      );
      await localDataSource.saveUserSession(userModel);
      return Right(userModel);
    } on RestApiException catch (e, stackTrace) {
      // Doc 017: 400 + errorCode distingue link inválido de password
      // débil — mismos dos mapeos que resetPassword.
      if (e.statusCode == 400) {
        if (e.errorCode == 'INVALID_OR_EXPIRED_TOKEN') {
          return const Left(InvalidOrExpiredTokenFailure());
        }
        if (e.errorCode == 'INVALID_PASSWORD') {
          return const Left(WeakPasswordFailure());
        }
      }
      logger.error(
        'Error de API al aceptar invitación',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al aceptar invitación',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }
```

### 11. `lib/core/routes/auth_guard.dart`

```dart
  static const String verifyEmailRoute = '/verify-email';
  static const String acceptInviteRoute = '/accept-invite';
```
y en `publicRoutes` agregar `acceptInviteRoute` después de `verifyEmailRoute`.

### 12. `lib/core/routes/app_router.dart`

Después del GoRoute de `verifyEmailRoute`:

```dart
      GoRoute(
        path: AuthGuard.acceptInviteRoute,
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          context: context,
          state: state,
          // Token + email del deep link `quesivo://accept-invite?…`.
          child: AcceptInviteScreen(
            cubit: locator<AcceptInviteCubit>(
              param1: state.uri.queryParameters['token'] ?? '',
              param2: state.uri.queryParameters['email'] ?? '',
            ),
          ),
        ),
      ),
```

### 13. `lib/core/deeplink/app_links_deep_link_service_impl.dart`

En `knownRoutes` agregar `AuthGuard.acceptInviteRoute` (mantener el
comentario del set actualizado).

### 14. `lib/core/di/setup_di.dart`

```dart
    () => AcceptInviteUseCase(locator<IAuthRepository>()),
```
(junto a VerifyEmailUseCase) y con los cubits:

```dart
  locator.registerFactoryParam<AcceptInviteCubit, String, String>(
    (token, email) => AcceptInviteCubit(
      locator<AcceptInviteUseCase>(),
      locator<ResendVerificationUseCase>(),
      token: token,
      email: email,
    ),
  );
```

### 15. `lib/features/users/domain/entities/org_member.dart`

`OrgMember` gana `final bool invitePending` (required en el constructor,
en `copyWith`, en `props`) — `true` solo cuando el miembro es un invitado
que aún no aceptó (regla backend: `userStatus=pending_verification` + sin
password). Es el gate del badge y del ítem "Reenviar invitación" del ⋮.
Docblock: `status` = membresía; `invitePending` viene derivado del backend
— un `userStatus` pendiente CON password (auto-registrado sin verificar
que se vinculó por link) NO es un invitado y no lo marca.

### 16. `lib/features/users/data/models/org_member_model.dart`

Constructor + `invitePending`. Dos shapes de contrato (ambos traen el
campo desde el backend post-071 — listado/PATCH en doc 008+ y
create/link en doc 007):

```dart
  /// Ítems del listado/PATCH (doc 008+): `status` = membresía,
  /// `userStatus` = global, `invitePending` = invitado sin aceptar.
  /// Create/link (doc 007): `status` ES el del usuario + `invitePending`
  /// igual — `fromCreatedJson` lo interpreta así (la membresía nueva
  /// siempre nace `active`).
  factory OrgMemberModel.fromJson(Map<String, dynamic> json) {
    return OrgMemberModel(
      ...,
      invitePending: json['invitePending'] == true,
      ...
    );
  }

  factory OrgMemberModel.fromCreatedJson(Map<String, dynamic> json) {
    return OrgMemberModel(
      ...,
      status: MemberStatus.active,
      invitePending: json['invitePending'] == true,
      ...
    );
  }
```

### 17. `lib/features/users/data/datasources/interfaces/i_remote_users_datasource.dart`

```dart
  /// `POST /auth/users` — `password == null` → modo invitación (Email-C,
  /// backend 070): el user queda `pending_verification` y recibe el mail.
  Future<OrgMemberModel> createUser({
    required String name,
    required String email,
    required String? password,
    required UserRole role,
  });

  /// `POST /auth/users/:id/resend-invite` — reenvía el mail al miembro
  /// pendiente (doc 018). 204 sin body; `INVITE_NOT_PENDING` si ya aceptó.
  Future<void> resendInvite({required String userId});
```

### 18. `lib/features/users/data/datasources/implementations/remote_users_datasource_impl.dart`

```dart
    final data = await networkService.post<Map<String, dynamic>>(
      '/auth/users',
      data: {
        'name': name,
        'email': email,
        // Ausente = invite mode (070): el backend crea el user
        // pending_verification + manda el mail con el link accept-invite.
        if (password != null) 'password': password,
        'role': role.apiValue,
      },
    );
    return OrgMemberModel.fromCreatedJson(data);
```
(`linkUser` también cambia a `fromCreatedJson` — su `status` también es
del user.) Y:

```dart
  /// `POST /auth/users/:id/resend-invite` real (doc 018) — 204 sin body.
  @override
  Future<void> resendInvite({required String userId}) async {
    await networkService.post<void>('/auth/users/$userId/resend-invite');
  }
```

### 19. `lib/features/users/domain/repositories/i_users_repository.dart`

`createUser` con `String? password` + doc actualizada, y:

```dart
  /// `POST /auth/users/:id/resend-invite` — reenvía el mail de invitación
  /// (doc 018). Errores: `InviteNotPendingFailure` (400 — ya aceptó),
  /// `MemberNotFoundFailure` (404), 403/429/red como arriba.
  Future<Either<UsersFailure, void>> resendInvite({required String userId});
```

### 20. `lib/features/users/domain/failures/users_failure.dart`

```dart
/// El miembro no está pendiente de invitación (`INVITE_NOT_PENDING`, doc
/// 018): ya aceptó o fue creado con password manual. Defensivo — el ⋮ no
/// ofrece reenviar a un activo; llega solo con data stale.
class InviteNotPendingFailure extends UsersFailure {
  const InviteNotPendingFailure();

  @override
  String get message => 'El usuario ya aceptó la invitación';
}
```

### 21. `lib/features/users/data/repositories/users_repository_impl.dart`

- `createUser`: `String? password` passthrough.
- `_mapError` case 400: `'INVITE_NOT_PENDING' => const InviteNotPendingFailure()`.
- `resendInvite` con el molde estándar:

```dart
  @override
  Future<Either<UsersFailure, void>> resendInvite({
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(UsersNetworkFailure());
    }
    try {
      await remoteDataSource.resendInvite(userId: userId);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      return Left(_mapError(e, stackTrace));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado reenviando invitación',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(UsersServerFailure());
    }
  }
```

### 22. `lib/features/users/domain/use_cases/create_user_use_case.dart`

`password` → `String?`; la validación `TempPassword` solo aplica cuando
viene (invite mode no pide password — el invitado elige el suyo):

```dart
    final valid =
        MemberName.dirty(name).isValid &&
        MemberEmail.dirty(email).isValid &&
        (password == null || TempPassword.dirty(password).isValid);
```

### 23. `lib/features/users/presentation/cubit/create_user_cubit.dart`

`submit` con `String? password` — passthrough al use case.

### 24. `lib/features/users/presentation/cubit/users_list_cubit.dart`

Nuevo método con el molde de `setMemberStatus` (busy + Either crudo a la
screen; nada que mergear en éxito — el miembro sigue pendiente hasta que
acepte):

```dart
  /// `POST /auth/users/:id/resend-invite` real (Email-C, doc 018):
  /// busy mientras vuela, Either a la screen para el toast. Sin merge —
  /// el 204 no trae body y el estado no cambia (sigue pendiente).
  Future<Either<UsersFailure, void>> resendInvite(OrgMember member) async {
    if (state.busyMemberIds.contains(member.id)) {
      return const Right(null);
    }
    emit(state.copyWith(busyMemberIds: {...state.busyMemberIds, member.id}));
    final result = await _resendInvite(userId: member.id);
    if (isClosed) return result;
    emit(
      state.copyWith(
        busyMemberIds: {...state.busyMemberIds}..remove(member.id),
      ),
    );
    return result;
  }
```
(agregar `ResendInviteUseCase _resendInvite` al constructor.)

### 25. `lib/features/users/presentation/widgets/new_user_sheet.dart`

Toggle de modo arriba del campo password:

- Estado `_inviteMode = true` (default) — `SegmentedButton` o dos chips
  con el estilo de `RoleSelectorChips`: "Invitar por correo" /
  "Contraseña manual".
- Invite mode: se ocultan el field de password y el checklist; en su
  lugar un texto de hint (`newUserInviteHint`: "Le llegará un correo con
  un enlace para crear su contraseña."). `_passwordError` no se evalúa.
- Manual mode: form actual intacto.
- `_submit`: `password: _inviteMode ? null : _password`.
- Hint del sheet (`newUserSheetHint`) se mantiene.

### 26. `lib/features/users/presentation/widgets/member_actions_menu.dart`

- Nuevo ítem `'invite'` — "Reenviar invitación" (`resendInviteAction`),
  icono `Icons.mail_outline`, color `quesivoDarkText` (neutro, no
  destructivo), posición: PRIMERO del menú (acción contextual del
  pendiente).
- Solo se agrega cuando `member.invitePending` es `true`.
- `_onSelected` case 'invite' → `onResendInvite(member)` (nuevo callback
  `ValueChanged<OrgMember>` requerido — sin confirmación: es una acción
  informativa barata, mismo criterio que §45 con confirm liviana —
  el mail se manda y listo).
- Cuando el miembro es pendiente, ¿ocultar el resto? **No** — suspender
  una membresía pendiente es válido; reset de password sobre un
  passwordless da error backend (`INVALID_PASSWORD`... verificar: 070 —
  reset sobre user sin password: el use-case de admin reset setea hash y
  activa? NO — backend 070 no tocó `updateUserPassword`; un admin-reset
  sobre un invitado pendiente setearía su password sin verificar el mail.
  Decisión: en pendientes se ofrecen las 4 acciones — el admin reset es
  un escape legítimo ("te la seteo yo a mano"). Se documenta en la card.)

### 27. `lib/features/users/presentation/widgets/org_member_card.dart`

- Param `required this.onResendInvite` (ValueChanged<OrgMember>) pasado al
  `MemberActionsMenu`.
- Badge "Invitación pendiente" (`invitePendingBadge`): pill tipo
  `MemberStatusChip` con `AppColors.quesivoWarning` (ámbar — pendiente de
  acción), visible cuando `member.invitePending`. Se suma
  al Wrap junto a rol/status/owner.
- `isBusy` cubre el ⋮ igual que ahora (el resend marca busy).

### 28. `lib/features/users/presentation/widgets/users_list_body.dart`

Param `required this.onResendInvite` → pasa a `OrgMemberCard`.

### 29. `lib/features/users/presentation/screens/users_screen.dart`

```dart
  /// Email-C (§68) — reenvío real vía POST /auth/users/:id/resend-invite:
  /// el cubit pone la card en busy; éxito → toast verde, error → toast
  /// con la regla (INVITE_NOT_PENDING con data stale → "ya aceptó").
  Future<void> _resendInvite(OrgMember member) async {
    final result = await context.read<UsersListCubit>().resendInvite(member);
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
          message: l10n.inviteResentFeedback(member.email),
        );
    }
  }
```
y en `_memberActionErrorText` agregar:
`InviteNotPendingFailure() => l10n.inviteNotPendingError,`
y `onResendInvite: _resendInvite` en el `UsersListBody`.

### 30. l10n — `app_es.arb` / `app_en.arb` / `app_pt.arb`

Keys nuevas (es / en / pt):

| key | es | en | pt |
|-----|----|----|----|
| `acceptInviteTitle` | "Definí tu contraseña" | "Set your password" | "Defina sua senha" |
| `acceptInviteDescription` | "Fuiste invitado a {org}. Creá tu contraseña para entrar." — cuidado: el email viene por param, el ORG no (el link no lo trae) → mejor: "Te invitaron a unirte. Creá tu contraseña para {email}." | "You were invited to join. Create your password for {email}." | "Você foi convidado. Crie sua senha para {email}." |
| `acceptInviteButton` | "Crear contraseña y entrar" | "Create password & sign in" | "Criar senha e entrar" |
| `acceptInviteInvalidTitle` | "Este enlace ya no es válido" | "This link is no longer valid" | "Este link não é mais válido" |
| `acceptInviteInvalidDescription` | "El enlace de invitación expiró o ya fue usado. Pedí uno nuevo." | "The invite link expired or was already used. Ask for a new one." | "O link de convite expirou ou já foi usado. Peça um novo." |
| `acceptInviteResendButton` | "Pedir link nuevo" | "Request new link" | "Pedir novo link" |
| `newUserInviteMode` | "Invitar por correo" | "Invite by email" | "Convidar por e-mail" |
| `newUserManualMode` | "Contraseña manual" | "Manual password" | "Senha manual" |
| `newUserInviteHint` | "Le llegará un correo con un enlace para crear su contraseña." | "They'll get an email with a link to set their password." | "Eles receberão um e-mail com um link para criar a senha." |
| `invitePendingBadge` | "Invitación pendiente" | "Invite pending" | "Convite pendente" |
| `resendInviteAction` | "Reenviar invitación" | "Resend invitation" | "Reenviar convite" |
| `inviteResentFeedback` | "Invitación reenviada a {email}" | "Invitation resent to {email}" | "Convite reenviado para {email}" |
| `inviteNotPendingError` | "El usuario ya aceptó la invitación" | "The user already accepted the invitation" | "O usuário já aceitou o convite" |

Con placeholders en `@key` metadata según el patrón de las keys
parametrizadas existentes (`memberLinkedFeedback` etc.). Después:
`flutter gen-l10n` — los generados NO se tocan a mano.

### 31. `Design/quesivo-design-system.yaml`

Bump de versión + changelog (propuesta 68): spec de la pantalla
accept-invite (backdrop 0.68, brand header, form password+confirm +
checklist, vista inválida con reenvío), toggle del NewUserSheet, badge
ámbar "Invitación pendiente", ítem ⋮ "Reenviar invitación".

## Verificación

```bash
flutter gen-l10n
dart format <archivos tocados>
flutter analyze
flutter test
```

**Hot restart completo** (no hot reload) tras el cambio de router — el
router se instancia una sola vez.

Prueba E2E (emulador, backend 070+071 arriba):
1. Admin → Usuarios → Crear → modo "Invitar por correo" → crear → mail a
   Gmail (sandbox redirect) + card aparece con badge "Invitación
   pendiente".
2. ⋮ de la card → "Reenviar invitación" → toast.
3. Abrir el mail → link → app abre accept-invite → definir password →
   auto-login → /home.
4. Link reusado → vista "enlace ya no es válido" + "Pedir link nuevo" →
   llega mail de invitación.

## Dependencias

- **Backend 071** (`userStatus` + `invitePending` en el listado y en la
  respuesta de create/link) — sin él el badge y el ⋮ "Reenviar" nunca
  aparecen (degradación limpia: todo lo demás funciona).
- `quesivo-redirect/accept-invite/` ya publicada (commit `a636f4a`).

## Fuera de alcance

- Deep link verificado (App Links) — pendiente 002, pre-producción.
- Suspender al invitado pendiente desde el ⋮ funciona pero no se agrega
  UI específica — el menú normal ya lo cubre.
