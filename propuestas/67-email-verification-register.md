# Propuesta: Verificación de email en registro — integración Flutter

Compañera de la propuesta backend 069 (`pendientes/004`): `POST /auth/register` ya no devuelve tokens — la cuenta nace `pending_verification` y el correo trae un link `quesivo://verify-email?token=…&email=…` (vía la página de redirect de GitHub Pages, mismo mecanismo que reset). Esta propuesta conecta el flujo completo: pantalla "revisá tu correo" (check-email) tras registrarse o al hacer login sin verificar, pantalla verify-email que consume el token y **auto-loguea** (`POST /auth/verify-email` devuelve `AuthResponseDto` como login), y botón de reenvío (`POST /auth/resend-verification`).

**Cambio de contrato**: `IAuthRepository.register` / `IRemoteAuthDataSource.register` devuelven `void` (ya no `User` con sesión). El auto-login post-registro se movió a `verifyEmail`.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/failures/auth_failure.dart` | nuevo `EmailNotVerifiedFailure` |
| `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart` | `register`→void; +`verifyEmail`+`resendVerification` |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | implementa los 3 cambios |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | `register`→`Either<…,void>`; +`verifyEmail`→`User`; +`resendVerification` |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | register sin save; verifyEmail guarda sesión; resend como forgot; login mapea `EMAIL_NOT_VERIFIED` |
| `lib/features/auth/domain/use_cases/register_use_case.dart` | retorno `Either<AuthFailure, void>` |
| `lib/features/auth/domain/use_cases/verify_email_use_case.dart` | nuevo |
| `lib/features/auth/domain/use_cases/resend_verification_use_case.dart` | nuevo |
| `lib/features/auth/presentation/cubit/check_email_cubit.dart` + `_state.dart` | nuevo — pantalla "revisá tu correo" + reenvío |
| `lib/features/auth/presentation/cubit/verify_email_cubit.dart` + `_state.dart` | nuevo — verifica al entrar + reenvío |
| `lib/features/auth/presentation/screens/check_email_screen.dart` | nuevo |
| `lib/features/auth/presentation/screens/verify_email_screen.dart` | nuevo |
| `lib/core/routes/auth_guard.dart` | `verifyEmailRoute` + `checkEmailRoute` públicas |
| `lib/core/routes/app_router.dart` | 2 rutas nuevas con factories DI |
| `lib/core/deeplink/app_links_deep_link_service_impl.dart` | whitelist de rutas: reset-password + verify-email |
| `lib/core/di/setup_di.dart` | registra 2 use-cases + 2 cubit factories |
| `lib/features/auth/presentation/screens/register_screen.dart` | éxito → `/check-email?email=…` (ya no refreshSession) |
| `lib/features/auth/presentation/cubit/login_cubit.dart` + `login_state.dart` | flag `emailNotVerified` |
| `lib/features/auth/presentation/screens/login_screen.dart` | flag → navega a `/check-email` |
| `lib/l10n/app_es.arb` + `app_en.arb` + `app_pt.arb` | strings nuevos + `flutter gen-l10n` |
| `Design/quesivo-design-system.yaml` | spec de las 2 pantallas + changelog |
| tests | repo + datasource + deeplink + cubits |

---

## 1. `auth_failure.dart` (existente — actualización)

**Ruta:** `lib/features/auth/domain/failures/auth_failure.dart`

**Después** (agregar junto a `RoleNotAllowedFailure`):
```dart
/// La cuenta existe y el password es correcto, pero el correo todavía
/// no fue verificado (HTTP 403 + errorCode `EMAIL_NOT_VERIFIED` —
/// backend propuesta 069). La UI no muestra este mensaje en toast: lo
/// usa para navegar a `/check-email`, donde está el botón de reenvío.
class EmailNotVerifiedFailure extends AuthFailure {
  const EmailNotVerifiedFailure()
    : super('Tu correo todavía no está verificado. Revisá tu bandeja.');
}
```

## 2. `i_remote_auth_datasource.dart` (existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart`

**Antes:**
```dart
  /// Registra organización + usuario nuevo contra `POST /auth/register`.
  Future<UserModel> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  });
```

**Después:**
```dart
  /// Registra organización + usuario nuevo contra `POST /auth/register`.
  /// Desde la propuesta backend 069 el 201 viene con body vacío: la
  /// cuenta nace `pending_verification` y la sesión la emite
  /// `verifyEmail` al confirmar el correo.
  Future<void> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  });
```

**Después** (agregar al final, tras `selectOrganization`):
```dart
  /// Verifica el correo con el `token` del deep link
  /// (`POST /auth/verify-email`, doc 015). Devuelve la sesión emitida —
  /// auto-login con token personal, mismo shape que login.
  Future<UserModel> verifyEmail(String token);

  /// Reenvía el correo de verificación (`POST /auth/resend-verification`,
  /// doc 016). Siempre 200 — anti-enumeración.
  Future<void> resendVerification(String email);
```

## 3. `remote_auth_datasource_impl.dart` (existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

**Antes:**
```dart
  @override
  Future<UserModel> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    // Backend real en todos los entornos (propuesta 36) — contrato
    // documentacion/api/auth/001-post-register.md: organización + usuario
    // admin en una transacción atómica.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'organizationName': organizationName,
        'name': name,
        'email': email,
        'password': password,
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );
    return UserModel.fromJson(responseData);
  }
```

**Después:**
```dart
  @override
  Future<void> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    // Backend real en todos los entornos — contrato
    // documentacion/api/auth/001-post-register.md (propuesta backend
    // 069): 201 con body vacío, la cuenta queda pending_verification.
    // deviceId/deviceName se siguen enviando: el DTO los acepta (los
    // ignora — no hay sesión que etiquetar) y quitarlos rompería contra
    // un backend viejo que aún los exige.
    await networkService.post<void>(
      '/auth/register',
      data: {
        'organizationName': organizationName,
        'name': name,
        'email': email,
        'password': password,
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );
  }
```

**Después** (agregar al final):
```dart
  @override
  Future<UserModel> verifyEmail(String token) async {
    // Contrato real (documentacion/api/auth/015-post-verify-email.md):
    // la sesión emitida es PERSONAL (sin org) — igual que login.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/verify-email',
      data: {
        'token': token,
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );
    return UserModel.fromJson(responseData);
  }

  @override
  Future<void> resendVerification(String email) async {
    // Contrato real (documentacion/api/auth/016-post-resend-verification.md):
    // siempre 200 — anti-enumeración.
    await networkService.post<void>(
      '/auth/resend-verification',
      data: {'email': email},
    );
  }
```

## 4. `i_auth_repository.dart` (existente — actualización)

**Ruta:** `lib/features/auth/domain/repositories/i_auth_repository.dart`

**Antes:**
```dart
  /// Crea una organización + cuenta admin (nombre de quesera, nombre de
  /// usuario, email, contraseña) y devuelve el usuario con su sesión
  /// (access/refresh token) — el backend hace auto-login.
  Future<Either<AuthFailure, User>> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  });
```

**Después:**
```dart
  /// Crea una organización + cuenta admin — el usuario queda
  /// `pending_verification` (backend 069): NO hay sesión acá, la primera
  /// la emite `verifyEmail` cuando el link del correo se confirma.
  Future<Either<AuthFailure, void>> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  });
```

**Después** (agregar tras `resetPassword`):
```dart
  /// Verifica el correo con el `token` del deep link
  /// (`quesivo://verify-email?token=…`). Éxito = sesión guardada +
  /// User con token personal (auto-login — backend 069).
  Future<Either<AuthFailure, User>> verifyEmail({required String token});

  /// Reenvía el correo de verificación. Siempre 200 server-side —
  /// nunca revela si el email existe ni si ya está verificado.
  Future<Either<AuthFailure, void>> resendVerification(String email);
```

## 5. `auth_repository_impl.dart` (existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Antes:**
```dart
      if (e.statusCode == 403) {
        if (e.errorCode == 'ROLE_NOT_ALLOWED') {
          return const Left(RoleNotAllowedFailure());
        }
        return const Left(AccountSuspendedFailure());
      }
```

**Después:**
```dart
      if (e.statusCode == 403) {
        if (e.errorCode == 'ROLE_NOT_ALLOWED') {
          return const Left(RoleNotAllowedFailure());
        }
        // Credenciales válidas pero correo sin verificar (backend 069)
        // — la pantalla de login navega a /check-email con este flag.
        if (e.errorCode == 'EMAIL_NOT_VERIFIED') {
          return const Left(EmailNotVerifiedFailure());
        }
        return const Left(AccountSuspendedFailure());
      }
```

**Antes:**
```dart
  @override
  Future<Either<AuthFailure, User>> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final userModel = await remoteDataSource.register(
        organizationName: organizationName,
        name: name,
        email: email,
        password: password,
      );
      // Auto-login: el registro exitoso guarda sesión igual que el login.
      await localDataSource.saveUserSession(userModel);
      return Right(userModel);
    } on RestApiException catch (e, stackTrace) {
      if (e.statusCode == 409) {
        return const Left(EmailAlreadyInUseFailure());
      }
      logger.error(
        'Error de API al registrar usuario',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado durante el registro',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }
```

**Después:**
```dart
  @override
  Future<Either<AuthFailure, void>> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      // Sin sesión acá (backend 069): la cuenta queda pendiente de
      // verificación — la pantalla navega a /check-email.
      await remoteDataSource.register(
        organizationName: organizationName,
        name: name,
        email: email,
        password: password,
      );
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      if (e.statusCode == 409) {
        return const Left(EmailAlreadyInUseFailure());
      }
      logger.error(
        'Error de API al registrar usuario',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado durante el registro',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }
```

**Después** (agregar tras `resetPassword`, antes de `_mapUnmappedError`):
```dart
  @override
  Future<Either<AuthFailure, User>> verifyEmail({required String token}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      // Auto-login (backend 069): la sesión emitida se guarda igual que
      // en login — el listener de la pantalla llama refreshSession() y
      // el AuthGuard rutea a /home (token personal, selector de quesera).
      final userModel = await remoteDataSource.verifyEmail(token);
      await localDataSource.saveUserSession(userModel);
      return Right(userModel);
    } on RestApiException catch (e, stackTrace) {
      if (e.statusCode == 400 && e.errorCode == 'INVALID_OR_EXPIRED_TOKEN') {
        return const Left(InvalidOrExpiredTokenFailure());
      }
      logger.error(
        'Error de API al verificar correo',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al verificar correo',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }

  @override
  Future<Either<AuthFailure, void>> resendVerification(String email) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      await remoteDataSource.resendVerification(email);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      // Siempre 200 salvo fallo real de infra o rate limit (anti-
      // enumeración, backend 069 — mismo criterio que forgotPassword).
      if (e.statusCode == 429) {
        logger.warning(
          'Rate limit alcanzado en resend-verification',
          error: e,
          stackTrace: stackTrace,
        );
        return const Left(TooManyAttemptsFailure());
      }
      logger.error(
        'Error de API al reenviar verificación',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(_mapUnmappedError(e));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al reenviar verificación',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }
```

## 6. `register_use_case.dart` (existente — actualización)

**Ruta:** `lib/features/auth/domain/use_cases/register_use_case.dart`

**Antes:**
```dart
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';
import '../entities/user.dart';
import '../failures/auth_failure.dart';
```

**Después:**
```dart
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';
import '../failures/auth_failure.dart';
```

**Antes:**
```dart
  Future<Either<AuthFailure, User>> call({
```

**Después:**
```dart
  Future<Either<AuthFailure, void>> call({
```

## 7. `verify_email_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/verify_email_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: verificar el correo con el `token` del deep link.
/// Éxito = cuenta activa + sesión guardada (auto-login, backend 069).
class VerifyEmailUseCase {
  final IAuthRepository repository;

  const VerifyEmailUseCase(this.repository);

  Future<Either<AuthFailure, User>> call({required String token}) {
    return repository.verifyEmail(token: token);
  }
}
```

## 8. `resend_verification_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/resend_verification_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: reenviar el correo de verificación — siempre 200
/// server-side (anti-enumeración, backend 069).
class ResendVerificationUseCase {
  final IAuthRepository repository;

  const ResendVerificationUseCase(this.repository);

  Future<Either<AuthFailure, void>> call(String email) {
    return repository.resendVerification(email);
  }
}
```

## 9. `check_email_state.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/check_email_state.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

/// Estado de la pantalla "Revisá tu correo" — el `email` llega por
/// query param (register/login/deep link); `status` es del reenvío.
class CheckEmailState extends Equatable {
  final String email;
  final FormzSubmissionStatus status;
  final String? errorMessage;

  const CheckEmailState({
    required this.email,
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
  });

  CheckEmailState copyWith({
    FormzSubmissionStatus? status,
    String? errorMessage,
  }) {
    return CheckEmailState(
      email: email,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, status, errorMessage];
}
```

## 10. `check_email_cubit.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/check_email_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/use_cases/resend_verification_use_case.dart';
import 'check_email_state.dart';

/// Cubit de la pantalla "Revisá tu correo" — recibe el email por
/// parámetro de ruta y expone el reenvío (resend-verification).
class CheckEmailCubit extends Cubit<CheckEmailState> {
  final ResendVerificationUseCase _resendVerificationUseCase;

  CheckEmailCubit(this._resendVerificationUseCase, {required String email})
    : super(CheckEmailState(email: email));

  Future<void> resend() async {
    if (state.status.isInProgress) return;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _resendVerificationUseCase(state.email);

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
}
```

## 11. `verify_email_state.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/verify_email_state.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

/// Estado de la pantalla verify-email: `status` = la verificación
/// (inProgress → success/failure); `resendStatus` = el reenvío desde
/// el estado de error. `email` viene del query param para reenviar sin
/// pedirlo de nuevo.
class VerifyEmailState extends Equatable {
  final String email;
  final FormzSubmissionStatus status;
  final FormzSubmissionStatus resendStatus;
  final String? errorMessage;

  const VerifyEmailState({
    required this.email,
    this.status = FormzSubmissionStatus.initial,
    this.resendStatus = FormzSubmissionStatus.initial,
    this.errorMessage,
  });

  VerifyEmailState copyWith({
    FormzSubmissionStatus? status,
    FormzSubmissionStatus? resendStatus,
    String? errorMessage,
  }) {
    return VerifyEmailState(
      email: email,
      status: status ?? this.status,
      resendStatus: resendStatus ?? this.resendStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, status, resendStatus, errorMessage];
}
```

## 12. `verify_email_cubit.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/verify_email_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/use_cases/resend_verification_use_case.dart';
import '../../domain/use_cases/verify_email_use_case.dart';
import 'verify_email_state.dart';

/// Cubit de verify-email: recibe `token` + `email` del deep link
/// (inyectados por `AppRouter` desde el query). `verify()` corre una
/// sola vez al entrar — la pantalla lo dispara en el create del
/// BlocProvider. Éxito → la sesión ya quedó guardada por el repo y el
/// listener llama `AuthCubit.refreshSession()`.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  final VerifyEmailUseCase _verifyEmailUseCase;
  final ResendVerificationUseCase _resendVerificationUseCase;
  final String _token;

  VerifyEmailCubit(
    this._verifyEmailUseCase,
    this._resendVerificationUseCase, {
    required String token,
    required String email,
  }) : _token = token,
       super(VerifyEmailState(email: email));

  Future<void> verify() async {
    if (state.status.isInProgress || state.status.isSuccess) return;

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

    final result = await _verifyEmailUseCase(token: _token);

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

  Future<void> resend() async {
    if (state.resendStatus.isInProgress || state.email.isEmpty) return;

    emit(state.copyWith(resendStatus: FormzSubmissionStatus.inProgress));

    final result = await _resendVerificationUseCase(state.email);

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

## 13. `check_email_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/screens/check_email_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../cubit/check_email_cubit.dart';
import '../cubit/check_email_state.dart';
import '../widgets/auth_heading.dart';
import '../widgets/forgot_password_info_card.dart';
import '../widgets/quesivo_brand_header.dart';

/// Pantalla "Revisá tu correo" (verificación pendiente — propuesta 67 /
/// backend 069): destino tras registrarse, tras un login con correo sin
/// verificar, o cuando un link de verificación falla. Reenvía el correo
/// con el email que llegó por query param.
///
/// SOLID (SRP): Dumb View — solo lee `CheckEmailState` y repinta. El
/// Cubit llega por constructor (resuelto por `AppRouter` vía DI factory).
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, required this.cubit});

  /// Cubit resuelto por `AppRouter` vía DI (factory) — la pantalla no
  /// conoce el Service Locator (DIP).
  final CheckEmailCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CheckEmailCubit>(
      create: (context) => cubit,
      child: const _CheckEmailView(),
    );
  }
}

class _CheckEmailView extends StatelessWidget {
  const _CheckEmailView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<CheckEmailCubit, CheckEmailState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isFailure) {
              QuesivoToast.error(
                context,
                message: state.errorMessage ?? l10n.genericAuthError,
              );
            }
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  const QuesivoBrandHeader(logoFraction: 0.62),

                  AuthHeading(
                    title: l10n.checkEmailTitle,
                    description: l10n.verifyEmailSentDescription,
                    titleHeight: 1.05,
                    titleGap: 16,
                    descriptionColor: AppColors.quesivoTextSecondary,
                    descriptionMaxLines: 4,
                    descriptionHeight: 1.45,
                  ),

                  // --- Card con el email destino (§information_card,
                  //     mismo widget que forgot — es genérica) ---
                  const SizedBox(height: 8),
                  BlocBuilder<CheckEmailCubit, CheckEmailState>(
                    buildWhen: (p, c) => p.email != c.email,
                    builder: (context, state) => ForgotPasswordInfoCard(
                      title: l10n.checkEmailTitle,
                      description: state.email,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- Acciones: reenviar + volver al login ---
                  BlocBuilder<CheckEmailCubit, CheckEmailState>(
                    buildWhen: (p, c) => p.status != c.status,
                    builder: (context, state) {
                      if (state.status.isInProgress) {
                        return Center(
                          child: QuesivoLoader(
                            size: 28,
                            semanticLabel: l10n.loadingLabel,
                          ),
                        );
                      }
                      return Column(
                        children: [
                          if (state.status.isSuccess)
                            ForgotPasswordInfoCard(
                              title: l10n.resendVerificationSuccessTitle,
                              description:
                                  l10n.resendVerificationSuccessDescription,
                            )
                          else
                            QuesivoPrimaryButton(
                              label: l10n.resendVerificationButton,
                              onPressed: () =>
                                  context.read<CheckEmailCubit>().resend(),
                            ),
                          const SizedBox(height: 40),
                          Center(
                            child: GestureDetector(
                              onTap: () => context.go(AuthGuard.loginRoute),
                              child: Text(
                                l10n.signInLink,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.quesivoYellow,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

## 14. `verify_email_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/screens/verify_email_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/verify_email_cubit.dart';
import '../cubit/verify_email_state.dart';
import '../widgets/auth_heading.dart';
import '../widgets/forgot_password_info_card.dart';
import '../widgets/quesivo_brand_header.dart';

/// Pantalla verify-email — destino del deep link
/// `quesivo://verify-email?token=…&email=…` (propuesta 67 / backend 069).
/// Verifica al entrar; éxito → la sesión ya está guardada y
/// `refreshSession()` hace que el AuthGuard rute a /home (auto-login).
///
/// SOLID (SRP): Dumb View — solo lee `VerifyEmailState` y repinta.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, required this.cubit});

  /// Cubit resuelto por `AppRouter` vía DI (factory, params token+email).
  final VerifyEmailCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VerifyEmailCubit>(
      // La verificación arranca sola al crear el cubit — una sola vez.
      create: (context) => cubit..verify(),
      child: const _VerifyEmailView(),
    );
  }
}

class _VerifyEmailView extends StatelessWidget {
  const _VerifyEmailView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<VerifyEmailCubit, VerifyEmailState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isSuccess) {
              // Auto-login: el repo ya guardó la sesión; el cubit global
              // confirma y el AuthGuard rutea a /home (token personal).
              context.read<AuthCubit>().refreshSession();
            }
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  const QuesivoBrandHeader(logoFraction: 0.62),

                  BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
                    builder: (context, state) {
                      // --- Verificando / éxito (spinner — el éxito sale
                      //     de la pantalla vía guard enseguida) ---
                      if (!state.status.isFailure) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AuthHeading(
                              title: l10n.verifyEmailVerifyingTitle,
                              description: l10n.verifyEmailVerifyingDescription,
                              titleHeight: 1.05,
                              titleGap: 16,
                              descriptionColor: AppColors.quesivoTextSecondary,
                              descriptionMaxLines: 3,
                              descriptionHeight: 1.45,
                            ),
                            const SizedBox(height: 48),
                            Center(
                              child: QuesivoLoader(
                                size: 32,
                                semanticLabel: l10n.loadingLabel,
                              ),
                            ),
                          ],
                        );
                      }

                      // --- Link inválido/expirado ---
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuthHeading(
                            title: l10n.verifyEmailInvalidTitle,
                            description:
                                state.errorMessage ??
                                    l10n.verifyEmailInvalidDescription,
                            titleHeight: 1.05,
                            titleGap: 16,
                            descriptionColor: AppColors.quesivoTextSecondary,
                            descriptionMaxLines: 4,
                            descriptionHeight: 1.45,
                          ),
                          const SizedBox(height: 36),
                          if (state.resendStatus.isInProgress)
                            Center(
                              child: QuesivoLoader(
                                size: 28,
                                semanticLabel: l10n.loadingLabel,
                              ),
                            )
                          else if (state.resendStatus.isSuccess)
                            ForgotPasswordInfoCard(
                              title: l10n.resendVerificationSuccessTitle,
                              description:
                                  l10n.resendVerificationSuccessDescription,
                            )
                          else if (state.email.isNotEmpty)
                            QuesivoPrimaryButton(
                              label: l10n.resendVerificationButton,
                              onPressed: () =>
                                  context.read<VerifyEmailCubit>().resend(),
                            ),
                          const SizedBox(height: 40),
                          Center(
                            child: GestureDetector(
                              onTap: () => context.go(AuthGuard.loginRoute),
                              child: Text(
                                l10n.signInLink,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.quesivoYellow,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

## 15. `auth_guard.dart` (existente — actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

**Antes:**
```dart
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';
  static const String onboardingRoute = '/onboarding';
```

**Después:**
```dart
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';
  static const String checkEmailRoute = '/check-email';
  static const String verifyEmailRoute = '/verify-email';
  static const String onboardingRoute = '/onboarding';
```

**Antes:**
```dart
  static const List<String> publicRoutes = [
    welcomeRoute,
    loginRoute,
    registerRoute,
    forgotPasswordRoute,
    resetPasswordRoute,
    onboardingRoute,
  ];
```

**Después:**
```dart
  static const List<String> publicRoutes = [
    welcomeRoute,
    loginRoute,
    registerRoute,
    forgotPasswordRoute,
    resetPasswordRoute,
    checkEmailRoute,
    verifyEmailRoute,
    onboardingRoute,
  ];
```

## 16. `app_router.dart` (existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Antes:**
```dart
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/register_cubit.dart';
import '../../features/auth/presentation/cubit/reset_password_cubit.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
```

**Después:**
```dart
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/check_email_cubit.dart';
import '../../features/auth/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/register_cubit.dart';
import '../../features/auth/presentation/cubit/reset_password_cubit.dart';
import '../../features/auth/presentation/cubit/verify_email_cubit.dart';
import '../../features/auth/presentation/screens/check_email_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
```

**Después** (agregar tras el `GoRoute` de `resetPasswordRoute`):
```dart
      GoRoute(
        path: AuthGuard.checkEmailRoute,
        pageBuilder: (context, state) => CustomTransitions.fade(
          context: context,
          state: state,
          // "Revisá tu correo" — el email llega por query param
          // (register/login/deep link fallido).
          child: CheckEmailScreen(
            cubit: locator<CheckEmailCubit>(
              param1: state.uri.queryParameters['email'] ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: AuthGuard.verifyEmailRoute,
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          context: context,
          state: state,
          // Token + email del deep link `quesivo://verify-email?…`.
          child: VerifyEmailScreen(
            cubit: locator<VerifyEmailCubit>(
              param1: state.uri.queryParameters['token'] ?? '',
              param2: state.uri.queryParameters['email'] ?? '',
            ),
          ),
        ),
      ),
```

## 17. `app_links_deep_link_service_impl.dart` (existente — actualización)

**Ruta:** `lib/core/deeplink/app_links_deep_link_service_impl.dart`

**Antes:**
```dart
    // Solo reaccionamos a rutas públicas conocidas — un deep link con una
    // ruta que no reconocemos se ignora (fail-safe, no navegamos a ciegas).
    // Se loguea solo el path normalizado, NUNCA el query completo: ahí
    // viaja el token y en release estos logs van a Crashlytics.
    if (path != AuthGuard.resetPasswordRoute) {
      _logger.warning('Deep link con ruta desconocida ignorado: $path');
      return;
    }
```

**Después:**
```dart
    // Solo reaccionamos a rutas públicas conocidas — un deep link con una
    // ruta que no reconocemos se ignora (fail-safe, no navegamos a ciegas).
    // Se loguea solo el path normalizado, NUNCA el query completo: ahí
    // viaja el token y en release estos logs van a Crashlytics.
    const knownRoutes = {
      AuthGuard.resetPasswordRoute,
      AuthGuard.verifyEmailRoute,
    };
    if (!knownRoutes.contains(path)) {
      _logger.warning('Deep link con ruta desconocida ignorado: $path');
      return;
    }
```

## 18. `setup_di.dart` (existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Después** (en el bloque de use-cases de auth, tras `RegisterUseCase`):
```dart
  locator.registerLazySingleton(
    () => VerifyEmailUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => ResendVerificationUseCase(locator<IAuthRepository>()),
  );
```
(más los imports de ambos archivos)

**Después** (en el bloque de cubits, tras `RegisterCubit`):
```dart
  locator.registerFactoryParam<CheckEmailCubit, String, void>(
    (email, _) =>
        CheckEmailCubit(locator<ResendVerificationUseCase>(), email: email),
  );
  locator.registerFactoryParam<VerifyEmailCubit, String, String>(
    (token, email) => VerifyEmailCubit(
      locator<VerifyEmailUseCase>(),
      locator<ResendVerificationUseCase>(),
      token: token,
      email: email,
    ),
  );
```
(más los imports de ambos cubits)

## 19. `register_screen.dart` (existente — actualización)

**Ruta:** `lib/features/auth/presentation/screens/register_screen.dart`

**Antes:**
```dart
                } else if (state.status.isSuccess) {
                  // Auto-login: la sesión ya quedó guardada por el repo;
                  // el cubit global confirma y AuthGuard rutea a /home.
                  context.read<AuthCubit>().refreshSession();
                }
```

**Después:**
```dart
                } else if (state.status.isSuccess) {
                  // Sin sesión (backend 069): la cuenta queda pendiente
                  // de verificación — a "revisá tu correo" con el email
                  // del form para el botón de reenvío.
                  context.go(
                    '${AuthGuard.checkEmailRoute}?email=${Uri.encodeComponent(state.email.value)}',
                  );
                }
```

(más `import 'package:go_router/go_router.dart';` e `import '../../../../core/routes/auth_guard.dart';` si faltan)

## 20. `login_state.dart` + `login_cubit.dart` (existentes — actualización)

**Ruta:** `lib/features/auth/presentation/cubit/login_state.dart`

**Después** — agregar el flag (y al `copyWith` + `props`):
```dart
  /// Credenciales válidas pero correo sin verificar (backend 069) — la
  /// pantalla navega a /check-email en vez de mostrar un toast.
  final bool emailNotVerified;
```
(default `false`; copyWith: `emailNotVerified: emailNotVerified ?? this.emailNotVerified`; resetear a `false` en los `*Changed` igual que `errorMessage` — los copyWith de los `*Changed` del cubit pasan `status: initial`/`errorMessage: null`, agregar `emailNotVerified: false` ahí.)

**Ruta:** `lib/features/auth/presentation/cubit/login_cubit.dart`

**Antes:**
```dart
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: FormzSubmissionStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
```

**Después:**
```dart
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: FormzSubmissionStatus.failure,
            errorMessage: failure.message,
            emailNotVerified: failure is EmailNotVerifiedFailure,
          ),
        );
      },
```

(más `import '../../domain/failures/auth_failure.dart';`)

## 21. `login_screen.dart` (existente — actualización)

**Ruta:** `lib/features/auth/presentation/screens/login_screen.dart`

**Antes:**
```dart
                if (state.status.isFailure) {
                  QuesivoToast.error(
                    context,
                    message: state.errorMessage ?? l10n.genericAuthError,
                  );
                } else if (state.status.isSuccess) {
```

**Después:**
```dart
                if (state.status.isFailure) {
                  if (state.emailNotVerified) {
                    // Correo sin verificar (backend 069): a "revisá tu
                    // correo" con el email tipeado — no un toast.
                    context.go(
                      '${AuthGuard.checkEmailRoute}?email=${Uri.encodeComponent(state.email.value)}',
                    );
                  } else {
                    QuesivoToast.error(
                      context,
                      message: state.errorMessage ?? l10n.genericAuthError,
                    );
                  }
                } else if (state.status.isSuccess) {
```

(más `import 'package:go_router/go_router.dart';` e `import '../../../../core/routes/auth_guard.dart';`)

## 22. l10n (existentes — actualización)

Agregar a `lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` (con sus bloques `@key` de placeholders si los hubiera — estos no llevan) y ejecutar `flutter gen-l10n`:

| key | es | en | pt |
|-----|----|----|----|
| `verifyEmailSentDescription` | "Te enviamos un enlace para verificar tu correo y activar tu cuenta." | "We sent you a link to verify your email and activate your account." | "Enviamos um link para verificar seu e-mail e ativar sua conta." |
| `resendVerificationButton` | "Reenviar correo" | "Resend email" | "Reenviar e-mail" |
| `resendVerificationSuccessTitle` | "Correo reenviado" | "Email resent" | "E-mail reenviado" |
| `resendVerificationSuccessDescription` | "Te enviamos un enlace nuevo. Revisá tu bandeja de entrada." | "We sent you a new link. Check your inbox." | "Enviamos um novo link. Verifique sua caixa de entrada." |
| `verifyEmailVerifyingTitle` | "Verificando tu correo" | "Verifying your email" | "Verificando seu e-mail" |
| `verifyEmailVerifyingDescription` | "Un momento, estamos confirmando tu cuenta." | "One moment, we are confirming your account." | "Um momento, estamos confirmando sua conta." |
| `verifyEmailInvalidTitle` | "Este enlace ya no es válido" | "This link is no longer valid" | "Este link não é mais válido" |
| `verifyEmailInvalidDescription` | "El enlace de verificación expiró o ya fue usado. Podés pedir uno nuevo." | "The verification link expired or was already used. You can request a new one." | "O link de verificação expirou ou já foi usado. Você pode pedir um novo." |

(`checkEmailTitle` — "Revisa tu correo" — ya existe y se reutiliza.)

## 23. `quesivo-design-system.yaml` (existente — actualización)

- Nueva spec `check_email`: pantalla post-registro/post-login-sin-verificar — heading + info card con el email destino + pill "Reenviar correo" + link a login.
- Nueva spec `verify_email`: pantalla del deep link — estado verifying (spinner), success (auto-login → /home), invalid (card + reenviar + link a login).
- `register`: la acción exitosa ahora navega a `/check-email` (ya no auto-login a `/home`).
- `login`: `EMAIL_NOT_VERIFIED` navega a `/check-email`.
- Changelog `1.21.0`: flujo de verificación de email obligatoria (propuesta 67).

## 24. Tests

- `test/features/auth/data/repositories/auth_repository_impl_test.dart`:
  - `register`: éxito → `Right(null)` y `saveUserSession` **no** se llama; 409 → `EmailAlreadyInUseFailure`.
  - `verifyEmail`: éxito → `saveUserSession` + `Right(user)`; 400 `INVALID_OR_EXPIRED_TOKEN` → `InvalidOrExpiredTokenFailure`; offline → `NetworkFailure`.
  - `resendVerification`: 429 → `TooManyAttemptsFailure`; éxito → `Right(null)`.
  - `login`: 403 + `EMAIL_NOT_VERIFIED` → `EmailNotVerifiedFailure`.
- `test/features/auth/data/datasources/remote_auth_datasource_impl_test.dart`:
  - `register` postea a `/auth/register` y no parsea body.
  - `verifyEmail` postea a `/auth/verify-email` con `token` + `deviceId`/`deviceName` y devuelve `UserModel`.
  - `resendVerification` postea a `/auth/resend-verification` con `{email}`.
- `test/core/deeplink/app_links_deep_link_service_impl_test.dart`:
  - `quesivo://verify-email?token=x&email=y` → navega a `/verify-email?token=x&email=y`.
  - variantes de URI (single-slash, no-slash, trailing slash) sobre verify-email.
- Cubits (`test/features/auth/presentation/cubit/`):
  - `CheckEmailCubit`: resend éxito → `status: success`; failure → `errorMessage`.
  - `VerifyEmailCubit`: token vacío → failure `InvalidOrExpiredTokenFailure` sin llamar al repo; verify éxito → success; verify failure → failure; resend éxito → `resendStatus: success`.
- Actualizar los tests existentes que esperaban `register` devolviendo `User`/guardando sesión.

## Orden de aplicación

1. `auth_failure.dart` + `i_remote_auth_datasource.dart` + `remote_auth_datasource_impl.dart`
2. `i_auth_repository.dart` + `auth_repository_impl.dart`
3. `register_use_case.dart` + `verify_email_use_case.dart` + `resend_verification_use_case.dart`
4. `check_email_state/cubit` + `verify_email_state/cubit`
5. `check_email_screen.dart` + `verify_email_screen.dart`
6. `auth_guard.dart` + `app_router.dart` + `app_links_deep_link_service_impl.dart`
7. `setup_di.dart`
8. `register_screen.dart` + `login_state/login_cubit/login_screen`
9. l10n + `flutter gen-l10n`
10. design-system yaml
11. tests + `flutter analyze` + `flutter test`

## Fuera de alcance / pendiente manual

- Página `verify-email/index.html` en el repo `quesivo-redirect` (idéntica a la de reset-password pero apuntando a `quesivo://verify-email?…` con `token` **y** `email`) — se hace directo en ese repo.
- Verificación E2E en emulador: register → correo → link → app verifica → /home logueado.
