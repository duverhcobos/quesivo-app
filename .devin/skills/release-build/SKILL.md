---
name: release-build
description: Checklist para generar APK/AAB release de Quesivo — permisos, --dart-define por entorno, mocks de dev, firma y versionado
allowed-tools:
  - read
  - grep
  - glob
triggers:
  - user
  - model
---

Checklist antes de generar un build release de **Quesivo** (`flutter build
apk`/`appbundle`). Lo que en `flutter run` (debug) "funciona" puede romper
en release — el caso real: el manifest `main/` no tenía `INTERNET` y el APK
fallaba con "No se pudo conectar al servidor" (el permiso solo existía en
`debug/`/`profile/`).

## Checklist de build

- [ ] **`AndroidManifest.xml` main** tiene `uses-permission INTERNET` —
  los manifests `debug/` y `profile/` NO heredan a release; todo permiso
  que la app use debe estar también en `src/main/`.
- [ ] **`usesCleartextTraffic`** si el backend corre por `http://` (IP LAN
  de desarrollo) — Android bloquea cleartext por defecto en release.
- [ ] **Entorno elegido** vía `--dart-define=ENV=dev|stg|prod`
  (`lib/core/constants/environment/environment.dart`) — sin flag cae a
  `dev`. `API_TOKEN` idem si aplica.
- [ ] **`API_URL` inyectada** — `environment.dart` no tiene URLs de
  stg/prod hardcodeadas: `urlAuth` = `apiBaseUrl` (dart-define `API_URL`,
  default `http://10.0.2.2:3000` para emulador dev). Las URLs viven en
  `.vscode/launch.json` y `shorebird-stg.json`; sin `API_URL` un build
  stg/prod apunta al default del emulador y falla en device físico.
- [ ] **Versiones sincronizadas**: `version:` de `pubspec.yaml` y
  `Environment.appVersion` (el pie del drawer la muestra) — Dart no lee el
  pubspec en runtime, hay que subir ambas a mano.
- [ ] **Minify/R8**: si se activa `minifyEnabled`/`shrinkResources`,
  verificar plugins sensibles (flutter_secure_storage puede necesitar
  reglas ProGuard).
- [ ] **`flutter analyze` + `flutter test` limpios** antes de buildear.

## Qué es real vs. mock en `dev`

- Todos los endpoints de auth pegan al backend real (`API_URL`) en todo
  entorno — los mocks dev-only de `remote_auth_datasource_impl.dart` ya
  fueron retirados (login/register/verify/forgot/reset reales desde las
  propuestas backend 068/069; `loginWithGoogle` real desde la propuesta
  70 con `google_sign_in` + `POST /auth/google`).
- Google sign-in requiere `GOOGLE_SERVER_CLIENT_ID` (dart-define) con el
  Web OAuth client ID de Google Cloud — vacío = el botón falla con
  `GoogleAuthFailure` visible, no silencioso. Incluirlo en el
  `--dart-define-from-file` de release (`shorebird-stg.json`).

Ojo: `networkInfo.isConnected` corre antes de cualquier llamada, incluso
de los mocks — sin internet el flujo falla igual con "No se pudo conectar".

## Comandos

```powershell
# Dev (mocks) — release firmado con keystore real si existe key.properties
flutter build apk --release

# Stg (backend Render)
flutter build apk --release --dart-define=ENV=stg --dart-define=API_URL=https://quesivo-api.onrender.com

# Un APK por arquitectura (más livianos)
flutter build apk --release --split-per-abi

# Play Store: AAB firmado
flutter build appbundle --release --dart-define=ENV=prod
```

Salida: `build/app/outputs/flutter-apk/app-release.apk` (o
`bundle/release/app-release.aab`).

## Firma para distribución real (ya configurada)

Keystore real en `android/quesivo-release.jks` + `android/key.properties`
(ambos en `.gitignore`, NUNCA commitear). `app/build.gradle.kts` carga
`signingConfigs.release` desde `key.properties`; si el archivo no existe
(CI/dev sin secretos) cae a firma debug para no romper el build. La misma
key debe firmar toda release/patch futura — cambiarla invalida updates y
la publicación en Play Store.

## Shorebird (code push)

App registrada: `app_id` en `shorebird.yaml` (commiteado, no es secreto).
Release base `0.1.0+1` ya publicado con firma real y
`applicationId = com.quesivo.app`.

```powershell
# Release nuevo (cambios nativos, assets, plugins, version bump)
shorebird release android --dart-define-from-file=shorebird-stg.json

# Patch OTA (SOLO cambios Dart) sobre el release actual
shorebird patch android --dart-define-from-file=shorebird-stg.json

# Probar el release publicado en un device conectado
shorebird preview
```

- **Siempre** `--dart-define-from-file=shorebird-stg.json` (commiteado,
  mismas defines que `launch.json` stg) — el flag `--dart-define` del CLI
  parsea mal valores posicionales ("Target file X not found"), y un patch
  con defines distintos al release base cambia el backend al que apunta.
- Los patches solo llevan Dart: cambios en plugins nativos, manifests,
  permisos, `applicationId`, firma o assets nuevos requieren `release`
  nuevo, nunca `patch`.
- Salida AAB firmado: `build/app/outputs/bundle/release/app-release.aab`.
