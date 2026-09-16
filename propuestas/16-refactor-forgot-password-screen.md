# Propuesta: Refactor — dividir `forgot_password_screen.dart` en widgets

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77. Revisor: APROBADO sin hallazgos. `forgot_password_screen.dart` 280 → ~105 líneas; `ForgotPasswordForm` + `ForgotPasswordInfoCard` + `ForgotPasswordActions` nuevos. `AuthHeading` ganó `titleHeight`/`titleGap`/`descriptionHeight` (defaults preservan register/login; forgot pasa 1.05/16/1.45 para paridad literal).

Mismo patrón que register (propuesta 14) y login (propuesta 15): la screen
queda como shell (backdrop + listener + scroll) componiendo widgets.
**Sin cambios de píxeles ni comportamiento.**

Reutiliza los compartidos: `QuesivoBrandHeader`, `AuthHeading` (necesita 2
params opcionales nuevos — ver §1), `QuesivoPrimaryButton`, `AuthPrompt` NO se
reusa acá (el prompt de forgot es apilado, no en línea — queda dentro del
widget de acciones).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/widgets/auth_heading.dart` | Agregar params opcionales `titleHeight` (default 1.0) y `titleGap` (default 14) — forgot usa 1.05/16; los defaults preservan register/login |
| `lib/features/auth/presentation/widgets/forgot_password_form.dart` | **Nuevo** — `BlocBuilder` del campo email |
| `lib/features/auth/presentation/widgets/forgot_password_info_card.dart` | **Nuevo** — la card "Revisa tu correo" (params title/description) |
| `lib/features/auth/presentation/widgets/forgot_password_actions.dart` | **Nuevo** — `BlocBuilder` inferior (spinner / card / botón) + prompt apilado + botón dev |
| `lib/features/auth/presentation/screens/forgot_password_screen.dart` | **Reduce a shell** (~90 líneas) |

---

## 1. `auth_heading.dart` (params opcionales nuevos)

```dart
const AuthHeading({
  super.key,
  required this.title,
  required this.description,
  this.titleHeight = 1.0,
  this.titleGap = 14,
  this.descriptionMaxLines = 2,
  this.descriptionColor = AppColors.quesivoDarkText,
});
```
`titleHeight` alimenta el `height` del título; `titleGap` el `SizedBox` entre
título y descripción. Los defaults = valores de register/login (sin cambio
para ellos).

## 2. `forgot_password_form.dart` (archivo nuevo)

`ForgotPasswordForm` — stateless, `l10n` por context:

```dart
// --- Campo email (§email_form) ---
BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
  buildWhen: (p, c) => p.email != c.email,
  builder: (context, state) => QuesivoAuthField(
    hintText: l10n.registerEmailPlaceholder,
    prefixIcon: Icons.mail_outline,
    keyboardType: TextInputType.emailAddress,
    onChanged: (v) =>
        context.read<ForgotPasswordCubit>().emailChanged(v),
    errorText:
        state.email.displayError != null ? l10n.invalidEmailError : null,
  ),
)
```

## 3. `forgot_password_info_card.dart` (archivo nuevo)

`ForgotPasswordInfoCard({required this.title, required this.description})` —
el `Container` surface radius 26 + Row [círculo iconSurface 90px +
`mark_email_unread_outlined` navy 44, SizedBox(20), Column title 17/w700 navy
+ gap 8 + desc 15/1.4 secondary] — literal del actual.

## 4. `forgot_password_actions.dart` (archivo nuevo)

`ForgotPasswordActions` — `BlocBuilder` (`buildWhen` status/isValid, ya
agregado post-revisión):

```dart
if (state.status.isInProgress) return const Center(child: CircularProgressIndicator());
return Column(children: [
  if (state.status.isSuccess)
    ForgotPasswordInfoCard(title: l10n.checkEmailTitle, description: l10n.checkEmailDescription)
  else
    QuesivoPrimaryButton(
      label: l10n.sendResetLinkButton,
      onPressed: state.isValid ? () { unfocus + submit } : null,
    ),
  const SizedBox(height: 40),
  // --- Link a login (§login_prompt, apilado) — literal del actual ---
  Center(child: Column(children: [Text(rememberedPassword 16 secondary), gap 4,
    GestureDetector(canPop ? pop : go(loginRoute)) Text(signInLink 17 w700 yellow)])),
  // ⚠️ ACCESO TEMPORAL DE DESARROLLO (literal, con su comentario) ---
  if (Environment.currentEnvironment == EnvType.dev)
    TextButton(push '/reset-password?token=dev' → devResetLink),
  const SizedBox(height: 20),
]);
```

## 5. `forgot_password_screen.dart` (reducido)

```dart
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key, required this.cubit});
  final ForgotPasswordCubit cubit;
  // BlocProvider<ForgotPasswordCubit>(create: (_) => cubit, child: _ForgotPasswordView())
}

class _ForgotPasswordView extends StatelessWidget {
  // Scaffold(quesivoWhite) > QuesivoBackdrop(0.68/0) >
  // BlocListener<ForgotPasswordCubit> (SIN CAMBIOS — solo isFailure snackbar)
  // > SafeArea > scroll > Column(start):
  //
  //   const SizedBox(height: 48),
  //   const QuesivoBrandHeader(logoFraction: 0.62),
  //   AuthHeading(
  //     title: l10n.forgotPassword,
  //     description: l10n.forgotPasswordInstructions,
  //     titleHeight: 1.05,
  //     titleGap: 16,
  //     descriptionColor: AppColors.quesivoTextSecondary,
  //     descriptionMaxLines: 3,
  //   ),
  //   const ForgotPasswordForm(),
  //   const SizedBox(height: 36),
  //   const ForgotPasswordActions(),
}
```

Borrar imports muertos (`go_router`, `auth_guard`, `environment`,
`quesivo_auth_field`, etc. — los que migren a los widgets). El doc comment y
los comentarios de sección se conservan.

## 6. Reglas (mismas que propuestas 14/15)

- **Literal**: cero cambios de píxel/estilo/comportamiento; comentarios
  explicativos viajan con el código (el del acceso dev incluido).
- Listener en la shell sin cambios.
- Doc comment de intención en widgets nuevos; `const` donde aplique.
- No tocar cubits/state/VOs ni nada fuera de `presentation/`.

## 7. Verificación

- `flutter analyze` — 0 issues.
- `flutter test` — 77/77.
- Manual: `/forgot-password` pixel-par; el flujo éxito→card intacto.
