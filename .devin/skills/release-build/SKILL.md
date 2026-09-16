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
- [ ] **URLs de `urlAuth`/`urlProd`** apuntan a algo real — `prod` hoy es
  `api.tu-empresa.com` placeholder (responde 500 real); `dev` es DummyJSON.
- [ ] **Versiones sincronizadas**: `version:` de `pubspec.yaml` y
  `Environment.appVersion` (el pie del drawer la muestra) — Dart no lee el
  pubspec en runtime, hay que subir ambas a mano.
- [ ] **Minify/R8**: si se activa `minifyEnabled`/`shrinkResources`,
  verificar plugins sensibles (flutter_secure_storage puede necesitar
  reglas ProGuard).
- [ ] **`flutter analyze` + `flutter test` limpios** antes de buildear.

## Qué es mock en `dev` (no pegar a un servidor para probarlo)

- `register`, `forgotPassword`, `resetPassword`, `loginWithGoogle` →
  `Future.delayed` + modelo fake (gate `EnvType.dev` en
  `remote_auth_datasource_impl.dart`).
- `loginWithEmailPassword` **sí pega de verdad** a DummyJSON
  (`/auth/login`, convierte email→username antes del `@`; credenciales de
  prueba: `emilys` / `emilyspass`).
- En `stg`/`prod` TODO va a endpoints reales — no hay mocks.

Ojo: `networkInfo.isConnected` corre antes de cualquier llamada, incluso
de los mocks — sin internet el flujo falla igual con "No se pudo conectar".

## Comandos

```powershell
# Dev (mocks) — debug-signed release para probar en el device
flutter build apk --release

# Prod (cuando exista backend real)
flutter build apk --release --dart-define=ENV=prod

# Un APK por arquitectura (más livianos)
flutter build apk --release --split-per-abi

# Play Store: AAB firmado
flutter build appbundle --release --dart-define=ENV=prod
```

Salida: `build/app/outputs/flutter-apk/app-release.apk` (o
`bundle/release/app-release.aab`).

## Firma para distribución real

Cuando el build salga del equipo interno: crear keystore
(`keytool -genkey`), `key.properties` en `android/` (NUNCA commiteado —
está en .gitignore o agregarlo) y `signingConfigs.release` en
`app/build.gradle.kts`. Mientras tanto el release va firmado con la key de
debug — sirve para instalar pero no para Play Store.
