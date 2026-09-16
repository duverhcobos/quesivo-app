---
name: environments-secrets
description: Manejo de entornos (dev/stg/prod), variables --dart-define y secretos en Quesivo
triggers:
  - user
  - model
---

Reglas para manejar entornos y secretos en **Quesivo**, un proyecto camino a producción.

## Entornos (`ENVIRONMENTS.md`)

- **Nunca hardcodear URLs, tokens o API keys** en el código fuente.
- Toda variable de entorno se define exclusivamente vía `--dart-define` y se centraliza en
  `lib/core/constants/environment/environment.dart` (`Environment`). Ningún otro archivo debe leer
  variables de entorno directamente.
- Para agregar una nueva variable secreta: editar `environment.dart` usando
  `String.fromEnvironment`.
- Ejecución local:
  ```bash
  flutter run --dart-define=ENV=dev --dart-define=API_TOKEN=<token>
  ```
  Entornos válidos: `dev`, `stg`, `prod`.
- VS Code tiene 3 configuraciones preconfiguradas en `.vscode/launch.json` (Solid DEV/STG/PROD).
  Preferir usarlas en vez de comandos manuales cuando se trabaje desde el IDE.
- Nunca usar archivos `.env` de texto plano para secretos de producción; el mecanismo del proyecto
  es `--dart-define`.

## Reglas de seguridad reforzadas (proyecto camino a producción)

- **Cero endpoints/datos de prueba fuera de `dev`:** `dummyjson.com` u otros mocks públicos solo
  pueden usarse cuando `Environment.currentEnvironment == EnvType.dev`. Los entornos `stg` y `prod`
  deben apuntar siempre a infraestructura real de Quesivo; nunca dejar un `TODO`/URL
  placeholder sin avisar explícitamente al usuario. Cualquier lógica "truco" específica de una API
  de pruebas (ej. transformar email en username) debe estar gateada por entorno, nunca ejecutarse
  incondicionalmente.
- **Manejo de secretos reforzado:** nunca imprimir, loguear ni comitear tokens, API keys o
  credenciales reales — ni siquiera en ejemplos dentro de `.md` o `launch.json`, ni en logs de
  debug. Si se necesita confirmar que un token fue inyectado, loguear solo si está presente/vacío,
  nunca el valor. Si se encuentra un secreto real en el repo, avisar al usuario en vez de
  simplemente borrarlo o versionarlo.
- **TLS/certificados:** cualquier bypass de validación de certificados (ej. certificados
  autofirmados en desarrollo local) debe:
  1. Estar condicionado explícitamente a `Environment.currentEnvironment == EnvType.dev` (nunca
     activo en `stg`/`prod`).
  2. Usar matching exacto de IP/host (regex de octetos completos), nunca `String.contains(...)`
     por substring, para evitar bypasses accidentales en hosts que contengan esos caracteres.
- **Cambios en flujos de sesión/token:** cambios en `AuthGuard`, `AuthInterceptor`,
  `RefreshTokenInterceptor`, `SecureLocalAuthDataSourceImpl` o cualquier cosa relacionada con
  sesión/tokens deben explicarse claramente al usuario antes o al momento de aplicarlos, dado su
  impacto en seguridad.
- **Sin atajos "provisionales" silenciosos:** si por falta de información hay que dejar un valor o
  contrato temporal (URL, key, texto, forma de un endpoint todavía no confirmado por backend),
  declararlo explícitamente en la respuesta al usuario y marcarlo en el código con un comentario
  visible (ej. `// PROVISIONAL: ...`); no dejarlo implícito como si fuera definitivo.
- **Almacenamiento local seguro:** al usar `flutter_secure_storage`, evitar `deleteAll()` salvo que
  sea intencional; borrar solo las claves relevantes a la operación (ej. logout borra solo claves
  de auth, no todo el storage compartido con otras features).
