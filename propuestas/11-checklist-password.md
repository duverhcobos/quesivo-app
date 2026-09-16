# Propuesta: Checklist de requisitos de contraseña en `/register`

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 65/65 (61 + 4 nuevos del VO). Revisor: APROBADO sin hallazgos. Post-implementación: se quitó el `errorText` genérico del campo contraseña (y la clave `weakPasswordError` de los `.arb`) — el checklist ya comunica cada requisito y el mensaje duplicado se veía doble.

Bajo el campo "Contraseña" de la pantalla de registro se lista en vertical el
requisito de la contraseña y cada ítem se tilda en vivo mientras el usuario
escribe (✓ verde al cumplirse). Hoy la regla solo se descubre por el `errorText`
genérico "Mínimo 8 caracteres, con mayúscula, minúscula y número".

## Decisiones

- **Fuente de verdad única**: los checks viven como predicados estáticos en el
  VO `RegisterPassword` (la regla de negocio no se duplica en la UI — SRP).
- **Siempre visible** (no solo al enfocar el campo): son "indicaciones" — el
  usuario las ve antes de escribir.
- Ubicación: **entre el campo Contraseña y Confirmar contraseña** — es donde el
  usuario está escribiendo.
- Ítem cumplido → `check_circle` + texto `quesivoSuccess`; pendiente →
  `circle_outlined` + texto `quesivoPlaceholder`. Fuente 14px (como términos).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/value_objects/register_password.dart` | Exponer predicados estáticos `hasMinLength`/`hasLowercase`/`hasUppercase`/`hasDigit` (el validator los reutiliza — no se duplica la regla) |
| `lib/features/auth/presentation/widgets/password_requirements_checklist.dart` | **Nuevo** — lista vertical de 4 requisitos con check vivo |
| `lib/features/auth/presentation/screens/register_screen.dart` | `BlocBuilder` sobre `password` que renderiza el checklist entre el campo password y el de confirmación |
| `lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` | 5 claves nuevas + `flutter gen-l10n` |
| `../Design/quesivo-design-system.yaml` | `register_form` documenta `password_requirements` + changelog |
| `test/features/auth/domain/value_objects/register_password_test.dart` | **Nuevo** — test de los predicados/validator |

---

## 1. `register_password.dart` (actualización)

**Ruta:** `lib/features/auth/domain/value_objects/register_password.dart`

```dart
class RegisterPassword extends FormzInput<String, RegisterPasswordValidationError> {
  const RegisterPassword.pure() : super.pure('');
  const RegisterPassword.dirty([super.value = '']) : super.dirty();

  static final _hasLower = RegExp(r'[a-z]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasDigit = RegExp(r'\d');

  /// Predicados de la política — única fuente de verdad compartida por el
  /// validator y por el checklist visual de la pantalla.
  static bool hasMinLength(String v) => v.length >= 8;
  static bool hasLowercase(String v) => _hasLower.hasMatch(v);
  static bool hasUppercase(String v) => _hasUpper.hasMatch(v);
  static bool hasDigit(String v) => _hasDigit.hasMatch(v);

  @override
  RegisterPasswordValidationError? validator(String value) {
    if (value.isEmpty) return RegisterPasswordValidationError.empty;
    final strong = hasMinLength(value) &&
        hasLowercase(value) &&
        hasUppercase(value) &&
        hasDigit(value);
    return strong ? null : RegisterPasswordValidationError.weak;
  }
}
```

(Sin cambios de comportamiento — el validator queda idéntico, solo reusa los
predicados.)

## 2. `password_requirements_checklist.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/widgets/password_requirements_checklist.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/value_objects/register_password.dart';

/// Checklist vivo de los requisitos de `RegisterPassword` (§register_form).
///
/// SOLID (SRP): solo pinta filas check/pendiente — la regla de qué cuenta
/// como "cumplido" vive en el Value Object (única fuente de verdad).
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    super.key,
    required this.password,
    required this.title,
    required this.minLengthLabel,
    required this.uppercaseLabel,
    required this.lowercaseLabel,
    required this.digitLabel,
  });

  final String password;
  final String title;
  final String minLengthLabel;
  final String uppercaseLabel;
  final String lowercaseLabel;
  final String digitLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.quesivoDarkText,
          ),
        ),
        const SizedBox(height: 8),
        _RequirementRow(
          met: RegisterPassword.hasMinLength(password),
          label: minLengthLabel,
        ),
        const SizedBox(height: 6),
        _RequirementRow(
          met: RegisterPassword.hasUppercase(password),
          label: uppercaseLabel,
        ),
        const SizedBox(height: 6),
        _RequirementRow(
          met: RegisterPassword.hasLowercase(password),
          label: lowercaseLabel,
        ),
        const SizedBox(height: 6),
        _RequirementRow(
          met: RegisterPassword.hasDigit(password),
          label: digitLabel,
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color =
        met ? AppColors.quesivoSuccess : AppColors.quesivoPlaceholder;
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }
}
```

## 3. `register_screen.dart` (actualización)

Importar el widget nuevo y `RegisterPassword` (para el buildWhen — no hace
falta, el cubit ya lo tiene en state):

**Después del `BlocBuilder` del campo password, antes del de confirmación:**

```dart
                  // --- Requisitos de contraseña (checklist vivo) ---
                  BlocBuilder<RegisterCubit, RegisterState>(
                    buildWhen: (p, c) =>
                        p.password.value != c.password.value,
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
```

(Mantener el `SizedBox(height: 16)` existente entre password y confirmación —
el checklist queda dentro de ese gap: `SizedBox(16)` → checklist → `SizedBox(16)`.)

## 4. Diccionarios i18n

**`app_es.arb`:**
```json
  "passwordReqTitle": "La contraseña debe tener:",
  "passwordReqMinLength": "Mínimo 8 caracteres",
  "passwordReqUppercase": "Una letra mayúscula",
  "passwordReqLowercase": "Una letra minúscula",
  "passwordReqDigit": "Un número"
```

**`app_en.arb`:**
```json
  "passwordReqTitle": "Password must have:",
  "passwordReqMinLength": "At least 8 characters",
  "passwordReqUppercase": "One uppercase letter",
  "passwordReqLowercase": "One lowercase letter",
  "passwordReqDigit": "One number"
```

**`app_pt.arb`:**
```json
  "passwordReqTitle": "A senha deve ter:",
  "passwordReqMinLength": "Mínimo de 8 caracteres",
  "passwordReqUppercase": "Uma letra maiúscula",
  "passwordReqLowercase": "Uma letra minúscula",
  "passwordReqDigit": "Um número"
```

Después ejecutar **`flutter gen-l10n`**.

## 5. `quesivo-design-system.yaml` (spec)

En `register.register_form`, después del campo `password`, documentar el
elemento nuevo (espejo del patrón de spec existente):

```yaml
          password_requirements:
            type: "live_checklist"
            position: "between_password_and_confirm_password"
            title:
              content: "La contraseña debe tener:"
              typography:
                weight: "500"
                size: "14px"
                color: "#172033"
            items:
              - id: "min_length"
                content: "Mínimo 8 caracteres"
              - id: "uppercase"
                content: "Una letra mayúscula"
              - id: "lowercase"
                content: "Una letra minúscula"
              - id: "digit"
                content: "Un número"
            item_state:
              pending:
                icon: "circle_outlined"
                icon_size: "18px"
                color: "#7A8499"
              met:
                icon: "check_circle"
                icon_size: "18px"
                color: "#2E9B62"
            item_typography:
              size: "14px"
```

Y en el `changelog` agregar al `v1.0.3` (o crear `v1.0.4` si ya existe) la línea:
`"register_form gana password_requirements: checklist vivo que tilda cada requisito mientras el usuario escribe (los predicados viven en el VO RegisterPassword)."`.

## 6. `register_password_test.dart` (archivo nuevo)

**Ruta:** `test/features/auth/domain/value_objects/register_password_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quesivo/features/auth/domain/value_objects/register_password.dart';

void main() {
  group('RegisterPassword', () {
    test('rechaza vacío con empty', () {
      const input = RegisterPassword.dirty('');
      expect(input.displayError, RegisterPasswordValidationError.empty);
    });

    test('rechaza password débil con weak', () {
      const input = RegisterPassword.dirty('queso');
      expect(input.displayError, RegisterPasswordValidationError.weak);
    });

    test('acepta password fuerte', () {
      const input = RegisterPassword.dirty('Queso123');
      expect(input.displayError, isNull);
      expect(input.isValid, isTrue);
    });

    test('predicados evalúan cada requisito por separado', () {
      expect(RegisterPassword.hasMinLength('Queso123'), isTrue);
      expect(RegisterPassword.hasMinLength('Que1'), isFalse);
      expect(RegisterPassword.hasUppercase('Queso123'), isTrue);
      expect(RegisterPassword.hasUppercase('queso123'), isFalse);
      expect(RegisterPassword.hasLowercase('Queso123'), isTrue);
      expect(RegisterPassword.hasLowercase('QUESO123'), isFalse);
      expect(RegisterPassword.hasDigit('Queso123'), isTrue);
      expect(RegisterPassword.hasDigit('Quesosito'), isFalse);
    });
  });
}
```

## 7. Verificación

- `flutter analyze` — 0 issues.
- `flutter test` — los 61 existentes + los nuevos del VO.
- Manual: escribir la contraseña letra a letra y ver cada ítem tildarse.
