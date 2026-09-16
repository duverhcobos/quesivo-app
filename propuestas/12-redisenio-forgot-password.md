# Propuesta: Rediseño de la pantalla Forgot Password (`/forgot-password`)

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 65/65. Decisiones tomadas con el usuario antes de implementar: sin flecha volver, sin círculo navy, info card como confirmación post-envío (sin snackbar/pop), heading "¿Olvidaste tu contraseña?". Ajustes post-revisor: `buildWhen` en el builder inferior (aplicado también a register/login por simetría), `maxLines: 3` en la descripción y spacing 40px del spec.

Última pantalla de auth con el diseño genérico heredado (AppBar, icono
`lock_reset`, `CustomTextField` con label). Se rediseña según
`Design/quesivo-design-system.yaml` §forgot_password (líneas ~2111–2460)
replicando los patrones de `/register` y `/login`: `QuesivoBackdrop`,
`QuesivoAuthField`, tipografía real, pill amarillo, DIP por constructor.

No toca dominio ni data: `ForgotPasswordCubit`/`ForgotPasswordState` se
conservan — es presentation + routing + i18n + spec.

## Decisiones (ya tomadas con el usuario)

- **Sin botón volver** (igual que register): la salida es el gesto atrás del
  sistema (vuelve a login por `pop`) o el link "Iniciar sesión" al pie. El spec
  se actualiza a `back_button.enabled: false`.
- **Sin círculo navy inferior** (`bottomCircleFraction: 0`) — mismo criterio;
  el spec se actualiza.
- **Info card solo tras envío**: al éxito NO hay snackbar ni `pop` automático —
  el botón se reemplaza por la card "Revisa tu correo" como estado de
  confirmación dentro de la misma pantalla, y el usuario sale por "Iniciar
  sesión" o el gesto atrás. La descripción de la card pasa a tiempo pasado
  ("Te enviamos un enlace…").
- **Tipografía real**: heading 32, descripción 16, campo 16, botón 18, card
  título 17 / descripción 15, prompt 16/17.
- Icono del card: `Icons.mark_email_unread_outlined` navy (Material no tiene el
  mail con acento amarillo del spec; se documenta la aproximación).
- Cubit por constructor resuelto por `AppRouter` (DIP, como register/login).
- Quedan huérfanas tras el rediseño → se eliminan: `emailLabel`,
  `forgotPasswordTitle` (el heading usa `forgotPassword`, texto del spec),
  `sendInstructionsButton` (→ `sendResetLinkButton` "Enviar enlace") y
  `forgotPasswordEmailSentSuccess` (ya no hay snackbar de éxito).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/screens/forgot_password_screen.dart` | **Reescritura** al spec §forgot_password |
| `lib/core/routes/app_router.dart` | `/forgot-password` → `ForgotPasswordScreen(cubit: locator<ForgotPasswordCubit>())` + import |
| `lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` | +4 claves, −3 huérfanas, 1 texto actualizado + `flutter gen-l10n` |
| `../Design/quesivo-design-system.yaml` | §forgot_password: tipografía real + `bottom_left` `enabled: false` + changelog v1.0.5 |

**Claves i18n — nuevas:** `checkEmailTitle`, `checkEmailDescription`,
`rememberedPassword`, `sendResetLinkButton`.
**Reutilizadas:** `forgotPassword` (heading), `forgotPasswordInstructions`
(texto actualizado al spec), `registerEmailPlaceholder`, `invalidEmailError`,
`forgotPasswordGenericError`, `signInLink`.
**Eliminadas:** `emailLabel`, `forgotPasswordTitle`, `sendInstructionsButton`,
`forgotPasswordEmailSentSuccess`.

---

## 1. `forgot_password_screen.dart` (reescritura completa)

**Ruta:** `lib/features/auth/presentation/screens/forgot_password_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';
import '../widgets/quesivo_auth_field.dart';

/// Pantalla de Recuperación de Contraseña QUESIVO
/// (quesivo-design-system.yaml §forgot_password).
///
/// SOLID (SRP): Dumb View — solo lee `ForgotPasswordState` y repinta. El
/// Cubit llega por constructor (resuelto por `AppRouter` vía DI factory).
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key, required this.cubit});

  /// Cubit de formulario resuelto por `AppRouter` vía DI (factory) — la
  /// pantalla no conoce el Service Locator (DIP).
  final ForgotPasswordCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ForgotPasswordCubit>(
      create: (context) => cubit,
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatelessWidget {
  const _ForgotPasswordView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Mismo criterio que register/login: solo el círculo amarillo.
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ?? l10n.forgotPasswordGenericError,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
            // Al éxito no hay snackbar ni pop: la sección inferior se
            // reemplaza por la info card "Revisa tu correo" (ver BlocBuilder).
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // --- Imagen de marca (~62% ancho, §brand_header) ---
                  Center(
                    child: Image.asset(
                      'assets/images/imagotipo_quesivo.png',
                      width: size.width * 0.62,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),

                  // --- Heading + descripción (§forgot_password_heading) ---
                  Text(
                    l10n.forgotPassword,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.forgotPasswordInstructions,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: AppColors.quesivoTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- Campo email (§email_form) ---
                  BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                    buildWhen: (p, c) => p.email != c.email,
                    builder: (context, state) => QuesivoAuthField(
                      hintText: l10n.registerEmailPlaceholder,
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) => context
                          .read<ForgotPasswordCubit>()
                          .emailChanged(v),
                      errorText: state.email.displayError != null
                          ? l10n.invalidEmailError
                          : null,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- Sección inferior: botón → card de confirmación ---
                  // Antes de enviar: pill "Enviar enlace". En progreso:
                  // spinner. Tras envío exitoso: info card "Revisa tu
                  // correo" como estado de confirmación (sin snackbar/pop).
                  BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                    builder: (context, state) {
                      if (state.status.isInProgress) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      return Column(
                        children: [
                          if (state.status.isSuccess)
                            // --- Info card (§information_card) — solo tras envío ---
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 26,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.quesivoSurface,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: const BoxDecoration(
                                      color: AppColors.quesivoIconSurface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.mark_email_unread_outlined,
                                      color: AppColors.quesivoNavy,
                                      size: 44,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.checkEmailTitle,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.quesivoNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.checkEmailDescription,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.4,
                                            color: AppColors
                                                .quesivoTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            // --- Acción primaria (§primary_button: "Enviar enlace") ---
                            SizedBox(
                              width: double.infinity,
                              height: 64,
                              child: ElevatedButton(
                                onPressed: state.isValid
                                    ? () {
                                        FocusScope.of(context).unfocus();
                                        context
                                            .read<ForgotPasswordCubit>()
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
                                child: Text(l10n.sendResetLinkButton),
                              ),
                            ),
                          const SizedBox(height: 30),

                          // --- Link a login (§login_prompt, apilado) ---
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  l10n.rememberedPassword,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color:
                                        AppColors.quesivoTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => context.canPop()
                                      ? context.pop()
                                      : context.go(
                                          AuthGuard.loginRoute,
                                        ),
                                  child: Text(
                                    l10n.signInLink,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.quesivoYellow,
                                    ),
                                  ),
                                ),
                              ],
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

**Imports — junto a los otros cubits:**
```dart
import '../../features/auth/presentation/cubit/forgot_password_cubit.dart';
```

**Antes:**
```dart
          child: const ForgotPasswordScreen(),
```

**Después:**
```dart
          child: ForgotPasswordScreen(
            cubit: locator<ForgotPasswordCubit>(),
          ),
```

(Mantener la transición `CustomTransitions.fade` existente.)

## 3. Diccionarios i18n

**`app_es.arb` — agregar:**
```json
  "checkEmailTitle": "Revisa tu correo",
  "checkEmailDescription": "Te enviamos un enlace para que puedas crear una nueva contraseña de forma segura.",
  "rememberedPassword": "¿Recordaste tu contraseña?",
  "sendResetLinkButton": "Enviar enlace"
```

**`app_en.arb`:**
```json
  "checkEmailTitle": "Check your email",
  "checkEmailDescription": "We've sent you a link so you can create a new password safely.",
  "rememberedPassword": "Remembered your password?",
  "sendResetLinkButton": "Send link"
```

**`app_pt.arb`:**
```json
  "checkEmailTitle": "Verifique seu e-mail",
  "checkEmailDescription": "Enviamos um link para você criar uma nova senha com segurança.",
  "rememberedPassword": "Lembrou sua senha?",
  "sendResetLinkButton": "Enviar link"
```

**Actualizar `forgotPasswordInstructions` al texto del spec:**
- es: `"No te preocupes, ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña."`
- en: `"Don't worry, enter your email and we'll send you a link to reset your password."`
- pt: `"Não se preocupe, insira seu e-mail e enviaremos um link para redefinir sua senha."`

**Eliminar de los 3 archivos:** `emailLabel` (huérfana tras este rediseño),
`forgotPasswordTitle`, `sendInstructionsButton`, `forgotPasswordEmailSentSuccess`
(ya no hay snackbar de éxito — la card es la confirmación).

Después ejecutar **`flutter gen-l10n`**.

## 4. `quesivo-design-system.yaml` (spec)

En `future_pages.forgot_password`: tipografía a valores reales — heading `32px`,
description `16px`, email field `text.size` `16px`, `primary_button.text` `18px`,
`information_card` title `17px` / description `15px`, `login_prompt`
`16px`/`17px`; `decorative_elements.bottom_left` → `enabled: false` con nota
(mismo criterio que register/login); `navigation.back_button` → `enabled: false`
con nota (salida por gesto atrás o link "Iniciar sesión"); `information_card`
documentado como estado de confirmación post-envío (reemplaza la acción
primaria al éxito — no es una sección estática); `brand_header.logo.width`
documentado como `~62%`. Changelog `v1.0.5` (page `forgot_password`).

## 5. Tests y verificación

Sin tests nuevos (cubit/estado intactos). Verificación: `flutter analyze`
0 issues + `flutter test` (los 65 existentes deben pasar).

## Notas

- `reset_password` (la pantalla de crear contraseña nueva desde el enlace) tiene
  spec en el yaml (~línea 2700+) pero **no tiene feature implementada** — sería
  propuesta aparte junto con su use case/endpoint.
