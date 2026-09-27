# Propuesta: Nombrado de quesera obligatorio — quitar "Por ahora no"

Decisión del usuario: el botón "Por ahora no" deja un hueco — limpia
`isNewSignup` permanentemente y hoy no existe UI posterior para renombrar
(el módulo `/home/organizacion` es placeholder). El nombrado pasa a ser
obligatorio en el signup por Google.

Corolario obligatorio: hoy `Guardar` queda deshabilitado cuando el campo
no cambia respecto al nombre generado (`_canSubmit` exige `!= original`).
Sin el skip eso era un deadlock: quien acepta el nombre generado no podía
seguir. `_canSubmit` pasa a exigir solo `nonEmpty` — un PATCH con el mismo
nombre es válido e idempotente (200 → flag limpio igual).

Se retira la cadena completa del skip (botón → cubit → use case → método
de repo → método del AuthCubit → registro DI → key l10n → tests). Código
muerto no se queda.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/organization/presentation/screens/org_name_setup_screen.dart` | quitar GestureDetector "Por ahora no" + `_canSubmit` solo `nonEmpty` + docs |
| `lib/features/organization/presentation/cubit/org_name_setup_cubit.dart` | quitar `skip()`, campo/param `_skipNameSetup`, import |
| `lib/features/organization/domain/use_cases/skip_org_name_setup_use_case.dart` | **eliminar archivo** |
| `lib/features/organization/domain/repositories/i_organization_repository.dart` | quitar `skipNameSetup` |
| `lib/features/organization/data/repositories/organization_repository_impl.dart` | quitar `skipNameSetup`; `_updateCachedSession` con `newName` requerido |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | quitar `skipOrgNameSetup()` + menciones en docs |
| `lib/core/di/setup_di.dart` | quitar factory `SkipOrgNameSetupUseCase` + arg del cubit |
| `lib/l10n/app_es.arb` / `app_en.arb` / `app_pt.arb` | quitar key `orgNameSetupSkip` → `flutter gen-l10n` |
| `test/features/organization/presentation/cubit/org_name_setup_cubit_test.dart` | quitar mock/tests de skip |
| `test/features/organization/presentation/screens/org_name_setup_screen_test.dart` | quitar tests del botón; ajustar el de "Guardar deshabilitado" |
| `test/features/organization/data/repositories/organization_repository_impl_test.dart` | quitar grupo `skipNameSetup` |
| `test/features/auth/presentation/cubit/auth_cubit_test.dart` | quitar tests de `skipOrgNameSetup` |

## Fragmentos clave

### `org_name_setup_screen.dart`

`_canSubmit` — antes exigía cambio respecto al original; ahora solo no-vacío
(el usuario puede confirmar el nombre generado, PATCH idempotente):

```dart
bool get _canSubmit => _name.trim().isNotEmpty;
```

El bloque de acciones queda solo con el botón primario (se elimina el
`SizedBox` + `Center` + `GestureDetector` del skip).

### `org_name_setup_cubit.dart`

Constructor queda con 3 dependencias (`UpdateOrganizationNameUseCase`,
`SelectOrganizationUseCase`, `AuthCubit`) y se elimina `skip()` completo.

### `organization_repository_impl.dart`

`_updateCachedSession` pasa a `Future<void> _updateCachedSession(String
newName)` — el caso `newName == null` (skip) ya no existe.

## Orden de aplicación

1. Screen + cubit (UI primero — es lo que el usuario ve).
2. Repo interface + impl + use case (borrado) + AuthCubit.
3. `setup_di.dart`.
4. `.arb` × 3 → `flutter gen-l10n`.
5. Tests × 4 archivos.
6. `flutter analyze` + `flutter test`.
