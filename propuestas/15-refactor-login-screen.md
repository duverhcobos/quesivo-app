# Propuesta: Refactor — dividir `login_screen.dart` en widgets componibles

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77. Revisor: APROBADO sin hallazgos. `login_screen.dart` 318 → ~119 líneas; `LoginFormFields` + `LoginActions` nuevos, reusa los 6 compartidos de la propuesta 14.

Continuación del refactor de `register_screen.dart` (propuesta 14) con el
mismo patrón: la screen queda como shell (backdrop + listeners + scroll) y las
secciones se extraen a widgets. **Sin cambios de píxeles ni comportamiento.**

Login reutiliza directamente los compartidos ya creados: `QuesivoBrandHeader`,
`AuthHeading` (los defaults coinciden con login: título 32/1.0, desc 16
`quesivoDarkText`), `QuesivoPrimaryButton`, `AuthDivider`,
`GoogleAuthButton`, `AuthPrompt`. Solo hacen falta 2 widgets nuevos
específicos de login.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/widgets/login_form_fields.dart` | **Nuevo** — email + password `BlocBuilder`s + link "¿Olvidaste tu contraseña?" |
| `lib/features/auth/presentation/widgets/login_actions.dart` | **Nuevo** — `BlocBuilder` inferior (botón + divisor + Google + prompt) |
| `lib/features/auth/presentation/screens/login_screen.dart` | **Reduce a shell** (~105 líneas) — compone los widgets |

---

## 1. `login_form_fields.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/widgets/login_form_fields.dart`

`LoginFormFields` — stateless, lee `l10n` por context, `BlocBuilder`s internos
(mismo criterio que `RegisterFormFields`):

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // --- Email (§login_form.email) ---
    BlocBuilder<LoginCubit, LoginState>(
      buildWhen: (p, c) => p.email != c.email,
      builder: (context, state) => QuesivoAuthField(
        hintText: l10n.registerEmailPlaceholder,
        prefixIcon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
        onChanged: (v) => context.read<LoginCubit>().emailChanged(v),
        errorText:
            state.email.displayError != null ? l10n.invalidEmailError : null,
      ),
    ),
    const SizedBox(height: 16),

    // --- Password (§login_form.password) ---
    BlocBuilder<LoginCubit, LoginState>(
      buildWhen: (p, c) => p.password != c.password,
      builder: (context, state) => QuesivoAuthField(
        hintText: l10n.registerPasswordPlaceholder,
        prefixIcon: Icons.lock_outline,
        isPassword: true,
        onChanged: (v) => context.read<LoginCubit>().passwordChanged(v),
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
  ],
);
```

## 2. `login_actions.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/widgets/login_actions.dart`

`LoginActions` — `BlocBuilder` (`buildWhen` status/isValid) → inProgress ?
spinner : Column (mismos spacers 28/22/26/20):

```dart
QuesivoPrimaryButton(
  label: l10n.loginButton,
  onPressed: state.isValid
      ? () {
          FocusScope.of(context).unfocus();
          context.read<LoginCubit>().submit();
        }
      : null,
),
const SizedBox(height: 28),
AuthDivider(text: l10n.loginDivider),
const SizedBox(height: 22),
GoogleAuthButton(
  label: l10n.continueWithGoogle,
  onPressed: () => context.read<AuthCubit>().loginWithGoogle(),
),
const SizedBox(height: 26),
AuthPrompt(
  text: l10n.noAccountPrompt,
  linkText: l10n.signUpLink,
  onTap: () => context.push(AuthGuard.registerRoute),
),
const SizedBox(height: 20),
```

## 3. `login_screen.dart` (reducido)

```dart
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.cubit});
  final LoginCubit cubit;
  // BlocProvider<LoginCubit>(create: (_) => cubit, child: _LoginView())
}

class _LoginView extends StatelessWidget {
  // Scaffold(quesivoWhite) > QuesivoBackdrop(0.68 / 0) > MultiBlocListener
  // (AuthCubit AuthError snackbar + LoginCubit status failure/success —
  //  SIN CAMBIOS) > SafeArea > SingleChildScrollView > Column(start):
  //
  //   const SizedBox(height: 48),
  //   const QuesivoBrandHeader(logoFraction: 0.65),
  //   AuthHeading(title: l10n.loginTitle, description: l10n.loginDescription),
  //   const LoginFormFields(),
  //   const SizedBox(height: 24),
  //   const LoginActions(),
}
```

Borrar los imports que migran a los widgets (`flutter_svg`, `go_router`,
`auth_guard`, `quesivo_auth_field`).

## 4. Reglas (mismas que propuesta 14)

- **Literal**: cero cambios de píxel/estilo/comportamiento; los comentarios
  explicativos viajan con el código.
- Listeners en la shell sin cambios (incluye el `if (state is AuthError)` del
  listener de AuthCubit — estilo preferido del usuario, ver `bloc-patterns`).
- Doc comment de intención en cada widget nuevo; `const` donde aplique.
- No tocar cubits/state/VOs.

## 5. Verificación

- `flutter analyze` — 0 issues.
- `flutter test` — 77/77.
- Manual: `/login` pixel-par con la versión anterior.
