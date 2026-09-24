---
name: pendientes-produccion
description: Checklist de pendientes pre-producción (../pendientes/, compartida con el backend) — cuándo crear ítems, formato, estados y cuándo revisarlos antes de un release de Quesivo
triggers:
  - user
  - model
---

# Pendientes pre-producción

La carpeta `pendientes/` vive en la **raíz del repo backend** (`../pendientes/`, compartida entre backend y frontend — mismo criterio que `../planeaciones/`, que el frontend ya referencia desde su `AGENTS.md`). Guarda ítems accionables que hoy funcionan como workaround de dev/MVP pero deben resolverse — o aceptarse explícitamente — antes de desplegar a producción.

## Qué SÍ va en `pendientes/` (lado frontend)

- Workarounds temporales con costo conocido (ej. deep link `quesivo://` vía GitHub Pages en vez de App Link/Universal Link verificado).
- Dependencias externas que afectan al release (ej. dominio propio para `assetlinks.json`/AASA).
- Deuda de seguridad/config detectada y diferida (ej. token en un flujo pendiente de hardening).

## Qué NO va en `pendientes/`

- Features/pantallas nuevas → `propuestas/` (ver `code-proposals`).
- Checklist genérico de release → ya existe la skill `release-build`.
- Deuda de calidad interna (refactors, tamaño de archivos) → se resuelve directo.

## Formato

Un archivo por ítem en `../pendientes/`: `NNN-titulo-corto.md` (numeración secuencial). Debajo del título:

```markdown
# Pendiente: <Título>

> **Estado: 🔴 PENDIENTE** — <detalle breve>
> **Producto:** backend | frontend | ambos
> **Bloqueo:** bloqueante | recomendado | opcional
```

Estados: 🔴 pendiente · ⏸️ pendiente externo · 🟡 en curso · 🟢 resuelto (citar propuesta/commit, no borrar) · ⚪ descartado (con motivo).
Bloqueo: **bloqueante** (no desplegar sin resolver) · **recomendado** (salir con riesgo aceptado) · **opcional**.

## Cuándo crear / consultar

- **Crear**: al introducir un workaround temporal en una propuesta o fix (ej. esquema custom en lugar de App Links), o al detectar dependencia externa relevante a producción. Actualizar siempre la tabla del `../pendientes/README.md`.
- **Consultar**: antes de generar un release (complementa a `release-build` — esa skill cubre el checklist técnico del build; `pendientes/` cubre los ítems de producto/infra diferidos), y cuando el usuario pregunte "¿qué falta para producción?".

La convención completa (formato detallado, criterio de cierre, relación con propuestas) está en `../.devin/skills/pendientes-produccion/SKILL.md` del backend — ambas skills describen la misma carpeta.
