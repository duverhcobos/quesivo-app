# Propuesta: Rediseño de la pantalla de Login (`/login`)

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 61/61. Ajustes post-revisión del `revisor`: `publicRoutes` usa las const de rutas (no literales) y se quitó el snackbar `welcomeMessage` del login para simetría con register (la clave se eliminó de los 3 `.arb` al quedar huérfana). `emailLabel` se conservó: la usa `forgot_password_screen.dart` (pendiente de rediseño).

La pantalla `/login` existe desde el proyecto base con el diseño genérico heredado
(AppBar con título + toggle de idioma, `CustomTextField` con labels, botones del
tema por defecto). Se rediseña según `Design/quesivo-design-system.yaml` §login
(líneas ~960–1240) **replicando los patrones ya aprobados en `/register`**
(propuesta 09): `QuesivoBackdrop`, `QuesivoAuthField`, tipografía real, pill
amarillo, divisor, Google con logo SVG oficial, link a registro.

No toca dominio ni data: `LoginCubit`/`LoginState`/`LoginUseCase` ya existen y se
conservan — es un cambio de presentation + routing + i18n + spec.

## Decisiones (consistentes con lo aprobado en register — vetables)

- **Solo círculo amarillo superior** (`bottomCircleFraction: 0`) — mismo criterio
  que register; el spec §login se actualiza a `enabled: false`.
- **Sin AppBar**: desaparecen el título en barra y el toggle de idioma (el locale
  sigue al idioma del dispositivo; no queda switcher en la UI — decisión de
  producto, el spec no lo contempla en auth).
- **Sin botón volver**: §login no lo define (entrada raíz desde welcome).
- **Tipografía real** = los valores aprobados en register: heading 32,
  descripción 16, campos 16, forgot-link 16, botón 18, divisor 15, Google 17,
  prompt registro 16.
- **Heading a la izquierda** (confirmado con el usuario): se aparta del spec
  §login que lo pide centrado — queda igual que register; el yaml se actualiza.
- **DIP como en register**: `LoginScreen` recibe el cubit por constructor y lo
  resuelve `AppRouter` (salda la deuda de `locator` en presentation).
- Botón primario 64px de alto (igual que register; spec dice 68–72, queda
  consistente entre pantallas hermanas).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/screens/login_screen.dart` | **Reescritura** al spec §login (misma estructura que register) |
| `lib/core/routes/app_router.dart` | `/login` → `LoginScreen(cubit: locator<LoginCubit>())` + import |
| `lib/core/routes/auth_guard.dart` | Nueva const `forgotPasswordRoute` (la pantalla y el router dejan el literal `'/forgot-password'`) |
| `lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` | +4 claves nuevas, −4 huérfanas + `flutter gen-l10n` |
| `../Design/quesivo-design-system.yaml` | §login: tipografía a valores reales + `bottom_left` `enabled: false` + changelog v1.0.3 |

**Claves i18n — nuevas:** `loginDescription`, `loginDivider`, `noAccountPrompt`,
`signUpLink`. **Reutilizadas:** `loginTitle`, `forgotPassword`, `loginButton`,
`continueWithGoogle`, `registerEmailPlaceholder`, `registerPasswordPlaceholder`,
`invalidEmailError`, `invalidPasswordError`, `genericAuthError`, `welcomeMessage`.
**Se eliminan (huérfanas tras el rediseño):** `emailLabel`, `passwordLabel`,
`loginGoogleButton`, `changeLanguageTooltip` — verificar antes de borrar que
ningún otro archivo las usa.

---

## 1. `login_screen.dart` (reescritura completa)

**Ruta:** `lib/features/auth/presentation/screens/login_screen.dart`

```dart
// lib/features/auth/presentation/screens/login_screen.dart
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
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/quesivo_auth_field.dart';

/// Pantalla de Login QUESIVO (quesivo-design-system.yaml §login).
///
/// SOLID (SRP): Dumb View — solo lee `LoginState` y repinta. El Cubit
/// local llega por constructor (resuelto por `AppRouter` vía DI factory);
/// la sesión la maneja el `AuthCubit` global vía `checkSession()`.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.cubit});

  /// Cubit de formulario resuelto por `AppRouter` vía DI (factory) — la
  /// pantalla no conoce el Service Locator (DIP).
  final LoginCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginCubit>(
      create: (context) => cubit,
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Mismo criterio que register: solo el círculo amarillo con huecos;
        // el navy inferior se omite para no competir con el form.
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
                } else if (state is AuthSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.welcomeMessage(state.user.name)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              },
            ),
            BlocListener<LoginCubit, LoginState>(
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

                  // --- Heading + descripción (§login_heading, a la izquierda
                  //     como register — decisión del usuario sobre el spec) ---
                  Text(
                    l10n.loginTitle,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.loginDescription,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: AppColors.quesivoDarkText,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- Formulario (§login_form) ---
                  BlocBuilder<LoginCubit, LoginState>(
                    buildWhen: (p, c) => p.email != c.email,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.registerEmailPlaceholder,
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) =>
                          context.read<LoginCubit>().emailChanged(v),
                      errorText: state.email.displayError != null
                          ? l10n.invalidEmailError
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<LoginCubit, LoginState>(
                    buildWhen: (p, c) => p.password != c.password,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.registerPasswordPlaceholder,
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      onChanged: (v) =>
                          context.read<LoginCubit>().passwordChanged(v),
                      errorText: state.password.displayError != null
                          ? l10n.invalidPasswordError
                          : null,
                    ),
                  ),

                  // --- ¿Olvidaste tu contraseña? (§forgot_password, right) ---
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => context.push(AuthGuard.forgotPasswordRoute),
                      child: Text(
                        l10n.forgotPassword,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.quesivoYellow,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.quesivoYellow,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Acción primaria (§primary_button: pill amarillo 64px) ---
                  BlocBuilder<LoginCubit, LoginState>(
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
                                                .read<LoginCubit>()
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
                                    child: Text(l10n.loginButton),
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
                                        l10n.loginDivider,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color:
                                              AppColors.quesivoTextSecondary,
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

                                // --- Google (§google_login: pill blanco) ---
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

                                // --- Link a registro (§register_prompt) ---
                                Center(
                                  child: GestureDetector(
                                    onTap: () => context
                                        .push(AuthGuard.registerRoute),
                                    child: Text.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: AppColors.quesivoDarkText,
                                        ),
                                        children: [
                                          TextSpan(text: l10n.noAccountPrompt),
                                          const TextSpan(text: ' '),
                                          TextSpan(
                                            text: l10n.signUpLink,
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

## 2. `app_router.dart` (actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Imports — junto a `login_screen.dart`:**
```dart
import '../../features/auth/presentation/cubit/login_cubit.dart';
```

**Antes:**
```dart
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitions.<transición actual>(
          ...
          child: const LoginScreen(),
        ),
      ),
```

**Después:**
```dart
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitions.<misma transición>(
          ...
          child: LoginScreen(cubit: locator<LoginCubit>()),
        ),
      ),
```

(Mantener la transición existente de `/login`; solo cambia el child. El
`locator` ya está importado en el archivo por `OnboardingScreen`/`RegisterScreen`.)

## 3. `auth_guard.dart` (actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

**Después de `registerRoute`:**
```dart
  static const String forgotPasswordRoute = '/forgot-password';
```

`app_router.dart` (`path: '/forgot-password'`) pasa a usar la const; la pantalla
de login la usa para el link "¿Olvidaste tu contraseña?".

## 4. Diccionarios i18n

**`app_es.arb` — agregar (junto a las claves de auth):**
```json
  "loginDescription": "Ingresa a tu cuenta para continuar gestionando tu quesera.",
  "loginDivider": "o continuar con",
  "noAccountPrompt": "¿No tienes una cuenta?",
  "signUpLink": "Registrarse"
```

**`app_en.arb`:**
```json
  "loginDescription": "Sign in to continue managing your cheese factory.",
  "loginDivider": "or continue with",
  "noAccountPrompt": "Don't have an account?",
  "signUpLink": "Sign up"
```

**`app_pt.arb`:**
```json
  "loginDescription": "Entre para continuar gerenciando sua queijaria.",
  "loginDivider": "ou continue com",
  "noAccountPrompt": "Não tem uma conta?",
  "signUpLink": "Cadastre-se"
```

**Eliminar de los 3 archivos** (quedan sin uso tras el rediseño): `emailLabel`,
`passwordLabel`, `loginGoogleButton`, `changeLanguageTooltip`.

Después ejecutar **`flutter gen-l10n`** (los `app_localizations*.dart` se
regeneran, no se editan a mano).

## 5. `quesivo-design-system.yaml` (actualización de spec)

En `login` (misma política que register v1.0.2): tipografía a valores reales
implementados — `login_heading.title` `32px`, `description` `16px`, campos
`text.size` `16px`, `forgot_password.text` `16px`, `primary_button.text` `18px`,
`social_divider.center_text` `15px`, `google_login.text` `17px`,
`register_prompt` `16px`/`16px`; `decorative_elements.bottom_left` →
`enabled: false` con nota (mismo criterio que register); `login_heading` →
`alignment.horizontal: "left"` en título y descripción (decisión del usuario:
igual que register, no centrado). Changelog nuevo `v1.0.3` (page `login`)
asentando ambos ajustes.

## 6. Tests

Sin tests nuevos: `LoginCubit`/`LoginState` no cambian y el proyecto no tiene
widget tests de pantallas. Verificación: `flutter analyze` 0 issues +
`flutter test` (los 61 existentes deben seguir pasando).

## Notas

- `LocaleCubit` sigue registrado en DI; solo desaparece su botón del AppBar.
  Si producto quiere switcher de idioma en el futuro, va como ítem del menú de
  la app, no en auth.
- `forgot_password_screen.dart` sigue con el diseño viejo — rediseñarla es una
  propuesta aparte (su spec §forgot_password ya existe en el yaml).
