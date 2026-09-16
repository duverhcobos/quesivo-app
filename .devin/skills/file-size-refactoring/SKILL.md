---
name: file-size-refactoring
description: Regla obligatoria de refactorización por tamaño — cuándo y cómo partir archivos grandes en widgets/componentes extraídos para mantener legibilidad en Quesivo
allowed-tools:
  - read
  - grep
  - glob
triggers:
  - user
  - model
---

Regla de tamaño y legibilidad para **Quesivo**. Aplica **siempre**: al crear
una pantalla/widget nuevo y también al modificar uno existente (si tu cambio
deja el archivo más grande, evaluá partirlo ANTES de dar por terminado).

## Umbrales — cuándo partir un archivo

| Señal | Acción |
|-------|--------|
| El archivo supera **~300 líneas** | Evaluar extracción — no es tolerable que siga creciendo |
| El archivo supera **~450 líneas** | Extracción obligatoria antes de cerrar el cambio |
| Contiene **más de 2 widgets/clases** con responsabilidad visual propia | Extraer los sub-widgets a archivos propios |
| Un `build` tiene bloques de **~40+ líneas** autocontenidos (una tarjeta, un header, una lista) | Extraer el bloque como widget con nombre propio |
| Helpers puros (funciones top-level) + widgets mezclados | El helper va al archivo del widget que lo usa, o a su propio archivo si es compartido |

Los umbrales son de archivo COMPLETO (imports + todas las clases), no por
clase. Un archivo de 200 líneas con 5 widgets de 40 líneas también se parte:
el problema es la cantidad de responsabilidades por archivo, no solo el total.

## Cómo extraer (convención del proyecto)

- Los sub-widgets extraídos que son **específicos de un diseño/componente**
  se **empaquetan en una subcarpeta** dentro de `widgets/` con el nombre del
  diseño — no quedan sueltos junto al resto:
  `widgets/quesivo_drawer.dart` → `widgets/drawer/drawer_menu_item_row.dart`,
  `widgets/drawer/drawer_identity.dart`. Si un widget extraído es genérico
  y reusable por otros componentes del feature, sí queda directo en
  `widgets/` — la carpeta es solo para piezas del mismo diseño.
- Al extraer, la clase **deja de ser privada** (`_MenuItemRow` →
  `DrawerMenuItemRow`) y conserva su doc comment movido al nuevo archivo.
- El archivo original queda como **composición**: importa las piezas y solo
  orquesta (Scaffold/Drawer/Stack + disposición). Screens y widgets
  contenedores componen, no implementan bloques visuales grandes.
- Si varios widgets extraídos comparten imports (AppColors, l10n, go_router),
  cada archivo lleva solo los imports que usa — no re-exportar.
- **Ojo con los imports relativos al mover a subcarpeta**: un nivel más de
  profundidad = un `../` más (desde `widgets/drawer/` a `lib/core/` son
  `../../../../../core/`, no `../../../../core/`).
- **Extraer sin cambiar comportamiento**: un refactor por tamaño no toca
  lógica, estado ni estilos — solo mueve código y ajusta nombres/imports.

## Cuándo se revisa

1. **Al diseñar la propuesta**: si la feature va a agregar >100 líneas a un
   archivo existente, la propuesta ya debe incluir la extracción como parte
   del plan (archivos nuevos listados junto a los modificados).
2. **Al implementar**: si al terminar el archivo quedó por encima del umbral,
   partir antes de correr `flutter analyze`/`test` finales.
3. **En el checklist de cierre** (`production-checklist`): el tamaño de los
   archivos tocados es un ítem de revisión — no se cierra un cambio dejando
   un archivo que creció sin evaluación de extracción.

## Señales de que un archivo ya pasó el punto

- Scrollear para encontrar un widget concreto lleva más de una pantalla.
- El doc comment de la clase principal tiene que explicar varios widgets
  privados para que el archivo se entienda.
- Cambiar el estilo de un ítem obliga a buscar entre cientos de líneas de
  otros widgets sin relación.

## Referencia

`quesivo_drawer.dart` creció a ~690 líneas con 6 widgets privados mezclados
(propuesta §29-refactor-drawer): es el ejemplo canónico de este problema y de
su solución — un archivo de composición + widgets `drawer_*` extraídos.
