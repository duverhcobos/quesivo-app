---
name: solid-clean-architecture
description: Reglas S.O.L.I.D. y de separación de capas obligatorias al escribir o revisar código en Quesivo
triggers:
  - user
  - model
---

Reglas de diseño obligatorias para **Quesivo**. Aplican al escribir código nuevo y al
revisar/auditar código existente.

1. **Domain layer pura:** prohibido importar Flutter u otras librerías de UI en `domain/`. Solo
   Dart puro + `equatable`/`dartz` si aplica.
2. **Value Objects para validación:** cualquier validación de input de usuario (email, password,
   etc.) se modela como Value Object (`formz`), nunca con RegEx directamente en la UI. Si una regla
   de negocio ya vive en un Value Object (ej. longitud mínima de password), no la dupliques en un
   Use Case ni en un Cubit — reutiliza el VO como única fuente de verdad.
3. **Repositorios como interfaces (`IXxxRepository`)** en `domain/repositories/`, implementados en
   `data/repositories/`. Nunca se referencia la implementación concreta fuera de `setup_di.dart`.
4. **Un Use Case por acción de negocio** (`domain/use_cases/`), con responsabilidad única.
5. **DataSources separados** en interfaz (Remote/Local) e implementación; el Repository Impl
   orquesta ambos y usa `INetworkInfo` para verificar conectividad antes de llamadas remotas.
6. **Mapeo de errores:** excepciones de infraestructura (`data/exceptions/`) deben mapearse a
   `Failure` (`domain/failures/`) dentro del Repository Impl; la UI nunca captura excepciones
   crudas.
7. **UI = Dumb Views:** las pantallas (`presentation/screens/`) no contienen lógica de negocio ni
   validaciones; solo reaccionan a estados de Cubits.
   - Prohibido `GlobalKey<FormState>` y manejo imperativo de `TextEditingController` para validar
     formularios.
   - Efectos secundarios (SnackBar, diálogos, navegación) van en `BlocListener`, nunca mezclados
     con la UI condicional del `build`.
8. **Segregación de estado:** no mezclar estado global de sesión (p.ej. `AuthCubit`) con estado
   efímero de un formulario (p.ej. `LoginCubit`). Cada pantalla con formulario tiene su propio
   Cubit local.
9. **Ciclo de vida en DI (`get_it`):**
   - `registerLazySingleton` → todo lo que gobierna estado/memoria persistente (repos,
     datasources, servicios, cubits globales como `AuthCubit`, `LocaleCubit`).
   - `registerFactory` → Cubits de pantalla/formulario (ViewModels efímeros), para que se destruyan
     al salir de la vista.
10. **Routing:** `AppRouter` (GoRouter) solo declara pantallas/transiciones. Toda lógica de
    protección de rutas vive en `AuthGuard`, evaluada contra listas abiertas (ej.
    `publicRoutes.contains(...)`), nunca con cadenas `if/else` por ruta. `AuthGuard` debe recibir
    sus dependencias por constructor (DIP) y no depender de tipos específicos del framework de
    routing (ej. recibir un `String location` en vez de un `GoRouterState`), para que un futuro
    cambio de librería de routing no obligue a reescribir la lógica de seguridad.
11. **Tipado estricto:** cero uso de `dynamic` salvo justificación explícita. Null safety
    deliberada, no forzada con `!` innecesariamente.
12. **Logging:** nunca usar `print()`. Todo pasa por `ILoggerService`
    (`lib/core/logging/interfaces/i_logger_service.dart`), que resuelve automáticamente a
    `DebugLoggerServiceImpl` o `CrashlyticsLoggerServiceImpl` según
    `bool.fromEnvironment('dart.vm.product')`. Nunca loguear tokens, contraseñas ni cuerpos
    completos de petición/respuesta HTTP.
13. **Theming:** no hardcodear colores/estilos en widgets. Usar `Theme.of(context)` y las
    abstracciones de `lib/core/theme/` (`AppColors`, `AppTheme`).

## Qué NO hacer

- No hardcodear textos, colores, URLs, tokens o keys.
- No usar `print()` para logging.
- No poner lógica de negocio o validación en widgets/pantallas.
- No usar `dynamic` sin justificación.
- No editar archivos generados (`l10n/app_localizations*.dart`).
- No mezclar responsabilidades entre capas (domain no conoce Flutter; presentation no conoce
  datasources directamente).
- No hacer commits/push sin que el usuario lo pida explícitamente.

Referencia detallada y ejemplos de código: `promt_solid.md` en la raíz del repo.
