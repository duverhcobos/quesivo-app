# Propuesta: Identidad de la QuesivoNavBar — la gota láctea como indicador de tab

**Estado: aplicada y auditada** — `flutter analyze` 0 issues, `flutter test`
77/77, `dart format` limpio. Revisor: 1 defecto real corregido — el
`Positioned` de la gota necesitaba un `Center` interno (sin él el ícono se
alineaba a la izquierda del item, no centrado sobre el borde). Nota: el
snippet de esta propuesta omitía ese `Center` — corregido en la
implementación. yaml en 1.5.0.

**Fix posterior (yaml 1.5.1, feedback del usuario):** la animación entre
tabs se veía desastrosa — el ensanche animado `flex 2:1`
(`TweenAnimationBuilder` + `Expanded(flex:)`) relayouteaba los 4 items
frame a frame mientras el padding y el crossfade corrían a la vez →
tironeo y el chip "reajustándose". Retirado: los 4 items ahora son
`Expanded` 1:1 fijos y el chip anima solo dentro de su celda (color +
padding + crossfade). La gota y el glow sin cambios.

**Fix posterior (yaml 1.5.2, feedback del usuario):** chip amarillo y glow
eliminados — con la gota marcando el activo, el fondo amarillo era doble
señal. Los 4 items comparten el mismo layout (celda fija + columna
ícono/label); el activo = ícono filled + label en amarillo con el color
animado (`TweenAnimationBuilder<Color?>`). Resultado final: gota arriba +
contenido amarillo — una sola señal, cero reajustes.

**Ajuste posterior (yaml 1.5.3, pedido del usuario):** de píldora flotante
a lámina a ancho completo — sin márgenes, esquinas superiores radius 20
(espejo del header), `SafeArea` interno que extiende el navy detrás de la
barra de gestos, contenido 74px con padding superior 10 para que la gota
respire, y sombra hacia arriba (offset_y -6).

La píldora navy + chip amarillo ya funcionan; lo que falta es la firma de
marca. El imagotipo tiene dos elementos — la Q estilizada y la **gota
láctea** — y la gota todavía no aparece en ninguna superficie. Propuesta:
la gota es el **marcador del tab activo**, apareciendo sobre el item
seleccionado.

## Cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/shell/presentation/widgets/quesivo_nav_bar.dart` | Gota indicadora + glow del chip activo |
| `../Design/quesivo-design-system.yaml` | Spec + changelog 1.5.0 |

## Detalle

### 1. La gota indicadora (elemento firma)

`Icons.water_drop` amarillo (~10px) centrado sobre el **borde superior**
del item activo — "la gota cae sobre el tab". Aparece con fade+scale
(200ms) solo en el activo; los inactivos la tienen invisible (mismo
espacio, cero layout shift). Respeta `disableAnimations` (usa el mismo
`animDuration` ya calculado — con animaciones off aparece de golpe).

Implementación: en `_QuesivoNavItem`, el `Center(child: chip)` queda
dentro de un `Stack` del item completo:

```dart
return Stack(
  clipBehavior: Clip.none,
  children: [
    Center(child: AnimatedContainer( ...chip actual... )),
    // La gota láctea del imagotipo como marcador: aparece sobre el
    // borde superior del item activo (fade+scale), invisible en el resto.
    Positioned(
      top: 2,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: animDuration,
          opacity: isActive ? 1 : 0,
          child: AnimatedScale(
            duration: animDuration,
            scale: isActive ? 1 : 0.6,
            curve: Curves.easeOutBack,
            child: const Icon(
              Icons.water_drop,
              size: 10,
              color: AppColors.quesivoYellow,
            ),
          ),
        ),
      ),
    ),
  ],
);
```

La `Stack` reemplaza al `Center` directo dentro del `InkWell` (el ripple se
mantiene igual — la gota lleva `IgnorePointer`).

### 2. Glow sutil del chip activo

El `AnimatedContainer` del chip suma una sombra amarilla suave — el activo
"flota" sobre el navy:

```dart
decoration: BoxDecoration(
  color: isActive ? AppColors.quesivoYellow : AppColors.transparent,
  borderRadius: BorderRadius.circular(20),
  boxShadow: isActive
      ? [
          BoxShadow(
            color: AppColors.quesivoYellow.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ]
      : null,
),
```

### 3. Doc comment

Actualizar el del widget: la gota láctea marca el tab activo + glow del
chip. Mencionar que la gota es el segundo elemento del imagotipo (la Q es
la marca, la gota el guiño lácteo del dominio).

## NO se toca

- `goBranch` / `initialLocation` (re-tap vuelve a la raíz) — navegación intacta.
- La animación de flex 2:1 del item activo ni el `AnimatedSwitcher`.
- Íconos, labels, colores base de la píldora navy.

## Verificación

`flutter analyze` + `flutter test` + `dart format` en el archivo.
yaml → 1.5.0 (cambio visual nuevo en componente existente → minor).
