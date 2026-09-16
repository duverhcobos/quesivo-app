# Propuesta: Pantalla de Registro (`/register`)

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 61/61. Ajustes post-revisión del subagente `revisor` + iteración visual sobre dispositivo (ya reflejados en esta propuesta y en el design yaml):

- `RegisterScreen` recibe el cubit por constructor (lo resuelve `AppRouter`, sin import de `setup_di` en presentation).
- Tipografía reducida a valores reales: heading 32, descripción 16, campos 16, términos 14, botón 18, divisor 15, Google 17, link login 16 (antes 44/19/19/16/22/17/20/18).
- Botón Google con el logo oficial multicolor (`assets/images/google_g.svg` vía `flutter_svg`) en vez de `Icons.g_mobiledata`; aplicado también en `login_screen.dart`.
- Sin círculo navy inferior-izquierdo (`bottomCircleFraction: 0`) y sin botón volver — el spec quedó `enabled: false` en ambos casos; la salida es el link "Iniciar sesión".

Queda como convención preexistente (no corregido acá): las `AuthFailure` llevan mensajes en español que llegan a la UI vía `errorMessage` — migrarlas a claves i18n sería un refactor aparte que también toca login/forgot.

Implementa la pantalla "Crear cuenta" según `Design/quesivo-design-system.yaml` §register:
backdrop de marca (`QuesivoBackdrop`, solo círculo amarillo superior), imagotipo, heading,
formulario quesera/nombre/email/password/confirmación, checkbox de términos, botón primario
amarillo, divisor, botón Google y link a login. Completa el TODO del botón "Registrarse" de
`WelcomeScreen` (`welcome_screen.dart:74`).

Sigue Clean Architecture: VOs nuevos (`FullName`, `RegisterPassword`, `ConfirmPassword`),
`RegisterUseCase`, contrato `register` en repository/datasource, `RegisterCubit` local de
pantalla, y registro en `AppRouter`/`AuthGuard`/`setup_di`. i18n en los 3 `.arb`.

**Decisión de producto (ya tomada):** el backend F0 (`planeaciones/001` §3.1) espera
*nombre de la organización* — se pide **en este mismo formulario** como primer campo
("Nombre de tu quesera"), no en un paso posterior. Motivo: la organización se crea en la
misma transacción atómica que el usuario; un nombre derivado o un setup post-registro
agregan complejidad (estado provisional + endpoint extra) por ahorrar un solo campo.
El design yaml se actualiza en la misma propuesta para reflejar el campo (§15).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/value_objects/full_name.dart` | **Nuevo** — VO nombre (no vacío, ≥3 letras) |
| `lib/features/auth/domain/value_objects/organization_name.dart` | **Nuevo** — VO nombre de quesera/organización (no vacío, ≥3 letras) |
| `lib/features/auth/domain/value_objects/register_password.dart` | **Nuevo** — VO password fuerte (8+, minús, mayús, dígito — espejo de `RegisterDto` del backend) |
| `lib/features/auth/domain/value_objects/confirm_password.dart` | **Nuevo** — VO confirmación (igualdad con password) |
| `lib/features/auth/domain/use_cases/register_use_case.dart` | **Nuevo** — orquesta registro, valida con VOs |
| `lib/features/auth/domain/failures/auth_failure.dart` | Agregar `EmailAlreadyInUseFailure` (409) |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | Agregar `register(...)` al contrato |
| `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart` | Agregar `register(...)` al contrato |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | Implementar `register` (mock en `dev`, POST real fuera) |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Implementar `register` (network check, saveSession, mapeo de errores) |
| `lib/features/auth/presentation/cubit/register_state.dart` | **Nuevo** — estado del formulario |
| `lib/features/auth/presentation/cubit/register_cubit.dart` | **Nuevo** — lógica de presentación |
| `lib/features/auth/presentation/widgets/quesivo_auth_field.dart` | **Nuevo** — campo de texto estilo design-system (hint + icono + toggle de visibilidad) |
| `lib/features/auth/presentation/screens/register_screen.dart` | **Nuevo** — pantalla según spec §register + campo organización |
| `lib/features/auth/presentation/screens/login_screen.dart` | Botón Google: icono oficial SVG |
| `assets/images/google_g.svg` | **Nuevo** — logo oficial multicolor de Google |
| `pubspec.yaml` | Agregar `flutter_svg` (render de SVG) |
| `../Design/quesivo-design-system.yaml` | Agregar `organization_name` a `register_form.fields` + flujo visual; post-implementación: tipografía a valores reales, `bottom_left`/`back_button` `enabled: false` |
| `lib/core/routes/auth_guard.dart` | `/register` a `publicRoutes` + const `registerRoute` |
| `lib/core/routes/app_router.dart` | `GoRoute` `/register` con `slideUp` |
| `lib/features/welcome/presentation/screens/welcome_screen.dart` | Botón "Registrarse" → `push('/register')` |
| `lib/core/di/setup_di.dart` | Registrar `RegisterUseCase` (lazySingleton) + `RegisterCubit` (factory) |
| `lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` | Claves nuevas + `flutter gen-l10n` |
| `test/features/auth/domain/use_cases/register_use_case_test.dart` | **Nuevo** — test del use case |
| `test/features/auth/presentation/cubit/register_cubit_test.dart` | **Nuevo** — test del cubit |
| `test/features/auth/data/repositories/auth_repository_impl_test.dart` | Casos de `register` |
| `test/core/routes/auth_guard_test.dart` | `/register` como ruta pública |

---

## 1. `full_name.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/value_objects/full_name.dart`

```dart
import 'package:formz/formz.dart';

enum FullNameValidationError { empty, tooShort }

/// Objeto de Valor para el nombre completo del usuario.
///
/// SOLID (SRP): única fuente de verdad de "qué es un nombre válido" —
/// ni la UI ni el Cubit repiten esta regla.
class FullName extends FormzInput<String, FullNameValidationError> {
  const FullName.pure() : super.pure('');
  const FullName.dirty([super.value = '']) : super.dirty();

  @override
  FullNameValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return FullNameValidationError.empty;
    if (trimmed.length < 3) return FullNameValidationError.tooShort;
    return null;
  }
}
```

## 2. `organization_name.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/value_objects/organization_name.dart`

```dart
import 'package:formz/formz.dart';

enum OrganizationNameValidationError { empty, tooShort }

/// Objeto de Valor para el nombre de la organización/quesera (tenant).
///
/// Es la entidad principal del registro: el backend crea la `organizacion`
/// con este nombre en la misma transacción que el usuario administrador
/// (planeaciones/001 §3.1). VO separado de `FullName` porque son reglas de
/// negocio distintas que pueden divergir (longitudes, caracteres, etc.).
class OrganizationName extends FormzInput<String, OrganizationNameValidationError> {
  const OrganizationName.pure() : super.pure('');
  const OrganizationName.dirty([super.value = '']) : super.dirty();

  @override
  OrganizationNameValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return OrganizationNameValidationError.empty;
    if (trimmed.length < 3) return OrganizationNameValidationError.tooShort;
    return null;
  }
}
```

## 3. `register_password.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/value_objects/register_password.dart`

```dart
import 'package:formz/formz.dart';

enum RegisterPasswordValidationError { empty, weak }

/// Contraseña para creación de cuenta — política más estricta que el `Password`
/// de login: mínimo 8 caracteres con minúscula, mayúscula y dígito, espejo de
/// `RegisterDto` del backend (`src/modules/auth/application/dtos/register.dto.ts`).
///
/// Se mantiene como VO separado para no endurecer la validación del login
/// (un usuario con credenciales viejas debe poder intentar loguearse).
class RegisterPassword extends FormzInput<String, RegisterPasswordValidationError> {
  const RegisterPassword.pure() : super.pure('');
  const RegisterPassword.dirty([super.value = '']) : super.dirty();

  static final _hasLower = RegExp(r'[a-z]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasDigit = RegExp(r'\d');

  @override
  RegisterPasswordValidationError? validator(String value) {
    if (value.isEmpty) return RegisterPasswordValidationError.empty;
    final strong = value.length >= 8 &&
        _hasLower.hasMatch(value) &&
        _hasUpper.hasMatch(value) &&
        _hasDigit.hasMatch(value);
    return strong ? null : RegisterPasswordValidationError.weak;
  }
}
```

## 4. `confirm_password.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/value_objects/confirm_password.dart`

```dart
import 'package:formz/formz.dart';

enum ConfirmPasswordValidationError { empty, mismatch }

/// Confirmación de contraseña — válida solo si es igual a la contraseña
/// original (recibida por constructor, porque Formz no compara campos).
class ConfirmPassword extends FormzInput<String, ConfirmPasswordValidationError> {
  final String password;

  const ConfirmPassword.pure({this.password = ''}) : super.pure('');
  const ConfirmPassword.dirty({required this.password, String value = ''})
      : super.dirty(value);

  @override
  ConfirmPasswordValidationError? validator(String value) {
    if (value.isEmpty) return ConfirmPasswordValidationError.empty;
    if (value != password) return ConfirmPasswordValidationError.mismatch;
    return null;
  }
}
```

## 5. `register_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/register_use_case.dart`

```dart
// lib/features/auth/domain/use_cases/register_use_case.dart
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';
import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';
import '../value_objects/email.dart';
import '../value_objects/full_name.dart';
import '../value_objects/organization_name.dart';
import '../value_objects/register_password.dart';

/// Caso de Uso: crear una cuenta nueva con nombre, email y contraseña.
///
/// SOLID (SRP): orquesta solo el flujo de registro. Las reglas de validación
/// viven en los Value Objects (única fuente de verdad); acá solo se verifica
/// que el input cumple el dominio antes de tocar la red.
class RegisterUseCase {
  final IAuthRepository repository;

  const RegisterUseCase(this.repository);

  Future<Either<AuthFailure, User>> call({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    final valid = Formz.validate([
      OrganizationName.dirty(organizationName),
      FullName.dirty(name),
      Email.dirty(email),
      RegisterPassword.dirty(password),
    ]);
    if (!valid) {
      return const Left(
        ServerFailure('Los datos del registro no son válidos.'),
      );
    }

    return repository.register(
      organizationName: organizationName.trim(),
      name: name.trim(),
      email: email,
      password: password,
    );
  }
}
```

## 6. `auth_failure.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/domain/failures/auth_failure.dart`

**Después de `InvalidCredentialsFailure`:**

```dart
/// Ocurre cuando el email ya está registrado (HTTP 409 del backend).
class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure()
    : super('Ya existe una cuenta con ese correo.');
}
```

## 7. `i_auth_repository.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/domain/repositories/i_auth_repository.dart`

**Después de `loginWithGoogle`:**

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

## 8. `i_remote_auth_datasource.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart`

**Después de `loginWithGoogle`:**

```dart
  /// Registra organización + usuario nuevo contra `POST /auth/register`.
  Future<UserModel> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  });
```

## 9. `remote_auth_datasource_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

**Después de `loginWithGoogle`:**

```dart
  @override
  Future<UserModel> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    // ⚠️ MOCK EXCLUSIVO DE DESARROLLO: DummyJSON no expone /auth/register.
    // En stg/prod se llama al endpoint real del backend Quesera
    // (planeaciones/001 §3.1: organización + usuario admin en una
    // transacción atómica — el nombre de la quesera viaja en el payload).
    if (Environment.currentEnvironment == EnvType.dev) {
      await Future.delayed(const Duration(seconds: 1));
      return UserModel(id: '3', email: email, name: name);
    }

    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'organizationName': organizationName,
        'name': name,
        'email': email,
        'password': password,
      },
    );
    return UserModel.fromJson(responseData);
  }
```

## 10. `auth_repository_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Después de `loginWithGoogle`:**

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
      return Left(ServerFailure(e.message));
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

## 11. `register_state.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/register_state.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/full_name.dart';
import '../../domain/value_objects/organization_name.dart';
import '../../domain/value_objects/register_password.dart';

/// Estado efímero del formulario de Registro (Presentation Logic local).
///
/// SOLID (SRP): separado del estado global de sesión (`AuthCubit`).
/// `isValid` es matemáticamente puro: todos los campos válidos + términos
/// aceptados.
class RegisterState extends Equatable {
  final OrganizationName organizationName;
  final FullName fullName;
  final Email email;
  final RegisterPassword password;
  final ConfirmPassword confirmPassword;
  final bool termsAccepted;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final bool isValid;

  const RegisterState({
    this.organizationName = const OrganizationName.pure(),
    this.fullName = const FullName.pure(),
    this.email = const Email.pure(),
    this.password = const RegisterPassword.pure(),
    this.confirmPassword = const ConfirmPassword.pure(),
    this.termsAccepted = false,
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.isValid = false,
  });

  RegisterState copyWith({
    OrganizationName? organizationName,
    FullName? fullName,
    Email? email,
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
    bool? termsAccepted,
    FormzSubmissionStatus? status,
    String? errorMessage,
    bool? isValid,
  }) {
    return RegisterState(
      organizationName: organizationName ?? this.organizationName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props => [
    organizationName,
    fullName,
    email,
    password,
    confirmPassword,
    termsAccepted,
    status,
    errorMessage,
    isValid,
  ];
}
```

## 12. `register_cubit.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/register_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/use_cases/register_use_case.dart';
import '../../domain/value_objects/confirm_password.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/full_name.dart';
import '../../domain/value_objects/organization_name.dart';
import '../../domain/value_objects/register_password.dart';
import 'register_state.dart';

/// Cubit del formulario de Registro (Presentation Logic local).
///
/// SOLID (SRP/ISP): no maneja sesión global — solo orquesta esta pantalla.
/// Cuando el password cambia, la confirmación se re-evalúa porque su regla
/// ("igual al password") depende del valor actualizado.
class RegisterCubit extends Cubit<RegisterState> {
  final RegisterUseCase _registerUseCase;

  RegisterCubit(this._registerUseCase) : super(const RegisterState());

  bool _validate({
    OrganizationName? organizationName,
    FullName? fullName,
    Email? email,
    RegisterPassword? password,
    ConfirmPassword? confirmPassword,
    bool? termsAccepted,
  }) {
    return Formz.validate([
          organizationName ?? state.organizationName,
          fullName ?? state.fullName,
          email ?? state.email,
          password ?? state.password,
          confirmPassword ?? state.confirmPassword,
        ]) &&
        (termsAccepted ?? state.termsAccepted);
  }

  void organizationNameChanged(String value) {
    final organizationName = OrganizationName.dirty(value);
    emit(
      state.copyWith(
        organizationName: organizationName,
        isValid: _validate(organizationName: organizationName),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  void fullNameChanged(String value) {
    final fullName = FullName.dirty(value);
    emit(
      state.copyWith(
        fullName: fullName,
        isValid: _validate(fullName: fullName),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  void emailChanged(String value) {
    final email = Email.dirty(value);
    emit(
      state.copyWith(
        email: email,
        isValid: _validate(email: email),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  void passwordChanged(String value) {
    final password = RegisterPassword.dirty(value);
    // La confirmación hereda el password nuevo: si ya fue tocada se
    // re-evalúa contra el valor actualizado; si está pura sigue pura.
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

  void termsToggled(bool accepted) {
    emit(
      state.copyWith(
        termsAccepted: accepted,
        isValid: _validate(termsAccepted: accepted),
        status: FormzSubmissionStatus.initial,
        errorMessage: null,
      ),
    );
  }

  Future<void> submit() async {
    if (!state.isValid) return;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    final result = await _registerUseCase(
      organizationName: state.organizationName.value,
      name: state.fullName.value,
      email: state.email.value,
      password: state.password.value,
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

## 13. `quesivo_auth_field.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/widgets/quesivo_auth_field.dart`

Campo de texto del design system (§register.register_form): alto ~62px, fondo
blanco, borde `#E5EAF2` (navy 2px al enfocar), radio 15, icono navy a la
izquierda, placeholder `#7A8499`, y toggle de visibilidad para passwords. El
toggle es estado puramente visual — no es lógica de negocio, así que vive en un
`StatefulWidget` local y no en el Cubit.

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Campo de texto de las pantallas de autenticación QUESIVO
/// (quesivo-design-system.yaml §register_form / §login_form).
///
/// SOLID (SRP): solo renderiza la caja con el estilo de marca; no sabe para
/// qué se usa (nombre, email, password). `isPassword` agrega el ojo de
/// visibilidad como estado visual interno.
class QuesivoAuthField extends StatefulWidget {
  const QuesivoAuthField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.errorText,
    this.onChanged,
  });

  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? errorText;
  final void Function(String)? onChanged;

  @override
  State<QuesivoAuthField> createState() => _QuesivoAuthFieldState();
}

class _QuesivoAuthFieldState extends State<QuesivoAuthField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.quesivoBorder, width: 1.5),
    );

    return TextFormField(
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(
        color: AppColors.quesivoDarkText,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(
          color: AppColors.quesivoPlaceholder,
          fontSize: 16,
        ),
        errorText: widget.errorText,
        filled: true,
        fillColor: AppColors.quesivoWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 18,
        ),
        prefixIcon: Icon(
          widget.prefixIcon,
          color: AppColors.quesivoNavy,
          size: 28,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.quesivoPlaceholder,
                  size: 26,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.quesivoNavy, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
        ),
      ),
    );
  }
}
```

## 14. `register_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/screens/register_screen.dart`

```dart
// lib/features/auth/presentation/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import '../widgets/quesivo_auth_field.dart';

/// Pantalla de Registro QUESIVO (quesivo-design-system.yaml §register).
///
/// SOLID (SRP): Dumb View — solo lee `RegisterState` y repinta. El Cubit
/// local se crea por factory en cada ingreso; la sesión resultante la
/// maneja el `AuthCubit` global vía `checkSession()`.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, required this.cubit});

  /// Cubit de formulario resuelto por `AppRouter` vía DI (factory) — la
  /// pantalla no conoce el Service Locator (DIP).
  final RegisterCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RegisterCubit>(
      create: (context) => cubit,
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Spec §register.decorative_elements: solo el círculo amarillo ~34%
        // arriba a la derecha (con huecos de queso); el navy inferior se
        // omite para no competir con el form (mismo criterio que onboarding).
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: MultiBlocListener(
          listeners: [
            BlocListener<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
            ),
            BlocListener<RegisterCubit, RegisterState>(
              listenWhen: (previous, current) =>
                  previous.status != current.status,
              listener: (context, state) {
                if (state.status.isFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage ?? l10n.genericAuthError),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                } else if (state.status.isSuccess) {
                  // Auto-login: la sesión ya quedó guardada por el repo;
                  // el cubit global confirma y AuthGuard rutea a /home.
                  context.read<AuthCubit>().checkSession();
                }
              },
            ),
          ],
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compensa el alto que ocupaba el botón volver (~48px) para
                  // que el imagotipo conserve su posición vertical.
                  const SizedBox(height: 48),

                  // --- Imagen de marca (~65% ancho, §brand_header) ---
                  Center(
                    child: Image.asset(
                      'assets/images/imagotipo_quesivo.png',
                      width: size.width * 0.65,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),

                  // --- Heading + descripción (§register_heading) ---
                  Text(
                    l10n.registerTitle,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.registerDescription,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: AppColors.quesivoDarkText,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- Formulario (§register_form, gap 16-18) ---
                  // La quesera va primero: es la entidad que se registra
                  // (organización = tenant principal del SaaS).
                  BlocBuilder<RegisterCubit, RegisterState>(
                    buildWhen: (p, c) =>
                        p.organizationName != c.organizationName,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.orgNamePlaceholder,
                      prefixIcon: Icons.storefront_outlined,
                      onChanged: (v) => context
                          .read<RegisterCubit>()
                          .organizationNameChanged(v),
                      errorText: state.organizationName.displayError != null
                          ? l10n.invalidOrgNameError
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<RegisterCubit, RegisterState>(
                    buildWhen: (p, c) => p.fullName != c.fullName,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.fullNamePlaceholder,
                      prefixIcon: Icons.person_outline,
                      onChanged: (v) =>
                          context.read<RegisterCubit>().fullNameChanged(v),
                      errorText: state.fullName.displayError != null
                          ? l10n.invalidFullNameError
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<RegisterCubit, RegisterState>(
                    buildWhen: (p, c) => p.email != c.email,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.registerEmailPlaceholder,
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) =>
                          context.read<RegisterCubit>().emailChanged(v),
                      errorText: state.email.displayError != null
                          ? l10n.invalidEmailError
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<RegisterCubit, RegisterState>(
                    buildWhen: (p, c) => p.password != c.password,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.registerPasswordPlaceholder,
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      onChanged: (v) =>
                          context.read<RegisterCubit>().passwordChanged(v),
                      errorText: state.password.displayError != null
                          ? l10n.weakPasswordError
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<RegisterCubit, RegisterState>(
                    buildWhen: (p, c) => p.confirmPassword != c.confirmPassword,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.confirmPasswordPlaceholder,
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      onChanged: (v) =>
                          context.read<RegisterCubit>().confirmPasswordChanged(v),
                      errorText: state.confirmPassword.displayError != null
                          ? l10n.passwordsDoNotMatchError
                          : null,
                    ),
                  ),

                  // --- Términos (§terms_and_conditions) ---
                  const SizedBox(height: 16),
                  BlocBuilder<RegisterCubit, RegisterState>(
                    buildWhen: (p, c) => p.termsAccepted != c.termsAccepted,
                    builder: (context, state) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Checkbox(
                            value: state.termsAccepted,
                            onChanged: (v) => context
                                .read<RegisterCubit>()
                                .termsToggled(v ?? false),
                            activeColor: AppColors.quesivoNavy,
                            checkColor: AppColors.quesivoWhite,
                            side: const BorderSide(
                              color: AppColors.quesivoPlaceholder,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          // Los links son decorativos por ahora: las páginas
                          // legales todavía no existen (pendiente de producto).
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                color: AppColors.quesivoDarkText,
                              ),
                              children: [
                                TextSpan(text: l10n.termsPrefix),
                                TextSpan(
                                  text: l10n.termsLink,
                                  style: const TextStyle(
                                    color: AppColors.quesivoYellow,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: l10n.termsConnector),
                                TextSpan(
                                  text: l10n.privacyLink,
                                  style: const TextStyle(
                                    color: AppColors.quesivoYellow,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Acción primaria (§primary_button: pill amarillo 64px) ---
                  BlocBuilder<RegisterCubit, RegisterState>(
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
                                                .read<RegisterCubit>()
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
                                    child: Text(l10n.createAccountButton),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // --- Divisor (§social_divider) ---
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                        color: AppColors.quesivoBorder,
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        l10n.registerDivider,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: AppColors.quesivoTextSecondary,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                        color: AppColors.quesivoBorder,
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),

                                // --- Google (§google_register) ---
                                SizedBox(
                                  width: double.infinity,
                                  height: 64,
                                  child: OutlinedButton.icon(
                                    icon: SvgPicture.asset(
                                      'assets/images/google_g.svg',
                                      width: 24,
                                      height: 24,
                                    ),
                                    onPressed: () => context
                                        .read<AuthCubit>()
                                        .loginWithGoogle(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.quesivoNavy,
                                      side: const BorderSide(
                                        color: AppColors.quesivoBorder,
                                        width: 1.5,
                                      ),
                                      shape: const StadiumBorder(),
                                      textStyle: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    label: Text(l10n.continueWithGoogle),
                                  ),
                                ),
                                const SizedBox(height: 26),

                                // --- Link a login (§login_prompt) ---
                                Center(
                                  child: GestureDetector(
                                    onTap: () =>
                                        context.push(AuthGuard.loginRoute),
                                    child: Text.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: AppColors.quesivoDarkText,
                                        ),
                                        children: [
                                          TextSpan(text: l10n.alreadyHaveAccount),
                                          const TextSpan(text: ' '),
                                          TextSpan(
                                            text: l10n.signInLink,
                                            style: const TextStyle(
                                              color: AppColors.quesivoYellow,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
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

## 15. `quesivo-design-system.yaml` (archivo existente — actualización)

**Ruta:** `../Design/quesivo-design-system.yaml`

El formulario del spec gana un campo `organization_name` como primer campo (el
tenant que se registra). En `register.register_form.fields`, **antes** de
`full_name`:

```yaml
        fields:
          organization_name:
            id: "organization_name"
            type: "text"
            label: null
            placeholder: "Nombre de tu quesera"
            height: "approximately_62px"
            background:
              color: "#FFFFFF"
            border:
              enabled: true
              color: "#E5EAF2"
              width: "1-2px"
            radius:
              value: "14-16px"
            icon:
              type: "store"
              style: "outline"
              color: "#07275C"
              size: "28-30px"
            text:
              color: "#172033"
              placeholder_color: "#7A8499"
              size: "16px"
              weight: "400"
            padding:
              horizontal: "26-30px"
          full_name:
            # ... (sin cambios)
```

Y en `register.hierarchy.visual_flow`, insertar `- "Nombre de tu quesera"` antes
de `- "Nombre completo"` (mismo criterio en `hierarchy.priority`: el campo nuevo
ocupa la posición 4 y corre las demás).

Post-implementación, el spec de register quedó además al día con: tipografía a
valores reales implementados, `decorative_elements.bottom_left` → `enabled: false`
(sin círculo navy inferior) y `navigation.back_button` → `enabled: false` (sin
flecha de volver) — ver changelog v1.0.2 del yaml.

## 16. `auth_guard.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

**Antes:**
```dart
  static const List<String> publicRoutes = [
    '/welcome',
    '/login',
    '/forgot-password',
    '/onboarding',
  ];

  static const String splashRoute = '/splash';
  static const String homeRoute = '/home';
  static const String welcomeRoute = '/welcome';
  static const String loginRoute = '/login';
  static const String onboardingRoute = '/onboarding';
```

**Después:**
```dart
  static const List<String> publicRoutes = [
    '/welcome',
    '/login',
    '/register',
    '/forgot-password',
    '/onboarding',
  ];

  static const String splashRoute = '/splash';
  static const String homeRoute = '/home';
  static const String welcomeRoute = '/welcome';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String onboardingRoute = '/onboarding';
```

## 17. `app_router.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Antes:**
```dart
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
```

```dart
      GoRoute(
        path: '/forgot-password',
```

**Después:**
```dart
import '../../features/auth/presentation/cubit/register_cubit.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
```

```dart
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          context: context,
          state: state,
          // El cubit de formulario se resuelve acá (DIP) — la pantalla no
          // conoce el locator. Factory ⇒ instancia fresca por ingreso.
          child: RegisterScreen(cubit: locator<RegisterCubit>()),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
```

## 18. `welcome_screen.dart` (archivo existente — actualización)

**Ruta:** `lib/features/welcome/presentation/screens/welcome_screen.dart`

**Antes:**
```dart
                      child: ElevatedButton(
                        // TODO: navegar a /register cuando exista la pantalla
                        onPressed: () => context.go(AuthGuard.loginRoute),
```

**Después:**
```dart
                      child: ElevatedButton(
                        onPressed: () => context.push(AuthGuard.registerRoute),
```

## 19. `setup_di.dart` (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Imports — después de `forgot_password_use_case.dart`:**
```dart
import '../../features/auth/domain/use_cases/register_use_case.dart';
```
**Después de `import '../cubit/forgot_password_cubit.dart';`:**
```dart
import '../../features/auth/presentation/cubit/register_cubit.dart';
```

**Use Cases — después del bloque `ForgotPasswordUseCase`:**
```dart
  locator.registerLazySingleton(
    () => RegisterUseCase(locator<IAuthRepository>()),
  );
```

**Cubits de pantalla — después de `ForgotPasswordCubit`:**
```dart
  locator.registerFactory(
    () => RegisterCubit(locator<RegisterUseCase>()),
  );
```

## 20. Diccionarios i18n (archivos existentes — actualización)

Agregar al final de **`lib/l10n/app_es.arb`** (antes de la llave de cierre):

```json
  "registerTitle": "Crear cuenta",
  "registerDescription": "Regístrate y comienza a gestionar tu quesera de forma fácil y segura.",
  "orgNamePlaceholder": "Nombre de tu quesera",
  "invalidOrgNameError": "Ingresa el nombre de tu quesera",
  "fullNamePlaceholder": "Nombre completo",
  "registerEmailPlaceholder": "Correo electrónico",
  "registerPasswordPlaceholder": "Contraseña",
  "confirmPasswordPlaceholder": "Confirmar contraseña",
  "invalidFullNameError": "Ingresa tu nombre completo",
  "weakPasswordError": "Mínimo 8 caracteres, con mayúscula, minúscula y número",
  "passwordsDoNotMatchError": "Las contraseñas no coinciden",
  "termsPrefix": "Acepto los ",
  "termsLink": "Términos y Condiciones",
  "termsConnector": " y la ",
  "privacyLink": "Política de Privacidad.",
  "createAccountButton": "Crear cuenta",
  "registerDivider": "o regístrate con",
  "continueWithGoogle": "Continuar con Google",
  "alreadyHaveAccount": "¿Ya tienes una cuenta?",
  "signInLink": "Iniciar sesión"
```

**`app_en.arb`:**
```json
  "registerTitle": "Create account",
  "registerDescription": "Sign up and start managing your cheese factory easily and safely.",
  "orgNamePlaceholder": "Your cheese factory name",
  "invalidOrgNameError": "Enter your cheese factory name",
  "fullNamePlaceholder": "Full name",
  "registerEmailPlaceholder": "Email",
  "registerPasswordPlaceholder": "Password",
  "confirmPasswordPlaceholder": "Confirm password",
  "invalidFullNameError": "Enter your full name",
  "weakPasswordError": "At least 8 characters, with uppercase, lowercase and a number",
  "passwordsDoNotMatchError": "Passwords do not match",
  "termsPrefix": "I accept the ",
  "termsLink": "Terms and Conditions",
  "termsConnector": " and the ",
  "privacyLink": "Privacy Policy.",
  "createAccountButton": "Create account",
  "registerDivider": "or sign up with",
  "continueWithGoogle": "Continue with Google",
  "alreadyHaveAccount": "Already have an account?",
  "signInLink": "Sign in"
```

**`app_pt.arb`:**
```json
  "registerTitle": "Criar conta",
  "registerDescription": "Cadastre-se e comece a gerenciar sua queijaria de forma fácil e segura.",
  "orgNamePlaceholder": "Nome da sua queijaria",
  "invalidOrgNameError": "Digite o nome da sua queijaria",
  "fullNamePlaceholder": "Nome completo",
  "registerEmailPlaceholder": "E-mail",
  "registerPasswordPlaceholder": "Senha",
  "confirmPasswordPlaceholder": "Confirmar senha",
  "invalidFullNameError": "Digite seu nome completo",
  "weakPasswordError": "Mínimo 8 caracteres, com maiúscula, minúscula e número",
  "passwordsDoNotMatchError": "As senhas não coincidem",
  "termsPrefix": "Aceito os ",
  "termsLink": "Termos e Condições",
  "termsConnector": " e a ",
  "privacyLink": "Política de Privacidade.",
  "createAccountButton": "Criar conta",
  "registerDivider": "ou cadastre-se com",
  "continueWithGoogle": "Continuar com Google",
  "alreadyHaveAccount": "Já tem uma conta?",
  "signInLink": "Entrar"
```

Después ejecutar **`flutter gen-l10n`** (los `app_localizations*.dart` se regeneran, no se editan a mano).

## 21. `register_use_case_test.dart` (archivo nuevo)

**Ruta:** `test/features/auth/domain/use_cases/register_use_case_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:quesivo/features/auth/domain/use_cases/register_use_case.dart';
import 'package:quesivo/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late RegisterUseCase useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = RegisterUseCase(mockAuthRepository);
  });

  const tOrgName = 'Quesera Los Alpes';
  const tName = 'María Quesera';
  const tEmail = 'maria@quesera.com';
  const tPassword = 'Queso123';
  const tUser = User(id: '1', email: tEmail, name: tName, token: 'token');

  test(
    'debería retornar un Usuario cuando el repositorio responde exitosamente',
    () async {
      when(
        () => mockAuthRepository.register(
          organizationName: tOrgName,
          name: tName,
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      final result = await useCase(
        organizationName: tOrgName,
        name: tName,
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Right(tUser));
      verify(
        () => mockAuthRepository.register(
          organizationName: tOrgName,
          name: tName,
          email: tEmail,
          password: tPassword,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si el password es débil',
    () async {
      final result = await useCase(
        organizationName: tOrgName,
        name: tName,
        email: tEmail,
        password: 'debil',
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si el email es inválido',
    () async {
      final result = await useCase(
        organizationName: tOrgName,
        name: tName,
        email: 'no-es-email',
        password: tPassword,
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si el nombre está vacío',
    () async {
      final result = await useCase(
        organizationName: tOrgName,
        name: '  ',
        email: tEmail,
        password: tPassword,
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si el nombre de la quesera está vacío',
    () async {
      final result = await useCase(
        organizationName: ' ',
        name: tName,
        email: tEmail,
        password: tPassword,
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );
}
```

## 22. `register_cubit_test.dart` (archivo nuevo)

**Ruta:** `test/features/auth/presentation/cubit/register_cubit_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:formz/formz.dart';

import 'package:quesivo/features/auth/domain/use_cases/register_use_case.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/presentation/cubit/register_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/register_state.dart';

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  late MockRegisterUseCase mockRegisterUseCase;

  setUp(() {
    mockRegisterUseCase = MockRegisterUseCase();
  });

  RegisterCubit buildCubit() => RegisterCubit(mockRegisterUseCase);

  const tUser = User(id: '1', email: 'maria@quesera.com', name: 'María');

  void fillValidForm(RegisterCubit cubit) {
    cubit
      ..organizationNameChanged('Quesera Los Alpes')
      ..fullNameChanged('María Quesera')
      ..emailChanged('maria@quesera.com')
      ..passwordChanged('Queso123')
      ..confirmPasswordChanged('Queso123')
      ..termsToggled(true);
  }

  test('el estado inicial es RegisterState limpio e inválido', () {
    expect(buildCubit().state, const RegisterState());
    expect(buildCubit().state.isValid, false);
  });

  blocTest<RegisterCubit, RegisterState>(
    'sin aceptar términos el formulario completo sigue inválido',
    build: buildCubit,
    act: (cubit) {
      cubit
        ..organizationNameChanged('Quesera Los Alpes')
        ..fullNameChanged('María Quesera')
        ..emailChanged('maria@quesera.com')
        ..passwordChanged('Queso123')
        ..confirmPasswordChanged('Queso123');
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<RegisterCubit, RegisterState>(
    'formulario completo + términos aceptados => isValid true',
    build: buildCubit,
    act: fillValidForm,
    verify: (cubit) => expect(cubit.state.isValid, true),
  );

  blocTest<RegisterCubit, RegisterState>(
    'confirmar un password distinto invalida el formulario',
    build: buildCubit,
    act: (cubit) {
      fillValidForm(cubit);
      cubit.confirmPasswordChanged('Otro123');
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<RegisterCubit, RegisterState>(
    'cambiar el password re-evalúa la confirmación ya escrita',
    build: buildCubit,
    act: (cubit) {
      fillValidForm(cubit);
      cubit.passwordChanged('Queso124'); // la confirmación quedó con Queso123
    },
    verify: (cubit) => expect(cubit.state.isValid, false),
  );

  blocTest<RegisterCubit, RegisterState>(
    'submit con formulario inválido no emite nada ni llama al use case',
    build: buildCubit,
    act: (cubit) => cubit.submit(),
    expect: () => const <RegisterState>[],
    verify: (_) => verifyZeroInteractions(mockRegisterUseCase),
  );

  blocTest<RegisterCubit, RegisterState>(
    'submit válido emite inProgress y luego success',
    build: buildCubit,
    seed: () => const RegisterState(isValid: true),
    setUp: () {
      when(
        () => mockRegisterUseCase(
          organizationName: any(named: 'organizationName'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Right(tUser));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const RegisterState(
        isValid: true,
        status: FormzSubmissionStatus.inProgress,
      ),
      const RegisterState(
        isValid: true,
        status: FormzSubmissionStatus.success,
      ),
    ],
  );

  blocTest<RegisterCubit, RegisterState>(
    'submit con falla del servidor emite failure con errorMessage',
    build: buildCubit,
    seed: () => const RegisterState(isValid: true),
    setUp: () {
      when(
        () => mockRegisterUseCase(
          organizationName: any(named: 'organizationName'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(EmailAlreadyInUseFailure()));
    },
    act: (cubit) => cubit.submit(),
    expect: () => [
      const RegisterState(
        isValid: true,
        status: FormzSubmissionStatus.inProgress,
      ),
      const RegisterState(
        isValid: true,
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Ya existe una cuenta con ese correo.',
      ),
    ],
  );
}
```

## 23. `auth_repository_impl_test.dart` (archivo existente — actualización)

**Ruta:** `test/features/auth/data/repositories/auth_repository_impl_test.dart`

Agregar un `group('register', ...)` con tres casos, siguiendo el patrón de los
tests existentes de `loginWithEmailPassword`:

- **éxito:** `remoteDataSource.register(...)` devuelve `UserModel` → repo devuelve
  `Right(user)` y `localDataSource.saveUserSession` se llamó 1 vez.
- **409:** datasource lanza `RestApiException(statusCode: 409, ...)` → repo devuelve
  `Left(EmailAlreadyInUseFailure())` y nunca toca `saveUserSession`.
- **sin red:** `networkInfo.isConnected` → `false` → `Left(NetworkFailure())` sin
  tocar el datasource.

## 24. `auth_guard_test.dart` (archivo existente — actualización)

**Ruta:** `test/core/routes/auth_guard_test.dart`

Agregar un caso junto a los de rutas públicas existentes:

- Sin sesión (`AuthInitial`), `evaluate('/register', ...)` devuelve `null` (ruta pública).
- Con sesión (`AuthSuccess`), `evaluate('/register', ...)` devuelve `'/home'`.

---

## Orden de aplicación

1. Domain: VOs (`organization_name`, `full_name`, `register_password`, `confirm_password`) → `EmailAlreadyInUseFailure` → `register_use_case`.
2. Contratos: `i_auth_repository` → `i_remote_auth_datasource`.
3. Data: `remote_auth_datasource_impl` → `auth_repository_impl`.
4. Presentation: `register_state` → `register_cubit` → `quesivo_auth_field` → `register_screen`.
5. Spec: `quesivo-design-system.yaml` (campo `organization_name` en `register_form`).
6. Routing: `auth_guard` (`/register` pública + const) → `app_router` → `welcome_screen` (botón).
7. DI: `setup_di` (use case + cubit).
8. i18n: 3 `.arb` → `flutter gen-l10n`.
9. Tests: los 2 archivos nuevos + los 2 agregados a specs existentes.
10. Verificación: `flutter analyze` + `flutter test`.

## Notas / decisiones

- **Password policy:** `RegisterPassword` (8+, mayús, minús, dígito) es espejo del `RegisterDto`
  actual del backend. El `Password` de login queda intacto (6+) para no bloquear logins.
- **Auto-login post-registro:** el repo guarda sesión y la UI dispara `AuthCubit.checkSession()`
  → `AuthGuard` redirige a `/home`. Mismo patrón que `LoginScreen`.
- **Nombre de organización:** se pide en el formulario (campo 1, antes del nombre personal —
  la organización es el tenant principal). El payload envía `organizationName` en camelCase;
  si la migración F0 del backend define otra clave (ej. `nombre_organizacion`), se ajusta solo
  el body del datasource.
- **Links legales:** los spans de Términos/Privacidad no navegan todavía (las páginas no existen).
  Cuando existan, se agregan `recognizer`/`GestureDetector` apuntando a rutas públicas.
- **Estilo de campos:** `QuesivoAuthField` es el widget compartido del nuevo estilo de auth; en una
  propuesta futura se puede migrar `LoginScreen`/`ForgotPasswordScreen` al mismo widget cuando se
  rediseñen esas pantallas contra su propia spec del yaml.
