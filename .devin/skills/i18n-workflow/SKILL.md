---
name: i18n-workflow
description: Flujo obligatorio para agregar o modificar textos visibles al usuario en Quesivo
triggers:
  - user
  - model
---

Flujo de internacionalización para **Quesivo** (`I18N_GUIDE.md`).

- Prohibido texto estático quemado en widgets (`Text('Login')`). Todo texto va por
  `AppLocalizations`.
- Prohibido también hardcodear colores en las mismas pantallas que tienen el texto (usar
  `Theme.of(context).colorScheme` o `AppColors`, no `Colors.blue`/`Colors.red` directos).

## Pasos obligatorios al agregar un texto nuevo

1. Añadir la misma clave (camelCase) en **los tres** diccionarios: `lib/l10n/app_es.arb`,
   `app_en.arb`, `app_pt.arb`. Si el texto tiene placeholders (ej. un nombre de usuario), agregar
   también el bloque `@claveDelTexto` con `placeholders` en los tres archivos.
2. Ejecutar `flutter gen-l10n` para regenerar las clases.
3. Consumir con `AppLocalizations.of(context)!.miClave` (import
   `package:quesivo/l10n/app_localizations.dart`).

No editar manualmente los archivos generados `lib/l10n/app_localizations*.dart` (se regeneran).
Cuando se proponga un cambio que toque i18n, la propuesta debe indicar "ejecutar
`flutter gen-l10n`" en vez de escribir esos archivos generados a mano.

Cambios de idioma en runtime se hacen vía `LocaleCubit`
(`context.read<LocaleCubit>().changeLocale(...)` o `.toggleLanguage()`), nunca manipulando
`Locale` directamente en la UI.

## Checklist antes de dar por terminado un cambio con texto visible

- [ ] Clave agregada en `app_es.arb`, `app_en.arb` y `app_pt.arb`.
- [ ] `flutter gen-l10n` ejecutado sin errores.
- [ ] Ningún `Text('...')` literal quedó sin pasar por `AppLocalizations`.
- [ ] Ningún color quedó hardcodeado en la misma pantalla tocada.
