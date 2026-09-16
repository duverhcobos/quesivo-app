# Propuesta: Rebrand `tercer_tiempo` → `quesivo`

**Estado: aplicada** — ver verificación al pie.

Rebrand completo del proyecto Flutter: el código fue heredado del proyecto "Tercer Tiempo" pero el producto real es **Quesivo**, la app móvil del SaaS multi-tenant para queseras (decisión de plataforma en `../planeaciones/003-decision-plataforma-frontend-movil.md`). Se renombra el package Dart, los identificadores nativos y las referencias de marca en docs/skills.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | `name: tercer_tiempo` → `name: quesivo`; descripción del producto real |
| 8 archivos en `lib/` | imports `package:tercer_tiempo/...` → `package:quesivo/...` |
| 5 archivos en `test/` | imports `package:tercer_tiempo/...` → `package:quesivo/...` |
| `lib/core/theme/app_colors.dart` | comentarios "Tercer Tiempo" → "Quesivo" |
| `android/app/build.gradle.kts` | `namespace`/`applicationId` → `com.example.quesivo` |
| `android/app/src/main/kotlin/com/example/tercer_tiempo/MainActivity.kt` | mover a `com/example/quesivo/` + `package com.example.quesivo` |
| `ios/Runner/Info.plist` | `CFBundleName` → `quesivo`, `CFBundleDisplayName` → `Quesivo` (era "Prueba Solid") |
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` `com.example.pruebaSolid` → `com.example.quesivo` |
| `web/index.html` | `<title>` y `apple-mobile-web-app-title` → `Quesivo` |
| `web/manifest.json` | `name`/`short_name` → `Quesivo` |
| `windows/`, `linux/`, `macos/` | binary names, titles y bundle ids → `quesivo`/`com.example.quesivo` |
| `I18N_GUIDE.md` | import de ejemplo → `package:quesivo/...` |
| `.devin/skills/*/SKILL.md` (10) | "Tercer Tiempo" → "Quesivo"; `frontend-design` reescrito contra `../Design/quesivo-design-system.yaml`; `token-saving-tools-policy` corrige el nombre del proyecto en codebase-memory |

**No se toca:** `propuestas/01-07` (historial de cambios aplicados bajo el nombre viejo), archivos generados (`ios/Flutter/ephemeral/`, `macos/Flutter/ephemeral/` — se regeneran con `flutter clean && flutter pub get`), `build/`, `.dart_tool/`, `.idea/`.

**Fuera de alcance (separar en otra propuesta si se quiere):**
- Bundle id "real" de producción (`com.example.*` es placeholder; definir dominio propio antes de publicar).
- Paleta 3TIEMPO residual en `app_colors.dart` (los tokens Quesivo ya conviven ahí; la limpieza de tokens viejos es un cambio de diseño, no de nombre).
- Eliminar scaffolds desktop (`windows/`, `linux/`, `macos/`) si se confirma que el target es solo móvil.

---

## Detalle de cambios mecánicos

### Package Dart

**Antes:** `import 'package:tercer_tiempo/...';`
**Después:** `import 'package:quesivo/...';`

Archivos afectados (13): `lib/main.dart`, `lib/features/welcome/presentation/screens/welcome_screen.dart`, `lib/features/onboarding/presentation/screens/onboarding_screen.dart`, `lib/features/home/presentation/screens/home_screen.dart`, `lib/features/auth/presentation/screens/login_screen.dart`, `lib/features/auth/presentation/screens/login_screen.dart`, `lib/features/auth/presentation/screens/forgot_password_screen.dart`, `lib/core/network/implementations/dio_network_service_impl.dart`, `lib/core/network/implementations/http_network_service_impl.dart`, `test/core/routes/auth_guard_test.dart`, `test/features/auth/presentation/cubit/auth_cubit_test.dart`, `test/features/auth/presentation/cubit/login_cubit_test.dart`, `test/features/auth/data/repositories/auth_repository_impl_test.dart`, `test/features/auth/domain/use_cases/login_use_case_test.dart`.

### Android

`android/app/build.gradle.kts`:
- **Antes:** `namespace = "com.example.tercer_tiempo"` / `applicationId = "com.example.tercer_tiempo"`
- **Después:** `namespace = "com.example.quesivo"` / `applicationId = "com.example.quesivo"`

`MainActivity.kt` se mueve de `android/app/src/main/kotlin/com/example/tercer_tiempo/` a `android/app/src/main/kotlin/com/example/quesivo/` con `package com.example.quesivo`. `AndroidManifest.xml` ya tiene `android:label="QUESIVO"`.

### iOS / macOS

- `Info.plist`: `CFBundleName` `tercer_tiempo` → `quesivo`; `CFBundleDisplayName` `Prueba Solid` → `Quesivo`.
- `project.pbxproj` (ios y macos) y `AppInfo.xcconfig`: `com.example.pruebaSolid` → `com.example.quesivo`; `tercer_tiempo.app` → `Quesivo.app` en referencias de producto y `TEST_HOST`.
- Los `ephemeral/*` (`flutter_export_environment.sh`, `Generated.xcconfig`, `flutter_native_integration.env`) tienen paths viejos del repo origen (`DHC30\tercer-tiempo-app`) — se regeneran solos con `flutter clean && flutter pub get`, no se editan a mano.

### Web / desktop

`web/index.html`, `web/manifest.json`, `windows/CMakeLists.txt`, `windows/runner/main.cpp`, `windows/runner/Runner.rc`, `linux/CMakeLists.txt`, `linux/runner/my_application.cc`, `macos/Runner.xcscheme`: nombre visible y binario → `Quesivo`/`quesivo`.

---

## Orden de aplicación

1. `pubspec.yaml` (name) → imports `lib/` → imports `test/`.
2. Nativos: android (gradle + mover MainActivity) → ios → macos → web → windows → linux.
3. Docs/skills.
4. `flutter clean && flutter pub get` → `flutter analyze` → `flutter test`.

---

## Verificación

Completada al aplicar: `flutter pub get` OK, `flutter analyze` sin issues, `flutter test` 43/43, sin referencias `tercer_tiempo`/`Tercer Tiempo`/`pruebaSolid` en `lib/`, `test/` ni configs de plataforma (quedan solo los `ephemeral/` de ios/macos, que se regeneran con `flutter clean`).
