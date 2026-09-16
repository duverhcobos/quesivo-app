# Instrucciones del Proyecto Quesivo App

El detalle de convenciones, arquitectura y workflows de este proyecto vive en skills bajo `.devin/skills/`, no en este archivo — cada skill cubre una sola responsabilidad y se invoca solo cuando es relevante, para no cargar contexto innecesario en cada sesión.

> Este proyecto Flutter nació del código de otro proyecto propio (Tercer Tiempo) — la arquitectura y los patrones se conservan, pero el producto es **Quesivo**: la app móvil del SaaS multi-tenant para queseras (`app-quesera`). El rebrand `tercer_tiempo` → `quesivo` ya se aplicó (`propuestas/08`); referencias al nombre viejo en `propuestas/01-07` son historial, no estado actual.

## Reglas mínimas siempre vigentes

- **Framework:** Flutter (SDK `^3.8.1`), Clean Architecture + S.O.L.I.D.
- **Nunca editar archivos fuente directamente** para implementar funcionalidad o lógica de negocio: ver skill `code-proposals` antes de escribir/modificar código (excepción: correcciones triviales de un solo archivo).
- **OS de desarrollo**: Windows / PowerShell.
- **Producto: Quesivo — app móvil** (Android/iOS), único cliente del MVP del backend Quesera, para el rol Administrador (decisión en `../planeaciones/003-decision-plataforma-frontend-movil.md`). App real camino a producción, no un repositorio de prueba/plantilla. Todo cambio se trata con el mismo rigor que código productivo — ver skill `environments-secrets` **siempre** que se toquen entornos, URLs, tokens o certificados.

## Índice de skills

| Skill | Cuándo usarla |
|-------|---------------|
| `flutter-architecture` | Antes de crear un archivo/feature nueva — confirmar el stack real y la estructura de carpetas Feature-First |
| `solid-clean-architecture` | Al escribir o revisar código — reglas SOLID, separación de capas, qué NO hacer |
| `environments-secrets` | Al tocar variables de entorno, URLs, tokens, certificados o cualquier cosa relacionada con sesión/seguridad |
| `i18n-workflow` | Al agregar o modificar cualquier texto visible al usuario |
| `ui-design-standard` | Al crear o modificar una pantalla/widget — theming, espaciado, componentes reutilizables, patrones de estructura |
| `file-size-refactoring` | **Siempre** al crear o modificar código — umbrales de tamaño de archivo y cuándo/cómo extraer widgets a archivos propios |
| `bloc-patterns` | Al escribir o revisar UI con estado — cuándo usar `context.read`/`watch`/`select` vs `BlocBuilder`/`BlocListener`/`BlocConsumer`, y dónde vive cada pieza (shell vs widgets) |
| `frontend-design` | Al diseñar o rediseñar UI con impacto visual — dirección estética distintiva, para que no se vea como una app Material genérica |
| `testing-workflow` | Al escribir tests o correr `flutter analyze`/`flutter test` |
| `code-proposals` | **Siempre** que se vaya a proponer un cambio de código — formato y reglas del archivo en `propuestas/` |
| `production-checklist` | **Siempre** antes de dar por terminado un cambio |
| `navigation-routing` | Al tocar rutas/pantallas — go_router: constantes en AuthGuard, segmentos relativos en hijos, push vs go, fuente de verdad de la ruta activa |
| `release-build` | Antes de generar APK/AAB release — permisos, --dart-define por entorno, mocks de dev, firma y versionado |
| `design-system-docs` | Tras cualquier cambio visual — cómo actualizar `Design/quesivo-design-system.yaml` (version, spec, changelog) |
| `new-feature-checklist` | Al agregar un módulo/feature nuevo — orden exacto de archivos del dominio a la pantalla |
| `token-saving-tools-policy` | Al explorar el código — cuándo leer directo vs. usar el grafo codebase-memory, batching y evitar repetir comandos |

Si una instrucción parece faltar acá, buscarla primero en `.devin/skills/` antes de asumir que no existe. La documentación extendida original también vive en `README.md`, `ENVIRONMENTS.md`, `I18N_GUIDE.md` y `promt_solid.md`.

## Flujo de desarrollo con subagentes

El proyecto tiene dos subagentes custom en `.devin/agents/`. **Usarlos siempre
que aplique** — no implementar propuestas ni auditar código directamente en la
sesión principal:

| Subagente | Modelo | Rol | Cuándo delegarle |
|-----------|--------|-----|------------------|
| `implementador` | SWE-2 | Aplica propuestas aprobadas al pie de la letra + `flutter analyze` + `flutter test` | Después de que la sesión principal (Sonnet) redacte y el usuario apruebe una propuesta |
| `revisor` | SWE-2 | Audita SOLID/convenciones — solo lee, no edita | Después de implementar, para verificar calidad del código resultante |

### Flujo estándar para cambios no triviales

```
1. Sesión principal (Sonnet) → diseña la propuesta en propuestas/
2. Usuario aprueba
3. Subagente "implementador" (SWE-2) → aplica la propuesta
4. Subagente "revisor" (SWE-2) → audita el resultado
5. Sesión principal (Sonnet) → reporta resumen al usuario
```

La sesión principal **piensa y decide**; los subagentes **ejecutan y verifican**.
Esto optimiza costo (SWE-2 es gratis) sin sacrificar calidad de diseño.
