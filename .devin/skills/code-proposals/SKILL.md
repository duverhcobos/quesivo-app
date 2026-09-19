---
name: code-proposals
description: Flujo obligatorio de propuestas antes de tocar código fuente en Quesivo
triggers:
  - user
  - model
---

Este proyecto (**Quesivo**, app móvil Flutter en desarrollo activo con destino a producción) exige
que los cambios de código **no se apliquen directamente**: se plantean primero como una propuesta
para que el usuario la revise y apruebe.

## Orden de implementación (acordado 2026-09-19)

La propuesta NO espera aprobación previa — el usuario valida el resultado ya funcionando, no el
documento. El ciclo es:

```
1. Sesión principal → redacta la propuesta en propuestas/ (mismo detalle de siempre:
   rutas exactas + código completo de archivos nuevos — es el contrato de lo que se implementa)
2. Se implementa de inmediato (subagente implementador o directo según tamaño)
3. Se AVISA al usuario → él valida VISUALMENTE en el device/emulador y pide ajustes de diseño
4. Solo DESPUÉS de su validación pasa a auditoría de código (subagente revisor) —
   auditar antes sería revisar código que la revisión visual puede cambiar
5. Se aplican juntas las correcciones visuales del usuario + hallazgos de la auditoría
6. Verificación (format/analyze/test) + commit
```

Excepciones: correcciones triviales de un solo archivo y fixes de comportamiento reportados por el
usuario en físico (bugs/UX ya implementados) se aplican directo sin propuesta — quedan documentados
en el design-system yaml y/o el commit.

## Cuándo aplica

Siempre que se vaya a implementar una funcionalidad, agregar una feature/pantalla, modificar lógica
de negocio, o cualquier cambio que afecte archivos fuente del proyecto.

**Excepción:** correcciones triviales de un solo archivo (typos, un import faltante, un ajuste de
una línea sin impacto arquitectónico) se pueden aplicar directamente sin pasar por `propuestas/`.

**Excepción explícita del usuario:** si el usuario autoriza expresamente saltarse este flujo para
una tarea puntual ("hazlo directo", "sin propuesta"), se puede editar el código fuente
directamente para esa ronda de cambios. Fuera de esa autorización explícita, se vuelve al flujo de
propuestas por defecto.

## Pasos

1. No editar los archivos fuente directamente.
2. Crear un archivo markdown en `propuestas/` con el nombre `<numero>-<descripcion>.md`.
3. Código a incluir por archivo, según su estado:
   - **Archivo nuevo:** incluir el **código completo** del archivo.
   - **Archivo existente que se actualiza:** incluir **solo el fragmento que cambia**, nunca el
     archivo completo. Dar suficiente contexto alrededor (nombre del widget/clase/método, o unas
     pocas líneas antes/después) para ubicar dónde aplicar el cambio, en formato "Antes / Después".
4. Especificar la **ruta exacta** de cada archivo desde la raíz del proyecto (ej.
   `lib/features/auth/domain/use_cases/reset_password_use_case.dart`).
5. Si el cambio requiere tocar diccionarios de i18n (`lib/l10n/*.arb`), regeneración
   (`flutter gen-l10n`), registro en `setup_di.dart`, o rutas en `AppRouter`/`AuthGuard`, declararlo
   explícitamente como pasos de la propuesta.
6. No incluir código generado automáticamente (nada de `lib/l10n/app_localizations*.dart` escrito a
   mano): la propuesta debe indicar "ejecutar `flutter gen-l10n`" en vez de escribir esos archivos.
7. Terminar con el **orden de aplicación recomendado** de los archivos listados.

## Formato de propuesta

```markdown
# Propuesta: <Título>

Descripción breve.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `ruta/archivo.dart` | descripción |

---

## 1. <Nombre archivo> (archivo nuevo)

**Ruta:** `ruta/completa/archivo.dart`

\`\`\`dart
// código completo
\`\`\`

## 2. <Nombre archivo> (archivo existente — actualización)

**Ruta:** `ruta/completa/archivo.dart`

**Antes:**
\`\`\`dart
// solo el fragmento/método que cambia
\`\`\`

**Después:**
\`\`\`dart
// el fragmento ya modificado
\`\`\`

---

## Orden de aplicación

1. ...
2. ...
```

Las propuestas aplicadas pueden conservarse en `propuestas/` como historial de decisiones.
