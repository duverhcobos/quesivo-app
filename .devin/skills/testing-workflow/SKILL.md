---
name: testing-workflow
description: Convenciones y comandos para escribir y correr tests en Quesivo
allowed-tools:
  - read
  - grep
  - glob
  - edit
  - exec
triggers:
  - user
  - model
---

Convenciones de testing para **Quesivo** (Flutter + `flutter_test` + `bloc_test` +
`mocktail`).

## Estructura

- Tests unitarios/bloc en `test/`, replicando exactamente la estructura de
  `lib/features/<feature>/...` (ej. `lib/core/routes/auth_guard.dart` →
  `test/core/routes/auth_guard_test.dart`).
- Usar `mocktail` para mocks de interfaces (repos, datasources, use cases, `ILoggerService`) y
  `bloc_test` para Cubits.
- No se usa emulador para tests: todo se prueba con dependencias falseadas (mocks) inyectadas
  manualmente, sin pasar por `get_it` en los tests — salvo que la clase bajo prueba dependa
  explícitamente del Service Locator (en ese caso, registrar/desregistrar el mock en
  `setUp`/`tearDown` de forma aislada).
- Al agregar un Use Case, Cubit, Repository o clase de seguridad (ej. guards de rutas) nuevo,
  añadir su test correspondiente. Prioridad de cobertura: primero las piezas de seguridad
  (`AuthGuard`, interceptores de auth), luego repositorios, luego cubits, luego use cases simples.

## Patrones de mock recomendados

- Repositorios/datasources/servicios: `class MockX extends Mock implements IX {}` + `when(...)`.
- Para dependencias con parámetros nombrados opcionales (ej. `logger.error(msg, error:, stackTrace:)`),
  registrar fallback con `registerFallbackValue(StackTrace.empty)` en `setUpAll` si se usa `any()`
  para esos named args.
- Para Cubits: usar `blocTest<CubitType, StateType>(..., seed: () => estadoDistintoDelInicial, act:
  ..., expect: () => [...])`. Si el estado inicial del Cubit es igual al primer estado que se
  quiere verificar en la secuencia, usar `seed` con un estado distinto para no perder la primera
  emisión.
- Para clases con dependencias que antes se resolvían vía Service Locator (patrón legado): si es
  posible, preferir inyección por constructor al escribir código nuevo — hace el test trivial sin
  tocar `locator`.

## Comandos

```bash
# Regenerar clases de i18n (obligatorio tras tocar cualquier .arb, antes de correr tests que las usen)
flutter gen-l10n

# Analizar/lint
flutter analyze

# Tests
flutter test
```

No hay pipeline de CI documentado en el repo; correr `flutter analyze` y `flutter test`
localmente antes de dar por terminado un cambio.
