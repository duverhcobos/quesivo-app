# §64 — Hero activa sola (sin slide) + animaciones de las cards

Documento retroactivo: el cambio se iteró en vivo con revisión visual del
usuario; este archivo cierra el historial formal.

## Problema

Dos puntas sueltas tras §59–§63:

1. Con quesera activa, el `QueseraHeroCarousel` seguía siendo un
   `PageView`: la hero navy aparecía **acompañada** de las otras cards
   "Entrar" en el mismo slide — visualmente ruidoso y semánticamente
   confuso (mezclaba "estás adentro" con "elegí").
2. Las cards eran estáticas: aparecían de golpe y el tap no daba
   feedback propio (solo el ripple del `InkWell`).

## Cambio

### A. La activa va sola, sin slide

`quesera_hero_carousel.dart` — early return cuando `activeOrgId != null`:

- Una sola `QueseraHeroCard` a todo ancho, alto `_heroHeight` (208).
- Sin `PageView`, sin dots, sin cards "Entrar" al lado.
- El cambio de quesera queda: back → selector → tap en otra card.
- El selector (`enteredOrg == false`) conserva el PageView + dots +
  peek solo cuando hay >1 quesera; con 1 sigue siendo card única.

### B. Animaciones

- **Entrada escalonada** (`_CardEntrance`, privado del carousel):
  fade + slide-up (`Offset(0, 0.08)`, `easeOutCubic`, 380ms), cada
  card arranca 70ms después de la anterior. Se aplica también a la
  hero — antes no tenía animación propia y `AnimatedSwitcher` no
  anima al primer child (con sesión restaurada aparecía de golpe).
- **Press feedback** (`QueseraCard` → `StatefulWidget`):
  `AnimatedScale` 0.97 (140ms `easeOut`) vía `onHighlightChanged`
  del `InkWell` — toda la card "cede" al tocarla.
- **Transición selector ↔ hero** (`_switcher`): `AnimatedSwitcher`
  280ms con `transitionBuilder` custom — fade + `ScaleTransition`
  0.97 → 1 (`easeOutCubic`); la que sale se "aleja" encogiéndose
  apenas. Keys `ValueKey('selector')` / `ValueKey('hero')`.
- **Accesibilidad**: todo respeta `MediaQuery.disableAnimations` —
  duraciones a cero y `_CardEntrance` devuelve el child directo.

## Lo que NO cambia

- Tap de card → `QueseraSelectionCubit.select(org.id)` (§63: una sola
  request, sin `/auth/me` extra).
- La hero no es tappable — sin press feedback (no es acción).
- Ondas del painter: intactas (cuadradas por el usuario en §61).

## Tests

- `quesera_hero_carousel_test`: org activa + N queseras → una sola
  hero, sin `PageView` ni "Entrar"; selector con N orgs → `PageView`
  + dots; tap sigue llamando `select(orgId)`.
- `quesera_card_test`: render, tap habilitado/deshabilitado, loader —
  sin cambios de contrato (el press-scale es interno).
- Los tests drenan animaciones con `pumpAndSettle`.
