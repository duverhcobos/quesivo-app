---
name: frontend-design
description: Guía de dirección visual distintiva para Quesivo App — evita que la UI se vea como una app Flutter/Material genérica sin identidad propia
triggers:
  - user
  - model
---

Enfoca esto como el/la directora de diseño de un estudio conocido por darle a cada cliente una
identidad visual que no se pueda confundir con "otra app Flutter con Material Design por default".
**Quesivo** ya tiene una identidad de marca definida en `Design/quesivo-design-system.yaml`
(repositorio `app-quesera`, carpeta hermana de `Frontend/`) — ese documento es la **fuente de
verdad** de la identidad visual: paleta `primary_navy` `#07275C` + `primary_yellow` `#F7A81D`,
imagotipo con Q estilizada + porción de queso + gota láctea, y especificaciones por pantalla.
Las decisiones de diseño salen de ahí y del dominio quesero (producción láctea, queseras rurales,
gestión simple para el administrador), no de un tema de Material genérico con el nombre "Quesivo"
encima.

## Diagnóstico honesto del estado actual

La paleta light/dark de `AppColors` (`lib/core/theme/app_colors.dart`) todavía conserva colores
heredados del proyecto origen (teal/verde/terracota) que **no** son la identidad Quesivo — los
tokens `quesivo*` del mismo archivo (`quesivoNavy`, `quesivoYellow`, etc.) son la marca real y las
pantallas de identidad (splash, welcome, onboarding) ya los usan. Antes de agregar cualquier
pantalla nueva, cuestionar si la paleta/tipografía usada expresa "Quesivo / gestión de quesera" o
si es intercambiable con cualquier otra app.

## Principios de diseño (adaptados a Flutter/mobile)

- **El "hero" en mobile no es una sección, es el primer instante.** El `SplashScreen` y la primera
  pantalla que ve alguien logueado (`HomeScreen`) son la oportunidad de instalar la identidad
  visual — el splash ya lo hace con `QuesivoBackdrop` + imagotipo; el resto de pantallas debe
  seguir el mismo lenguaje (navy sólido, acentos amarillos, componentes redondeados del design
  system), no un `Scaffold` genérico con un ícono de Material.
- **La tipografía carga la personalidad.** Definir un par de familias tipográficas deliberado en
  `AppTheme` (una para títulos con carácter, otra para cuerpo de texto legible) en vez de dejar la
  fuente por defecto del sistema/Material. Si se usa `google_fonts` o una fuente bundleada, debe
  registrarse una sola vez en `AppTheme`, nunca con `TextStyle(fontFamily: ...)` sueltos en cada
  pantalla.
- **La estructura debe significar algo.** Si en algún momento se necesitan indicadores numerados,
  divisores o "chips" de estado, que representen algo real del dominio (ej. litros recibidos,
  estado de una liquidación, etapa de un lote de producción) — no decoración genérica tipo
  "01 / 02 / 03" sin relación con el contenido.
- **Movimiento con intención, no decoración.** Ya existe `CustomTransitions` (fade/slideUp) como
  base — al agregar micro-interacciones (botones, transición de login exitoso, etc.) preguntarse
  si refuerzan la sensación de claridad/confianza que necesita quien administra su quesera, o si
  son solo efecto por efecto. Menos animación bien pensada gana sobre muchos efectos sueltos.
- **La complejidad debe calzar con la visión.** Si la dirección elegida es minimalista (fondo
  limpio, tipografía fuerte, poco color), la ejecución tiene que ser precisa en espaciado y detalle
  — no una versión a medias de un diseño maximalista.

## Proceso: plan de tokens antes de código

Antes de tocar `AppColors`/`AppTheme` o construir una pantalla nueva con intención visual:

1. **Color:** partir de la paleta del design system (`primary_navy` `#07275C`, `primary_yellow`
   `#F7A81D`, neutros `#F7F9FC`/`#E5EAF2`/`#172033`, semánticos success `#2E9B62` / warning
   `#F2A900` / error `#D64545` / info `#3478C8`). Si la pantalla está especificada en
   `quesivo-design-system.yaml`, seguir esa spec al pie de la letra; si es nueva, reutilizar los
   tokens `quesivo*` de `AppColors` y documentar cualquier color nuevo en el yaml.
2. **Tipografía:** 2 roles mínimo — una tipografía de display con carácter (usada con
   moderación, para títulos/momentos clave) y una tipografía de cuerpo legible para el resto.
3. **Layout:** describir en una frase + un wireframe ASCII simple cómo se ve la pantalla nueva,
   antes de escribir el widget tree.
4. **Elemento firma:** un único elemento distintivo que la pantalla debe recordar (ej. una forma,
   un patrón, un detalle de color) — no varios efectos compitiendo entre sí.

Después de armar ese plan, revisarlo contra la pregunta: *"¿esto es una decisión para Quesivo
específicamente, o es lo que produciría cualquier app Flutter con un tema Material 3 sin
personalizar?"* Si se parece a lo genérico, ajustar antes de escribir código.

## Autocrítica y contención

- Gastar la "audacia" en un solo lugar (el elemento firma); todo alrededor debe quedar disciplinado
  y consistente con el resto de la app (ver skill `ui-design-standard` para la escala de espaciado
  y componentes reutilizables — esta skill decide *qué* diseñar, `ui-design-standard` decide *cómo*
  mantenerlo consistente una vez decidido).
- No sacrificar accesibilidad por estética: contraste suficiente en ambos temas, tamaños de toque
  adecuados, y respetar el ajuste de movimiento reducido del sistema
  (`MediaQuery.of(context).disableAnimations`) antes de animar agresivamente.
- Probar cualquier cambio de paleta/tipografía en `ThemeMode.system` (light y dark), no solo en el
  tema que se tenga abierto en el momento.

## Copy y voz (aplica a los `.arb` de `lib/l10n/`)

- Las palabras son material de diseño, no relleno. Antes de escribir un texto nuevo, preguntar qué
  necesita entender o poder hacer la persona en ese momento.
- Nombrar las cosas como las nombra quien administra una quesera, no como las nombra el
  código (ej. "Recepción de leche", no "Insert de milk_reception").
- Voz activa y consistente: si un botón dice "Enviar Instrucciones", la confirmación debe hablar de
  lo mismo ("Correo de recuperación enviado"), no de otra cosa.
- Errores y estados vacíos: explicar qué pasó y qué hacer, en el tono de la interfaz — nunca vagos
  ni con jerga técnica (ej. evitar mostrarle a alguien un `Exception` o un código de estado HTTP
  crudo).
