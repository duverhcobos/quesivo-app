# Propuesta: Refactor — `welcome_screen` y `onboarding_screen`

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77. Revisor: APROBADO sin hallazgos. `welcome_screen.dart` 97 → 38 líneas (`WelcomeBrandArea` + `WelcomeActions`); `onboarding_screen.dart` 173 → 136 líneas (`OnboardingBottomPanel`; el PageView/estado quedaron en la screen porque le pertenecen).

Cierra la serie de refactors (14–17) aplicando el mismo patrón a las dos
pantallas restantes que lo ameritan: la screen compone widgets; el estado y el
wiring quedan en la screen. **Sin cambios de píxeles ni comportamiento.**

Nota de alcance: ambas son de otros features — los widgets nuevos van en
`features/welcome/presentation/widgets/` y `features/onboarding/presentation/widgets/`
respectivamente (no en auth).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/welcome/presentation/widgets/welcome_brand_area.dart` | **Nuevo** — área de marca 61% + imagotipo |
| `lib/features/welcome/presentation/widgets/welcome_actions.dart` | **Nuevo** — row de los 2 botones |
| `lib/features/welcome/presentation/screens/welcome_screen.dart` | **Reduce a shell** (~55 líneas) |
| `lib/features/onboarding/presentation/widgets/onboarding_bottom_panel.dart` | **Nuevo** — panel navy: dots + botón next/start |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | **Reduce** (~120 líneas) — conserva estado y PageView |

---

## 1. Welcome

**`welcome_brand_area.dart` — `WelcomeBrandArea`** (stateless, literal):

```dart
/// Área de marca superior (61% del alto) con el imagotipo (~42% vertical
/// del área) — §welcome.
class WelcomeBrandArea extends StatelessWidget {
  const WelcomeBrandArea({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      height: size.height * 0.61,
      width: double.infinity,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(top: size.height * 0.61 * 0.10),
          child: Image.asset(
            'assets/images/imagotipo_quesivo.png',
            width: size.width,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
```

**`welcome_actions.dart` — `WelcomeActions`** (stateless, `l10n` por context):
el `Row` actual con los dos `Expanded > SizedBox(60) > ElevatedButton` —
"Iniciar Sesión" amarillo → `push(loginRoute)` y "Registrarse" blanco →
`push(registerRoute)`, literal (17/w700, StadiumBorder, gap 18, comentarios
de los botones incluidos).

**`welcome_screen.dart`** queda:

```dart
class WelcomeScreen extends StatelessWidget {
  // Scaffold(quesivoWhite) > Column:
  //   const WelcomeBrandArea(),
  //   Expanded(
  //     child: WelcomePanel(
  //       title: l10n.welcomeTitle,
  //       description: l10n.welcomeDescription,
  //       actions: const WelcomeActions(),
  //     ),
  //   ),
}
```

(Imports eliminados: `go_router`, `auth_guard`, `app_colors` — solo si quedan
muertos tras mover los botones.)

## 2. Onboarding

**`onboarding_bottom_panel.dart` — `OnboardingBottomPanel`** (stateless):

```dart
/// Panel navy inferior del onboarding: dots + botón next/"Comenzar"
/// (patrón welcome_panel del design doc: ancho completo, esquinas
/// superiores 30px, flat).
class OnboardingBottomPanel extends StatelessWidget {
  const OnboardingBottomPanel({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.buttonLabel,
    required this.onPressed,
  });

  final int count;
  final int currentIndex;
  final String buttonLabel;
  final VoidCallback onPressed;
}
```

Cuerpo literal del `Container` actual: navy + `BorderRadius.vertical(top: 30)`
+ padding `fromLTRB(32, 24, 32, 32)` + `SafeArea(top: false)` + Column[
`OnboardingDots(count, currentIndex, activeColor: quesivoYellow,
inactiveColor: quesivoWhite.withValues(alpha: 0.35))`, `SizedBox(20)`,
`SizedBox(w:inf, h:56) > ElevatedButton` amarillo/navy 16/w700 pill con
`buttonLabel`/`onPressed`].

**`onboarding_screen.dart`** conserva todo el estado (`PageController`,
`_currentPage`, `_next`, `_finish`, `dispose`) y el build queda:

```dart
// ... Column:
//   Align(skip TextButton → _finish)            // se queda (es navegación
//   Expanded(PageView.builder → OnboardingPage) // ligada al estado local)
//   OnboardingBottomPanel(
//     count: _icons.length,
//     currentIndex: _currentPage,
//     buttonLabel: isLast ? l10n.onboardingStart : l10n.onboardingNext,
//     onPressed: _next,
//   ),
```

El PageView y el skip NO se extraen: dependen del `PageController`/`setState`
locales — es la lógica de la pantalla, no decoración.

## 3. Reglas (mismas que 14–17)

- **Literal**: cero cambios de píxel/estilo/comportamiento; comentarios
  explicativos viajan con el código.
- Doc comment de intención en widgets nuevos; `const` donde aplique.
- No tocar nada fuera de `presentation/`; sin claves l10n nuevas; sin git.

## 4. Verificación

- `flutter analyze` — 0 issues.
- `flutter test` — 77/77.
- Manual: `/welcome` y `/onboarding` pixel-par; navegación welcome→login/
  register y el carrusel intactos.
