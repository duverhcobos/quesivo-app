# Propuesta 47 — Sanitización y validación en vivo de los inputs del módulo usuarios

**Estado:** Propuesta — pendiente de implementación
**Fecha:** 2026-06-30
**Feature:** `users` (sheets `NewUserSheet` + `ResetPasswordSheet`) · `core/widgets`

## Problema

Los campos del sheet de creación aceptan **cualquier carácter** y solo
validan al hacer submit:

- "Nombre completo" admite dígitos y símbolos (`Juan123!!!` pasa).
- El email admite espacios y caracteres que el formato jamás acepta.
- La contraseña admite símbolos aunque el requisito solo pide
  mayúscula + minúscula + dígito (el admin inventa la temporal — los
  caracteres permitidos deben ser exactamente los del requisito).
- No hay aviso mientras se escribe: el error solo aparece tras tap en
  "Crear usuario".

## Diseño

Dos capas de feedback, ambas inmediatas:

1. **Bloqueo a nivel tecla** — `FilteringTextInputFormatter.allow(...)`
   impide que el carácter inválido siquiera entre al campo. La regex de
   caracteres permitidos la expone el VO de dominio (single source —
   la UI no duplica la regla).
2. **Validación en vivo** — `errorText` se computa en `onChanged`:
   cuando el campo tiene contenido e inválido, el error se muestra sin
   esperar el submit. Campo vacío sigue mostrando el error de
   "requerido" únicamente al submit (no se penaliza un campo que aún
   no se tocó).

### Reglas por campo

| Campo | Charset permitido (formatter) | Error en vivo |
|---|---|---|
| Nombre | letras (con tildes/ñ/ü), espacio, `'` y `-` | formato inválido (separador al inicio, doble separador, etc.) |
| Email | `a-z A-Z 0-9 @ . _ % + -` — sin espacios | formato inválido mientras no cumpla `algo@algo.algo` |
| Contraseña | `a-z A-Z 0-9` — **solo lo que pide el requisito** | el checklist vivo ya es el aviso; `errorText` queda para submit |

`MemberName` gana patrón estricto:
`^[letters]+(?:[ '\-][letters]+)*$` — obliga letra al inicio/fin y
separadores simples entre palabras (rechaza `-Juan`, `Juan  Perez`,
`Juan'`).

`TempPassword` gana `allowedChars` (`a-zA-Z0-9`) — el formatter bloquea
símbolos y espacios a nivel tecla. La política del VO no cambia:
alfanumérico es subconjunto compatible con el backend.

`MemberEmail` gana `allowedChars` (charset de email) — la regex de
validación no cambia.

`ResetPasswordSheet` recibe el mismo formatter de contraseña (misma
política de temporal).

## Cambios por archivo

### `lib/core/widgets/quesivo_text_field.dart`

Nuevo parámetro `inputFormatters` pasado al `TextFormField`:

```dart
import 'package:flutter/services.dart';  // TextInputFormatter

const QuesivoTextField({
  ...
  this.inputFormatters,
});

/// Formatters de tecla — el sheet de creación los usa para bloquear
/// caracteres que el campo jamás acepta (dígitos en nombre, espacios
/// en email, símbolos en contraseña temporal).
final List<TextInputFormatter>? inputFormatters;
```

En el `TextFormField`: `inputFormatters: widget.inputFormatters,`

### `lib/features/users/domain/value_objects/member_name.dart` (reescrito)

```dart
import 'package:formz/formz.dart';

enum MemberNameValidationError { empty, invalidFormat }

/// VO del nombre del miembro — letras (con tildes/ñ/ü), espacios,
/// apóstrofes y guiones; separadores simples internos. El backend pide
/// non-empty ≤255 (doc 007); el formato es regla de producto: el campo
/// es "nombre completo", no texto libre.
class MemberName extends FormzInput<String, MemberNameValidationError> {
  /// Caracteres que el teclado puede ingresar — el widget arma el
  /// `FilteringTextInputFormatter` con esta regex (single source).
  static final allowedChars = RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'\- ]");

  static final _pattern = RegExp(
    r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]+(?:[ '\-][a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]+)*$",
  );

  const MemberName.pure() : super.pure('');
  const MemberName.dirty([super.value = '']) : super.dirty();

  @override
  MemberNameValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return MemberNameValidationError.empty;
    return _pattern.hasMatch(trimmed)
        ? null
        : MemberNameValidationError.invalidFormat;
  }
}
```

### `lib/features/users/domain/value_objects/member_email.dart`

Agregar junto a `_emailRegex`:

```dart
/// Charset de email — bloquea espacios y símbolos ajenos al formato.
static final allowedChars = RegExp(r'[a-zA-Z0-9@._%+\-]');
```

### `lib/features/users/domain/value_objects/temp_password.dart`

Agregar junto a los predicados:

```dart
/// Charset permitido — solo lo que el requisito pide (letras y
/// dígitos); símbolos y espacios se bloquean a nivel tecla.
static final allowedChars = RegExp(r'[a-zA-Z0-9]');
```

### `lib/features/users/presentation/widgets/new_user_sheet.dart`

Imports: `package:flutter/services.dart` (FilteringTextInputFormatter).

Estado — `_nameError` se divide para distinguir el error de submit
(vacío) del error en vivo (formato):

```dart
bool _nameError = false;        // vacío al submit → "Ingresá el nombre completo"
bool _nameFormatError = false;  // live: separadores mal ubicados
bool _emailError = false;       // submit: vacío · live: formato inválido
```

Campo nombre:

```dart
QuesivoTextField(
  hintText: l10n.fullNamePlaceholder,
  prefixIcon: Icons.person_outline,
  enabled: !isBusy,
  inputFormatters: [
    FilteringTextInputFormatter.allow(MemberName.allowedChars),
  ],
  errorText: _nameError
      ? l10n.invalidMemberNameError
      : _nameFormatError
          ? l10n.memberNameFormatError
          : null,
  onChanged: (v) {
    context.read<CreateUserCubit>().resetStatus();
    setState(() {
      _name = v;
      _nameError = false;
      // Aviso en vivo — solo si hay contenido e inválido.
      _nameFormatError =
          v.isNotEmpty && MemberName.dirty(v).isNotValid;
    });
  },
),
```

Campo email (mismo patrón; `_emailError` cubre ambos casos porque el
mensaje `invalidEmailError` aplica igual):

```dart
onChanged: (v) {
  context.read<CreateUserCubit>().resetStatus();
  setState(() {
    _email = v;
    _emailError = v.isNotEmpty && MemberEmail.dirty(v).isNotValid;
  });
},
```

Campo contraseña:

```dart
inputFormatters: [
  FilteringTextInputFormatter.allow(TempPassword.allowedChars),
],
```

Su `errorText`/checklist no cambian — el formatter ya bloquea lo
imposible y el checklist es el aviso en vivo.

En `_submit`, `_nameError` pasa a cubrir vacío **o** formato inválido:

```dart
final nameInvalid =
    _name.trim().isEmpty || MemberName.dirty(_name).isNotValid;
setState(() {
  _nameError = _name.trim().isEmpty;
  _nameFormatError = !_nameError && nameInvalid;
  ...
});
```

### `lib/features/users/presentation/widgets/reset_password_sheet.dart`

Mismo formatter en su `QuesivoTextField` de contraseña:

```dart
inputFormatters: [
  FilteringTextInputFormatter.allow(TempPassword.allowedChars),
],
```
(import `flutter/services.dart` + `temp_password.dart`).

### `lib/l10n/app_{es,en,pt}.arb`

Nueva key:

```json
"memberNameFormatError": "Usa solo letras, espacios, guiones y apóstrofes"
```
```json
"memberNameFormatError": "Use only letters, spaces, hyphens and apostrophes"
```
```json
"memberNameFormatError": "Use apenas letras, espaços, hífens e apóstrofos"
```

Regenerar con `flutter pub get` (l10n.yaml + generate:true).

### `Design/quesivo-design-system.yaml`

`create_user_sheet` → nueva subsección `input_sanitization` + bump
`1.10.7` + changelog.

### Tests

`new_user_sheet_test.dart` — nuevos casos:
- name formatter: `enterText('Juan123!!')` → el campo queda `Juan`.
- email formatter: `enterText('a b@c')` → queda `ab@c` (espacio bloqueado).
- password formatter: `enterText('Abc1!@#x')` → queda `Abc1x`.
- live: `enterText` email sin `@` → error visible sin submit; name
  `'-Juan'` → `memberNameFormatError` visible sin submit.

`create_user_cubit_test.dart` / VO specs — si existe spec de
`MemberName`, agregar casos del patrón (tildes válidas, dígito
rechazado, doble espacio rechazado, separador inicial rechazado).
Si no existe spec dedicado, los casos cubren el widget test.

## Alcance extendido (feedback de validación visual)

Tras validar la primera parte en el device, el usuario pidió aplicar el
mismo criterio a **todos** los inputs de la app. Los forms de auth ya
validan en vivo (Formz `displayError` marca dirty en `onChanged`), así
que el delta es el **formatter de charset** en cada campo, más endurecer
`FullName` con el patrón de nombre.

### Campos adicionales

| Archivo | Campo | Formatter |
|---|---|---|
| `features/users/presentation/widgets/users_search_field.dart` | buscador | `RegExp(r"[a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ@._%+\-' ]")` — unión nombre+email (todo lo buscable); regex local del widget, es filtro de UI, no regla de dominio |
| `features/auth/presentation/widgets/register_form_fields.dart` | organización | `OrganizationName.allowedChars` = `[a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ '&.,\-]` (razón social admite dígitos) |
| 〃 | nombre completo | `FullName.allowedChars` = mismo charset que `MemberName` |
| 〃 | email | `Email.allowedChars` = mismo que `MemberEmail` |
| 〃 | password + confirmar | `RegisterPassword.allowedChars` = `a-zA-Z0-9` |
| `features/auth/presentation/widgets/login_form_fields.dart` | email | `Email.allowedChars` |
| 〃 | password | `Password.allowedChars` = `a-zA-Z0-9` (feedback en validación — todas las contraseñas nacen alfanuméricas, el login bloquea igual) |
| `features/auth/presentation/widgets/forgot_password_form.dart` | email | `Email.allowedChars` |
| `features/auth/presentation/widgets/reset_password_form_fields.dart` | password + confirmar | `RegisterPassword.allowedChars` |

**Login password también recibe formatter** (feedback del usuario en
validación visual): el diseño original lo dejaba libre por ser
credencial existente, pero todas las vías de creación ya son
alfanuméricas (register/temp/reset), así que bloquear símbolos en el
login es consistente — `Password` VO gana `allowedChars`.

### VOs de auth

- `email.dart`: `static final allowedChars = RegExp(r'[a-zA-Z0-9@._%+\-]');`
- `full_name.dart`: `allowedChars` (mismo charset que `MemberName`) +
  nuevo error `invalidFormat` con el mismo patrón estricto
  `^[letras]+(?:[ '\-][letras]+)*$`. En `register_form_fields` el
  errorText distingue: `invalidFormat` → `l10n.memberNameFormatError`
  (key reutilizada), resto → `invalidFullNameError` actual.
- `organization_name.dart`: `allowedChars` (validator sin cambios —
  non-empty + min 3).
- `register_password.dart`: `static final allowedChars = RegExp(r'[a-zA-Z0-9]');`

### Tests adicionales

- `users_search_field` / screen test: símbolos/emojis no entran al campo.
- Register/login forms: un caso de formatter por widget (email bloquea
  espacio, fullName bloquea dígito, password bloquea símbolo).

`Design/quesivo-design-system.yaml` — la entrada `1.10.7` cubre el
alcance completo (agregar los campos de auth + buscador a
`input_sanitization`).

## Orden de implementación

1. VOs (`member_name` reescrito, `allowedChars` en email/password).
2. `QuesivoTextField.inputFormatters`.
3. `new_user_sheet.dart` (formatters + errores en vivo + submit).
4. `reset_password_sheet.dart` (formatter).
5. ARBs + `flutter pub get`.
6. Tests.
7. yaml bump.
8. `flutter analyze` + `flutter test`.
9. Alcance extendido: VOs de auth (`email`, `full_name`, `organization_name`, `register_password`) → formatters en `register_form_fields`, `login_form_fields`, `forgot_password_form`, `reset_password_form_fields` (auth), `users_search_field` → tests adicionales → actualizar yaml `1.10.7`.
