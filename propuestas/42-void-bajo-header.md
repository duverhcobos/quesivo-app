# Propuesta: Cerrar el vacío navy bajo la identidad del header

Feedback visual del usuario sobre §41: "se ve mucho mejor, pero se desorganizó el header". El header no está roto — lo que quedó expuesto es un **vacío navy de ~40px** entre la identidad (nombre + organización) y el título del módulo: en §38/§39 el back arrow ocupaba esa zona y la hacía sentir intencional; al retirarlo (§41) quedó un hueco muerto que hace leer la banda como "estirada".

El vacío se compone de tres aires apilados:

- margen inferior del `ShellHeader` (16px dentro de sus 76px fijos),
- esquinas redondeadas inferiores de la banda (20px),
- la fila del título: `IconButton` de 48px mínimo con texto de 26 centrado (~9px de aire extra).

## Cambios

| Archivo | Acción |
|---------|--------|
| `shell_header.dart` | `contentHeight` 76 → **68** (márgenes verticales 16→12) — la banda se aprieta y `context.shellHeaderHeight` baja para todas las pantallas |
| `users_screen.dart` | `IconButton` de la acción: `padding: zero` + `constraints 40×40` (sigue siendo touch target aceptable) — la fila del título baja de 48 a 40; gap título→stats 12 → 8 |
| `Design/quesivo-design-system.yaml` | `content_height` + `module_header.height` + versión 1.7.4 → **1.7.5** + changelog |

Resultado esperado: vacío ~40px → ~20px — identidad y título vuelven a leerse como una sola cabecera. Sin cambios de i18n, DI, rutas ni tests (no hay textos ni widgets nuevos/eliminados).
