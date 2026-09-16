# Propuesta: Refactor — dividir `register_screen.dart` en widgets componibles

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77. Revisor: APROBADO sin hallazgos. `register_screen.dart` 427 → ~128 líneas; 9 widgets extraídos (6 compartidos para reuso en login/forgot/reset + 3 de register).

`register_screen.dart` tiene ~430 líneas con todo el layout inline. El archivo
de la pantalla pasa a ser solo la shell (backdrop + listeners + scroll) que
importa y ordena los elementos visuales — cada sección se extrae a su widget.
**Sin cambios de comportamiento ni de píxeles** — refactor puro de estructura.

Los widgets compartidos (brand header, heading, pill, divisor, botón Google,
prompt) se extraen a nivel feature `auth` porque login/forgot/reset los
reutilizarán en el mismo refactor posterior.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/widgets/quesivo_brand_header.dart` | **Nuevo compartido** — imagotipo centrado + gap |
| `lib/features/auth/presentation/widgets/auth_heading.dart` | **Nuevo compartido** — título 32 navy + descripción 16 |
| `lib/features/auth/presentation/widgets/quesivo_primary_button.dart` | **Nuevo compartido** — pill amarillo 64px/18 |
| `lib/features/auth/presentation/widgets/auth_divider.dart` | **Nuevo compartido** — divisor con texto central |
| `lib/features/auth/presentation/widgets/google_auth_button.dart` | **Nuevo compartido** — outlined pill con `google_g.svg` |
| `lib/features/auth/presentation/widgets/auth_prompt.dart` | **Nuevo compartido** — texto + link amarillo en línea |
| `lib/features/auth/presentation/widgets/register_form_fields.dart` | **Nuevo (register)** — los 5 `BlocBuilder` de campos + checklist |
| `lib/features/auth/presentation/widgets/register_terms.dart` | **Nuevo (register)** — checkbox + texto legal |
| `lib/features/auth/presentation/widgets/register_actions.dart` | **Nuevo (register)** — `BlocBuilder` inferior (botón + divisor + Google + prompt) |
| `lib/features/auth/presentation/screens/register_screen.dart` | **Reduce a shell** — compone los widgets |

---

## 1. Widgets compartidos nuevos

Todos stateless, con params mínimos, estilos idénticos a lo que hoy está inline
(copiar literal). Leen `AppLocalizations` por dentro SOLO los específicos de
register; los compartidos reciben sus textos por constructor (como
`PasswordRequirementsChecklist`).

**`quesivo_brand_header.dart`:**
```dart
/// Imagotipo centrado + gap inferior (§brand_header). `logoFraction` =
/// fracción del ancho (register 0.65, forgot 0.62, reset 0.55, login 0.62).
class QuesivoBrandHeader extends StatelessWidget {
  const QuesivoBrandHeader({super.key, required this.logoFraction});
  final double logoFraction;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Column(
      children: [
        Center(
          child: Image.asset(
            'assets/images/imagotipo_quesivo.png',
            width: size.width * logoFraction,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: size.height * 0.03),
      ],
    );
  }
}
```

**`auth_heading.dart`:**
```dart
/// Título 32/w800 navy + descripción 16 (§*_heading, alineado a la izquierda).
class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.title,
    required this.description,
    this.descriptionMaxLines = 2,
    this.descriptionColor = AppColors.quesivoDarkText,
  });
  final String title;
  final String description;
  final int descriptionMaxLines;
  final Color descriptionColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.0,
            color: AppColors.quesivoNavy,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          description,
          maxLines: descriptionMaxLines,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: descriptionColor,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
```
(Ojo: register usa `height: 1.0` en el título y `SizedBox(14)`/desc
`quesivoDarkText`; forgot usa `height: 1.05`, `SizedBox(16)` y
`quesivoTextSecondary`; reset `quesivoPlaceholder`. Para no alterar píxeles de
register ahora, los params con default = valores de register; cuando se
refactoren las otras se pasan los suyos.)

**`quesivo_primary_button.dart`:**
```dart
/// Pill amarillo 64px/18/w700 (§primary_button) con estado disabled atenuado.
class QuesivoPrimaryButton extends StatelessWidget {
  const QuesivoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed, // null = disabled
  });
  final String label;
  final VoidCallback? onPressed;
  // ElevatedButton.styleFrom idéntico al actual (quesivoYellow/quesivoNavy,
  // disabled *0.45/0.5, StadiumBorder, 18px w700), height 64, full width.
}
```

**`auth_divider.dart`:** Row con dos `Divider(quesivoBorder)` + `Text(text)`
15px secondary centrado (literal del actual).

**`google_auth_button.dart`:** `OutlinedButton.icon` con `SvgPicture.asset
('assets/images/google_g.svg', 24)` — outlined pill 64px, 17px w600 navy,
border quesivoBorder 1.5 — params `{label, onPressed}`.

**`auth_prompt.dart`:**
```dart
/// "texto plano linkAmarillo" en una línea (§login_prompt / register_prompt).
class AuthPrompt extends StatelessWidget {
  const AuthPrompt({
    super.key,
    required this.text,
    required this.linkText,
    required this.onTap,
  });
  final String text;
  final String linkText;
  final VoidCallback onTap;
  // GestureDetector > Text.rich 16px darkText + TextSpan amarillo w700.
}
```

## 2. Widgets específicos de register

Los `BlocBuilder` quedan DENTRO de estos widgets (usan
`context.read<RegisterCubit>()` que resuelve por el `BlocProvider` de la
pantalla — no hace falta pasar el cubit). Leen `l10n` por context.

**`register_form_fields.dart` — `RegisterFormFields`:** Column con los 5
campos (`orgName`, `fullName`, `email`, `password`, `confirmPassword`) y el
`PasswordRequirementsChecklist` entre password y confirm, mismos
`buildWhen`/errorText/spacers de hoy.

**`register_terms.dart` — `RegisterTermsCheckbox`:** `BlocBuilder` sobre
`termsAccepted` con el Row checkbox + `Text.rich` legal (literal actual,
comentario de links decorativos incluido).

**`register_actions.dart` — `RegisterActions`:** `BlocBuilder`
(`buildWhen` status/isValid) → inProgress ? spinner : Column[
`QuesivoPrimaryButton(l10n.createAccountButton, onPressed: isValid ? submit+unfocus : null)`,
SizedBox(28), `AuthDivider(l10n.registerDivider)`, SizedBox(22),
`GoogleAuthButton(l10n.continueWithGoogle, onPressed: loginWithGoogle)`,
SizedBox(26), `AuthPrompt(alreadyHaveAccount, signInLink, → push(loginRoute))`,
SizedBox(20)].

## 3. `register_screen.dart` (reducido)

Queda (~90 líneas): imports, doc comment, `RegisterScreen` (cubit por
constructor, `BlocProvider`) y `_RegisterView` con solo:

```dart
return Scaffold(
  backgroundColor: AppColors.quesivoWhite,
  body: QuesivoBackdrop(
    topCircleFraction: 0.68,
    bottomCircleFraction: 0,
    child: MultiBlocListener(
      listeners: [ /* AuthCubit + RegisterCubit — sin cambios */ ],
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              QuesivoBrandHeader(logoFraction: 0.65),
              AuthHeading(
                title: l10n.registerTitle,
                description: l10n.registerDescription,
              ),
              const RegisterFormFields(),
              const SizedBox(height: 16),
              const RegisterTermsCheckbox(),
              const SizedBox(height: 24),
              const RegisterActions(),
            ],
          ),
        ),
      ),
    ),
  ),
);
```

(Los listeners quedan en la screen — son wiring, no elemento visual.)

## 4. Reglas del refactor

- **Literal**: el código movido no cambia ni un píxel — mismos estilos,
  espaciados, `buildWhen`, errorText y comentarios explicativos (moverlos con
  el código).
- Widgets nuevos con doc comment de intención (patrón de la casa).
- `const` en constructores; params mínimos.
- No tocar cubits/state/VOs — solo presentation.

## 5. Verificación

- `flutter analyze` — 0 issues.
- `flutter test` — 77/77.
- Manual: abrir `/register` y comparar píxel a píxel con la versión anterior.
