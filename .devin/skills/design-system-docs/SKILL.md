---
name: design-system-docs
description: Contrato de documentación del design system — cuándo y cómo actualizar quesivo-design-system.yaml (version bump, spec, changelog) tras cualquier cambio visual en Quesivo
allowed-tools:
  - read
  - grep
  - glob
triggers:
  - user
  - model
---

`Design/quesivo-design-system.yaml` (carpeta hermana de `Frontend/`) es la
**fuente de verdad** de la identidad visual de Quesivo — specs por
pantalla/componente + changelog versionado. Todo cambio visual que llega a
código debe reflejarse ahí en la misma iteración, no después.

## Cuándo toca actualizarlo

- Pantalla nueva, componente nuevo o rediseño → bump **minor** (1.4.x → 1.5.0).
- Ajuste visual dentro de un componente existente (colores, tamaños,
  paddings, animación) → bump **patch** (1.4.0 → 1.4.1).
- Refactor sin cambios visuales (mover archivos, renombrar) → patch con
  `status: "completed"` y nota de "sin cambios visuales" — documenta la
  estructura, no el look.
- Solo l10n/copy sin cambio visual → no hace falta bump.

## Qué va en cada sección

- **`version`** (metadata arriba): la nueva versión.
- **Spec del componente/página**: el estado real y final — tokens,
  medidas, widgets involucrados, comportamiento. Se edita in-place, no se
  acumula historia ahí.
- **`changelog`** (al final, una entrada por versión):
  ```yaml
  - version: "1.x.y"
    page: "shell"          # o la página afectada
    status: "completed"
    changes:
      - "Qué cambió + por qué (propuesta §NN citada si aplica)"
  ```
  El changelog sí acumula historia — cada entrada describe el delta.

## Convenciones de escritura

- Referencias a propuestas como `propuesta §30-drawer-diseno-v2` o
  `(§28)` inline.
- Valores con tokens del sistema (`#07275C`, `quesivoSurface`), no nombres
  inventados.
- Bugs descartados también se documentan (ej. fuentes de ruta activa que
  fallaron — §28) para que no se repitan.
- Si el cambio vino de feedback del usuario en sesión ("no tiene
  identidad", "el backdrop hace ruido"), citarlo — el changelog explica el
  porqué, no solo el qué.
