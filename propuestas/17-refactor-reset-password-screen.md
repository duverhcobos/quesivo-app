# Propuesta: Refactor — dividir `reset_password_screen.dart` en widgets

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77. Revisor: APROBADO sin hallazgos. `reset_password_screen.dart` 229 → ~109 líneas; `ResetPasswordFormFields` + `ResetPasswordActions` nuevos. (Nota: `go_router`/`auth_guard` quedaron en la shell — los usa el listener.)

Última pantalla de auth con el mismo patrón (propuestas 14/15/16): la screen
queda como shell (backdrop + listener + scroll) componiendo widgets.
**Sin cambios de píxeles ni comportamiento.**

Reutiliza los compartidos: `QuesivoBrandHeader`, `AuthHeading` (con los params
ya agregados en propuesta 16), `QuesivoPrimaryButton` y
`PasswordRequirementsChecklist`. Solo hacen falta 2 widgets nuevos.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/widgets/reset_password_form_fields.dart` | **Nuevo** — campo nueva contraseña + checklist + confirmación (3 `BlocBuilder`s) |
| `lib/features/auth/presentation/widgets/reset_password_actions.dart` | **Nuevo** — `BlocBuilder` inferior (spinner / botón + link a login) |
| `lib/features/auth/presentation/screens/reset_password_screen.dart` | **Reduce a shell** (~90 líneas) |

---

## 1. `reset_password_form_fields.dart` (archivo nuevo)

`ResetPasswordFormFields` — stateless, `l10n` por context, `BlocBuilder`s
internos (literal del actual):

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // --- Nueva contraseña (§password_form.new_password) ---
    BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
      buildWhen: (p, c) => p.password != c.password,
      builder: (context, state) => QuesivoAuthField(
        hintText: l10n.newPasswordPlaceholder,
        prefixIcon: Icons.lock_outline,
        isPassword: true,
        onChanged: (v) =>
            context.read<ResetPasswordCubit>().passwordChanged(v),
      ),
    ),
    const SizedBox(height: 16),
    // --- Requisitos (mismo checklist vivo que en register) ---
    BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
      buildWhen: (p, c) => p.password.value != c.password.value,
      builder: (context, state) => PasswordRequirementsChecklist(
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
        onChanged: (v) =>
            context.read<ResetPasswordCubit>().confirmPasswordChanged(v),
        errorText: state.confirmPassword.displayError != null
            ? l10n.passwordsDoNotMatchError
            : null,
      ),
    ),
  ],
)
```

## 2. `reset_password_actions.dart` (archivo nuevo)

`ResetPasswordActions` — `BlocBuilder` (`buildWhen` status/isValid) →
inProgress ? spinner : Column (literal actual):

```dart
QuesivoPrimaryButton(
  label: l10n.updatePasswordButton,
  onPressed: state.isValid
      ? () {
          FocusScope.of(context).unfocus();
          context.read<ResetPasswordCubit>().submit();
        }
      : null,
),
const SizedBox(height: 40),
// --- Link a login (§login_link) ---
Center(
  child: GestureDetector(
    onTap: () => context.go(AuthGuard.loginRoute),
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
```

## 3. `reset_password_screen.dart` (reducido)

```dart
// BlocProvider<ResetPasswordCubit>(create: (_) => cubit, child: _ResetPasswordView())
// Scaffold(quesivoWhite) > QuesivoBackdrop(0.68/0) >
// BlocListener<ResetPasswordCubit> (SIN CAMBIOS — snackbar error +
//   snackbar success + context.go(loginRoute)) > SafeArea > scroll >
// Column(start):
//
//   const SizedBox(height: 48),
//   const QuesivoBrandHeader(logoFraction: 0.55),
//   AuthHeading(
//     title: l10n.resetTitle,
//     description: l10n.resetDescription,
//     titleHeight: 1.05,
//     titleGap: 16,
//     descriptionColor: AppColors.quesivoPlaceholder,
//     // descriptionMaxLines default 2 y descriptionHeight default 1.4
//     // ya coinciden con los valores actuales de reset.
//   ),
//   const ResetPasswordFormFields(),
//   const SizedBox(height: 36),
//   const ResetPasswordActions(),
```

Borrar imports muertos (`go_router`, `auth_guard`, `password_requirements_checklist`,
`quesivo_auth_field`). Doc comment y comentarios de sección se conservan.

## 4. Reglas (mismas que propuestas 14–16)

- **Literal**: cero cambios de píxel/estilo/comportamiento; comentarios viajan
  con el código (incluye el de "spec destinations.success → login" del
  listener, que se queda en la shell).
- Listener en la shell sin cambios.
- Doc comment de intención en widgets nuevos; `const` donde aplique.
- No tocar cubits/state/VOs ni nada fuera de `presentation/`.

## 5. Verificación

- `flutter analyze` — 0 issues.
- `flutter test` — 77/77.
- Manual: `/reset-password` pixel-par; éxito → snackbar + `/login`.
