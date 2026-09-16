# Propuesta: Onboarding premium — hero de marca + panel navy + parallax

**Estado: aplicada** — `flutter analyze` sin issues.

Rediseño visual del carrusel de onboarding (propuesta 05) para que deje de verse
como "Flutter genérico" (ícono Material en círculo gris) y adopte el lenguaje
QUESIVO como elemento principal. Sin assets nuevos, sin deps, sin cambios de
i18n ni de rutas — solo presentación.

**Tres cambios:**

1. **Hero de marca por slide**: el ícono pasa de "círculo gris `#EEF2F7`" a un
   **blob amarillo grande con huecos de queso** — el elemento firma de la marca
   escalado a protagonista (mismo lenguaje que el círculo decorativo del
   backdrop). Ícono navy más grande encima.
2. **Panel navy inferior**: los dots + el botón van dentro de un panel navy con
   esquinas superiores redondeadas — mismo patrón que el `welcome_panel` del
   design doc (§8 welcome). El círculo navy del backdrop desaparece (el panel lo
   reemplaza, igual que en welcome).
3. **Parallax**: el hero se desplaza horizontalmente a distinta velocidad que la
   página al arrastrar entre slides — profundidad sutil, coordinada con el gesto.

**Sin tocar:** textos (`.arb`), `IOnboardingStatusStore`, rutas, `AuthGuard`,
`setup_di.dart`. `animate: false` en el backdrop se mantiene (aprobado por el
usuario).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/onboarding/presentation/widgets/onboarding_hero.dart` | **Nuevo** — blob amarillo con huecos + ícono navy |
| `lib/features/onboarding/presentation/widgets/onboarding_page.dart` | Actualización — layout con hero + parallax |
| `lib/features/onboarding/presentation/widgets/onboarding_dots.dart` | Actualización — colores parametrizables (variante sobre navy) |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Actualización — panel navy inferior, sin círculo navy del backdrop |

---

## 1. onboarding_hero.dart (archivo nuevo)

**Ruta:** `lib/features/onboarding/presentation/widgets/onboarding_hero.dart`

Blob amarillo con huecos de queso blancos y el ícono navy centrado. Mismo
lenguaje visual que `_BrandCircle`/`_CheeseHole` del backdrop, pero como
elemento protagonista del slide (totalmente visible, huecos repartidos por todo
el círculo).

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Hero visual del slide de onboarding: blob amarillo QUESIVO con "huecos de
/// queso" blancos + ícono navy centrado. Es el elemento firma de la marca
/// llevado a tamaño protagonista.
class OnboardingHero extends StatelessWidget {
  const OnboardingHero({
    super.key,
    required this.icon,
    required this.size,
  });

  final IconData icon;

  /// Diámetro del blob.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ColoredBox(
              color: AppColors.quesivoYellow,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    _hole(0.16, 0.22, 0.11),
                    _hole(0.62, 0.14, 0.075),
                    _hole(0.74, 0.52, 0.12),
                    _hole(0.28, 0.68, 0.09),
                    _hole(0.48, 0.38, 0.06),
                  ],
                ),
              ),
            ),
          ),
          Icon(icon, size: size * 0.30, color: AppColors.quesivoNavy),
        ],
      ),
    );
  }

  /// Hueco blanco posicionado en fracciones del diámetro del blob
  /// (`left`/`top`/`size` relativos al tamaño del blob).
  Widget _hole(double left, double top, double holeSize) {
    return Positioned(
      left: size * left,
      top: size * top,
      child: Container(
        width: size * holeSize,
        height: size * holeSize,
        decoration: const BoxDecoration(
          color: AppColors.quesivoWhite,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
```

## 2. onboarding_page.dart (existente — reescritura)

**Ruta:** `lib/features/onboarding/presentation/widgets/onboarding_page.dart`

Ahora recibe el `PageController` y su índice para calcular el parallax del hero
(se muestra completo porque el layout cambia entero):

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'onboarding_hero.dart';

/// Slide individual del carrusel: hero de marca + título + descripción.
/// El hero aplica parallax según la posición de scroll del PageView.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.controller,
    required this.index,
  });

  final IconData icon;
  final String title;
  final String description;

  /// Controller del PageView — se escucha para el parallax del hero.
  final PageController controller;

  /// Índice de este slide dentro del PageView.
  final int index;

  /// Cuánto se desplaza el hero por página de scroll (px por delta).
  static const double _parallaxPx = 40;

  @override
  Widget build(BuildContext context) {
    final heroSize = MediaQuery.sizeOf(context).width * 0.62;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              // delta = cuánto está scrolleada esta página fuera de foco:
              // 0 = visible, ±1 = adyacente. El hero se mueve en dirección
              // contraria → efecto de profundidad al arrastrar.
              final page = controller.hasClients
                  ? (controller.page ?? index.toDouble())
                  : index.toDouble();
              final delta = (page - index).clamp(-1.0, 1.0);
              return Transform.translate(
                offset: Offset(delta * -_parallaxPx, 0),
                child: child,
              );
            },
            child: OnboardingHero(icon: icon, size: heroSize),
          ),
          const SizedBox(height: 44),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
```

## 3. onboarding_dots.dart (existente — colores parametrizables)

**Ruta:** `lib/features/onboarding/presentation/widgets/onboarding_dots.dart`

**Antes:**
```dart
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;
```

**Después:**
```dart
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.count,
    required this.currentIndex,
    this.activeColor = AppColors.quesivoNavy,
    this.inactiveColor = AppColors.quesivoBorder,
  });

  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;
```

**Antes:**
```dart
            color: isActive
                ? AppColors.quesivoNavy
                : AppColors.quesivoBorder,
```

**Después:**
```dart
            color: isActive ? activeColor : inactiveColor,
```

## 4. onboarding_screen.dart (existente — reestructura)

**Ruta:** `lib/features/onboarding/presentation/screens/onboarding_screen.dart`

La pantalla pasa de "contenido blanco con botón suelto" a "contenido + panel
navy inferior" (patrón del `welcome_panel` del design doc). El círculo navy del
backdrop se elimina (`bottomCircleFraction: 0`) porque el panel cumple ese rol.

**Antes (fragmento `build`):**
```dart
    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Estático en onboarding — la animación de entrada queda solo en splash.
        animate: false,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    l10n.onboardingSkip,
                    style: const TextStyle(
                      color: AppColors.quesivoNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _icons.length,
                  physics: reduceMotion
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) => OnboardingPage(
                    icon: _icons[index],
                    title: titles[index],
                    description: descriptions[index],
                  ),
                ),
              ),
              OnboardingDots(
                count: _icons.length,
                currentIndex: _currentPage,
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.quesivoYellow,
                      foregroundColor: AppColors.quesivoNavy,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      isLast ? l10n.onboardingStart : l10n.onboardingNext,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
```

**Después (fragmento `build` completo):**
```dart
    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Estático en onboarding — la animación de entrada queda solo en splash.
        animate: false,
        // Sin círculo navy abajo-izquierda: el panel navy lo reemplaza
        // (mismo criterio que la pantalla welcome del design doc).
        bottomCircleFraction: 0,
        child: SafeArea(
          bottom: false, // el panel navy llega hasta el borde inferior
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    l10n.onboardingSkip,
                    style: const TextStyle(
                      color: AppColors.quesivoNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _icons.length,
                  physics: reduceMotion
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) => OnboardingPage(
                    icon: _icons[index],
                    title: titles[index],
                    description: descriptions[index],
                    controller: _pageController,
                    index: index,
                  ),
                ),
              ),
              // Panel navy inferior — patrón welcome_panel del design doc:
              // ancho completo, esquinas superiores redondeadas, flat.
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.quesivoNavy,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OnboardingDots(
                        count: _icons.length,
                        currentIndex: _currentPage,
                        activeColor: AppColors.quesivoYellow,
                        inactiveColor: AppColors.quesivoWhite.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.quesivoYellow,
                            foregroundColor: AppColors.quesivoNavy,
                            elevation: 0,
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(
                            isLast ? l10n.onboardingStart : l10n.onboardingNext,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
```

> **Nota:** `bottomCircleFraction: 0` genera un círculo de diámetro 0 dentro del
> `Positioned`/`_CornerEntry` — inofensivo (widget vacío). Si en el futuro se
> quiere ocultar con más claridad se agrega un flag al backdrop; por ahora el
> parámetro existente lo cubre sin tocar la API.

---

## Orden de aplicación

1. Crear `onboarding_hero.dart`.
2. Reescribir `onboarding_page.dart`.
3. Actualizar `onboarding_dots.dart`.
4. Actualizar `onboarding_screen.dart`.
5. `flutter analyze` + `flutter test`; verificar en emulador: blob con huecos,
   panel navy con dots amarillo/blanco, parallax al arrastrar, "Saltar"/
   "Comenzar" siguen funcionando.

## Notas

- **Upgrade path a ilustraciones**: cuando existan assets, solo se reemplaza el
  `Icon` dentro de `OnboardingHero` por `Image.asset`/`SvgPicture` — el blob y
  el parallax quedan.
- **Accesibilidad**: contraste dots sobre navy (amarillo #F7A81D sobre #07275C
  ≈ 7:1), área de toque del botón 56px, `disableAnimations` neutraliza dots
  animados, swipe y — ahora también — parallax podría neutralizarse si se siente
  mareante (el `Transform.translate` queda; se puede envolver en `reduceMotion`
  en una iteración futura si hace falta).
- **El blob es idéntico en los 3 slides** — la variación entre slides la da el
  ícono y el copy; si se quiere más variedad, los huecos podrían parametrizarse
  por índice en una iteración futura.
