# Propuesta: Pantalla Reset Password (`/reset-password`)

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77 (65 + 4 use-case + 8 cubit). Decisiones con el usuario: botón dev-gated, sin flecha volver, éxito → snackbar + `/login`, checklist reutilizado. Revisor: APROBADO CON OBSERVACIONES — único hallazgo MENOR (`colorScheme.error` en snackbar de error) dejado así por convención: todas las pantallas de auth lo usan; normalizar a `AppColors.quesivoError` sería un cambio transversal aparte.

Implementa la pantalla "Crea una nueva contraseña" según
`Design/quesivo-design-system.yaml` §reset_password (líneas ~2703–3015):
backdrop de marca, imagotipo, heading, campo nueva contraseña + checklist vivo
+ confirmación, pill amarillo "Actualizar contraseña" y link "Volver al inicio
de sesión". Es el último tramo del flujo de auth.

El flujo real llega desde un deep link del correo con `?token=` — la ruta
`/reset-password?token=…` ya queda preparada para eso (`matchedLocation` ignora
el query para el guard; el token se lee de `state.uri.queryParameters`). Como
todavía no hay backend, en `dev` el datasource responde mock (igual que
register/forgot) y la pantalla se alcanza por un **botón temporal en
forgot-password**, debajo de "¿Recordaste tu contraseña?".

## Decisiones (vetables)

- **Botón dev-gated**: el acceso temporal solo se renderiza si
  `Environment.currentEnvironment == EnvType.dev` — así nunca puede filtrarse
  a un build de prod.
- **Sin flecha volver ni navy inferior** — mismo criterio que register/login/
  forgot (spec queda `enabled: false`).
- **Reutiliza VOs existentes**: `RegisterPassword` + `ConfirmPassword` (misma
  política de seguridad que el alta) y el widget `PasswordRequirementsChecklist`
  entre los dos campos.
- **Éxito → snackbar "Contraseña actualizada" + `go('/login')`** (reemplaza la
  pila — no se vuelve atrás a reset; spec `destinations.success → login`).
- **Tipografía real** = valores ya aprobados: heading 32, descripción 16,
  campos 16, botón 18, link 17.
- El contrato lleva `token` aunque el mock lo ignore — el endpoint real lo va a
  necesitar y el deep link ya lo provee por query param.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/use_cases/reset_password_use_case.dart` | **Nuevo** — valida VOs y llama al repo |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | Agregar `resetPassword({token, password})` |
| `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart` | Agregar `resetPassword({token, password})` |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | Implementar (mock en dev, POST `/auth/reset-password` fuera) |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Implementar (network check + mapeo de errores) |
| `lib/features/auth/presentation/cubit/reset_password_state.dart` | **Nuevo** — estado del formulario |
| `lib/features/auth/presentation/cubit/reset_password_cubit.dart` | **Nuevo** — lógica de presentación |
| `lib/features/auth/presentation/screens/reset_password_screen.dart` | **Nuevo** — pantalla según spec §reset_password |
| `lib/features/auth/presentation/screens/forgot_password_screen.dart` | Botón dev bajo el login_prompt → `/reset-password?token=dev` |
| `lib/core/routes/auth_guard.dart` | `/reset-password` a `publicRoutes` + const `resetPasswordRoute` |
| `lib/core/routes/app_router.dart` | `GoRoute` `/reset-password` (slideUp) con `token` del query |
| `lib/core/di/setup_di.dart` | `ResetPasswordUseCase` (lazySingleton) + `ResetPasswordCubit` (factory) |
| `lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` | Claves nuevas + `flutter gen-l10n` |
| `../Design/quesivo-design-system.yaml` | §reset_password a valores reales + `enabled: false` ×2 + changelog v1.0.6 |
| `test/features/auth/domain/use_cases/reset_password_use_case_test.dart` | **Nuevo** |
| `test/features/auth/presentation/cubit/reset_password_cubit_test.dart` | **Nuevo** |

---

## 1. `reset_password_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/reset_password_use_case.dart`

```dart
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';
import '../value_objects/confirm_password.dart';
import '../value_objects/register_password.dart';

/// Caso de Uso: restablecer la contraseña con un token del correo.
///
/// SOLID (SRP): orquesta solo el flujo de reset. Las reglas de validación
/// viven en los Value Objects (misma política que el alta — RegisterPassword).
class ResetPasswordUseCase {
  final IAuthRepository repository;

  const ResetPasswordUseCase(this.repository);

  Future<Either<AuthFailure, void>> call({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    final valid = Formz.validate([
      RegisterPassword.dirty(password),
      ConfirmPassword.dirty(password: password, value: confirmPassword),
    ]);
    if (!valid) {
      return const Left(
        ServerFailure('Los datos del formulario no son válidos.'),
      );
    }

    return repository.resetPassword(token: token, password: password);
  }
}
```

## 2. `i_auth_repository.dart` (actualización)

**Después de `forgotPassword`:**

```dart
  /// Restablece la contraseña con el token recibido por correo
  /// (deep link `/reset-password?token=…`).
  Future<Either<AuthFailure, void>> resetPassword({
    required String token,
    required String password,
  });
```

## 3. `i_remote_auth_datasource.dart` (actualización)

**Después de `forgotPassword`:**

```dart
  /// Envía la nueva contraseña + token a `POST /auth/reset-password`.
  Future<void> resetPassword({
    required String token,
    required String password,
  });
```

## 4. `remote_auth_datasource_impl.dart` (actualización)

**Después de `forgotPassword`:**

```dart
  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    // ⚠️ MOCK EXCLUSIVO DE DESARROLLO: DummyJSON no expone
    // /auth/reset-password. En stg/prod va al endpoint real del backend.
    if (Environment.currentEnvironment == EnvType.dev) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    }

    await networkService.post<void>(
      '/auth/reset-password',
      data: {'token': token, 'password': password},
    );
  }
```

## 5. `auth_repository_impl.dart` (actualización)

**Después de `forgotPassword`:**

```dart
  @override
  Future<Either<AuthFailure, void>> resetPassword({
    required String token,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      await remoteDataSource.resetPassword(token: token, password: password);
      return const Right(null);
    } on RestApiException catch (e, stackTrace) {
      logger.error(
        'Error de API al restablecer contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      logger.error(
        'Error inesperado al restablecer contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      return const Left(ServerFailure('Error inesperado de red'));
    }
  }
```

## 6. `reset_password_state.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/reset_password_state.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/register_password.dart';

/// Estado efímero del formulario de Restablecer Contraseña
/// (Presentation Logic local).
class ResetPasswordState extends Equatable {
  final RegisterPassword password;
  final ConfirmPassword confirmPassword;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final bool isValid;

  const ResetPasswordState({
    this.password = const RegisterPassword.pure(),
    this.confirmPassword = const ConfirmPassword.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isValid = false,
  });

  ResetPasswordState copyWith({
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
    FormzSubmissionStatus? status,
    String? errorMessage,
    bool? isValid,
  }) {
    return ResetPasswordState(
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props =>
      [password, confirmPassword, status, errorMessage, isValid];
}
```

## 7. `reset_password_cubit.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/reset_password_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/use_cases/reset_password_use_case.dart';
import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/register_password.dart';
import 'reset_password_state.dart';

/// Cubit del formulario de Restablecer Contraseña (Presentation Logic local).
///
/// Igual que `RegisterCubit`: cuando el password cambia, la confirmación se
/// re-evalúa porque su regla depende del valor actualizado. Recibe el `token`
/// del deep link al construirse (inyectado por `AppRouter` desde el query).
class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final ResetPasswordUseCase _resetPasswordUseCase;
  final String _token;

  ResetPasswordCubit(this._resetPasswordUseCase, {required String token})
      : _token = token,
        super(const ResetPasswordState());

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
        isValid: _validate(password: password, confirmPassword: confirmPassword),
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
    if (!state.isValid) return;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _resetPasswordUseCase(
      token: _token,
      password: state.password.value,
      confirmPassword: state.confirmPassword.value,
    );

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

## 8. `reset_password_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/screens/reset_password_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../cubit/reset_password_cubit.dart';
import '../cubit/reset_password_state.dart';
import '../widgets/password_requirements_checklist.dart';
import '../widgets/quesivo_auth_field.dart';

/// Pantalla de Restablecimiento de Contraseña QUESIVO
/// (quesivo-design-system.yaml §reset_password).
///
/// SOLID (SRP): Dumb View — solo lee `ResetPasswordState` y repinta. El Cubit
/// llega por constructor (resuelto por `AppRouter` vía DI factory) con el
/// `token` del deep link ya dentro.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key, required this.cubit});

  final ResetPasswordCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ResetPasswordCubit>(
      create: (context) => cubit,
      child: const _ResetPasswordView(),
    );
  }
}

class _ResetPasswordView extends StatelessWidget {
  const _ResetPasswordView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Mismo criterio que el resto de auth: solo el círculo amarillo.
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<ResetPasswordCubit, ResetPasswordState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ?? l10n.genericAuthError,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else if (state.status.isSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.passwordUpdatedSuccess),
                  backgroundColor: AppColors.quesivoSuccess,
                ),
              );
              // Spec destinations.success → login (reemplaza la pila:
              // no se puede "volver" al formulario de reset).
              context.go(AuthGuard.loginRoute);
            }
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // --- Imagen de marca (~55% ancho, §brand_header) ---
                  Center(
                    child: Image.asset(
                      'assets/images/imagotipo_quesivo.png',
                      width: size.width * 0.55,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),

                  // --- Heading + descripción (§reset_heading, izquierda) ---
                  Text(
                    l10n.resetTitle,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.resetDescription,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: AppColors.quesivoPlaceholder,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- Nueva contraseña (§password_form.new_password) ---
                  BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                    buildWhen: (p, c) => p.password != c.password,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.newPasswordPlaceholder,
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      onChanged: (v) => context
                          .read<ResetPasswordCubit>()
                          .passwordChanged(v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --- Requisitos (mismo checklist vivo que en register) ---
                  BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                    buildWhen: (p, c) => p.password.value != c.password.value,
                    builder: (context, state) =>
                        PasswordRequirementsChecklist(
                      password: state.password.value,
                      title: l10n.passwordReqTitle,
                      minLengthLabel: l10n.passwordReqMinLength,
                      uppercaseLabel: l10n.passwordReqUppercase,
                      lowercaseLabel: l10n.passwordReqLowercase,
                      digitLabel: l10n.passwordReqDigit,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Confirmar contraseña (§password_form.confirm_password) ---
                  BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                    buildWhen: (p, c) => p.confirmPassword != c.confirmPassword,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.confirmPasswordPlaceholder,
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      onChanged: (v) => context
                          .read<ResetPasswordCubit>()
                          .confirmPasswordChanged(v),
                      errorText: state.confirmPassword.displayError != null
                          ? l10n.passwordsDoNotMatchError
                          : null,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- Acción primaria (§primary_button: "Actualizar contraseña") ---
                  BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                    buildWhen: (p, c) =>
                        p.status != c.status || p.isValid != c.isValid,
                    builder: (context, state) {
                      return state.status.isInProgress
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 64,
                                  child: ElevatedButton(
                                    onPressed: state.isValid
                                        ? () {
                                            FocusScope.of(context).unfocus();
                                            context
                                                .read<ResetPasswordCubit>()
                                                .submit();
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.quesivoYellow,
                                      foregroundColor: AppColors.quesivoNavy,
                                      disabledBackgroundColor: AppColors
                                          .quesivoYellow
                                          .withValues(alpha: 0.45),
                                      disabledForegroundColor: AppColors
                                          .quesivoNavy
                                          .withValues(alpha: 0.5),
                                      elevation: 0,
                                      shape: const StadiumBorder(),
                                      textStyle: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    child: Text(l10n.updatePasswordButton),
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // --- Link a login (§login_link) ---
                                Center(
                                  child: GestureDetector(
                                    onTap: () =>
                                        context.go(AuthGuard.loginRoute),
                                    child: Text(
                                      l10n.backToLogin,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
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

## 9. `auth_guard.dart` (actualización)

```dart
  static const String resetPasswordRoute = '/reset-password';
```

y agregar `resetPasswordRoute` a `publicRoutes` (la lista ya usa las consts).

## 10. `app_router.dart` (actualización)

**Imports:**
```dart
import '../../features/auth/presentation/cubit/reset_password_cubit.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
```

**Ruta (después de `/forgot-password`):**
```dart
      GoRoute(
        path: AuthGuard.resetPasswordRoute,
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          context: context,
          state: state,
          // El cubit y el token del deep link se resuelven acá (DIP).
          child: ResetPasswordScreen(
            cubit: locator<ResetPasswordCubit>(
              param1: state.uri.queryParameters['token'] ?? '',
            ),
          ),
        ),
      ),
```

Nota para el implementador: `locator<T>(param1: …)` requiere registrar el cubit
con `registerFactoryParam` en `setup_di` (ver §12). Si `get_it` no soportara el
named param en esta versión, alternativa: `locator<ResetPasswordCubit>()`
recibiendo el token por el constructor de la screen — preferir la versión con
param si compila.

## 11. `forgot_password_screen.dart` (actualización — acceso dev)

**Después del `Center` del login_prompt, antes del `SizedBox(height: 20)`:**

```dart
                          // ⚠️ ACCESO TEMPORAL DE DESARROLLO: hasta que el
                          // deep link del correo exista (backend), la pantalla
                          // de reset solo se alcanza por este botón — jamás
                          // se renderiza fuera de `dev`.
                          if (Environment.currentEnvironment == EnvType.dev)
                            TextButton(
                              onPressed: () => context.push(
                                '${AuthGuard.resetPasswordRoute}?token=dev',
                              ),
                              child: Text(l10n.devResetLink),
                            ),
```

Y el import: `import '../../../../core/constants/environment/environment.dart';`

## 12. `setup_di.dart` (actualización)

**Imports:**
```dart
import '../../features/auth/domain/use_cases/reset_password_use_case.dart';
import '../../features/auth/presentation/cubit/reset_password_cubit.dart';
```

**Use Cases — después de `ForgotPasswordUseCase`:**
```dart
  locator.registerLazySingleton(
    () => ResetPasswordUseCase(locator<IAuthRepository>()),
  );
```

**Cubits — después de `ForgotPasswordCubit`:**
```dart
  locator.registerFactoryParam<ResetPasswordCubit, String, void>(
    (token, _) => ResetPasswordCubit(
      locator<ResetPasswordUseCase>(),
      token: token,
    ),
  );
```

## 13. Diccionarios i18n

**`app_es.arb`:**
```json
  "resetTitle": "Crea una nueva contraseña",
  "resetDescription": "Ingresa tu nueva contraseña para continuar.",
  "newPasswordPlaceholder": "Nueva contraseña",
  "updatePasswordButton": "Actualizar contraseña",
  "passwordUpdatedSuccess": "Contraseña actualizada. Inicia sesión.",
  "backToLogin": "Volver al inicio de sesión",
  "devResetLink": "Probar restablecer (dev)"
```

**`app_en.arb`:**
```json
  "resetTitle": "Create a new password",
  "resetDescription": "Enter your new password to continue.",
  "newPasswordPlaceholder": "New password",
  "updatePasswordButton": "Update password",
  "passwordUpdatedSuccess": "Password updated. Sign in.",
  "backToLogin": "Back to sign in",
  "devResetLink": "Try reset (dev)"
```

**`app_pt.arb`:**
```json
  "resetTitle": "Crie uma nova senha",
  "resetDescription": "Insira sua nova senha para continuar.",
  "newPasswordPlaceholder": "Nova senha",
  "updatePasswordButton": "Atualizar senha",
  "passwordUpdatedSuccess": "Senha atualizada. Faça login.",
  "backToLogin": "Voltar ao login",
  "devResetLink": "Testar redefinição (dev)"
```

Después ejecutar **`flutter gen-l10n`**.

## 14. `quesivo-design-system.yaml` (spec)

En `future_pages.reset_password`: tipografía a valores reales (heading `32px`,
descripción `16px`, campos `16px`, botón `18px`, login_link `17px`);
`decorative_elements.bottom_left` → `enabled: false` + nota;
`navigation.back_button` → `enabled: false` + nota; documentar
`password_requirements` entre `new_password` y `confirm_password` (mismo bloque
que en register); `brand_header.logo.width` → `~55%`; nota del acceso temporal
dev en `forgot_password.login_prompt`. Changelog `v1.0.6` (page
`reset_password`).

## 15. Tests

**`test/features/auth/domain/use_cases/reset_password_use_case_test.dart`** —
espejo del de register: éxito → `Right(null)`, input inválido → `Left` sin
tocar el repo, falla del repo → `Left`.

**`test/features/auth/presentation/cubit/reset_password_cubit_test.dart`** —
espejo del de register: cambios de campo emiten dirty + isValid, confirm se
re-evalúa al cambiar password, submit válido → inProgress/success, submit
inválido → no llama al use case, falla → failure + errorMessage.

## 16. Verificación

- `flutter analyze` — 0 issues.
- `flutter test` — los 65 existentes + los nuevos.
- Manual: forgot-password → botón "Probar restablecer (dev)" → formulario →
  éxito → snackbar + `/login`.
