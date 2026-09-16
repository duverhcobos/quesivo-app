# Propuesta: Paleta de colores de marca + rediseño del Splash

Se completa la paleta de colores dada por el usuario (faltaban `secondary`/`accent` en ambos
modos), se centraliza en `AppColors`/`AppTheme`, y se rediseña `SplashScreen` usando el logo real
de la app (`ic_launcher_foreground.png`, ya con transparencia pensada para superponerse a un
color de fondo) en vez del ícono genérico de Material que había antes.

Aplicado con autorización explícita del usuario para saltarse la revisión previa a la
implementación en esta ronda, pero documentado aquí como evidencia del cambio.

---

## Plan de diseño (color story)

Se convirtió `primary` a HSL para descubrir su "familia": **hue 189°, saturación 36%** (un
teal profundo, oscuro en modo claro / claro en modo oscuro). `secondary` y `accent` se derivaron
del mismo sistema en vez de elegirse sueltos:

| Rol | Justificación | Light | Dark |
|---|---|---|---|
| `text` (dado) | — | `#091415` | `#EAF5F6` |
| `background` (dado) | — | `#FAFEFF` | `#000405` |
| `primary` (dado) | Tono "club / noche después del partido" | `#224349` | `#B6D7DD` |
| `secondary` (nuevo) | Verde de cancha — mismo hue-family rotado a verde (142°), misma saturación (38%) que `primary` | `#295B3C` | `#A4D6B6` |
| `accent` (nuevo) | Calidez del tercer tiempo (terracota, hue 20°, saturación 65% — el color más vivo de los tres, el "único accesorio" que se permite brillar) | `#CA602B` | `#DF8F68` |
| `surface` (ajustado) | Blanco/negro con un leve tinte del mismo hue 189° en vez de blanco/negro puro | `#F6F8F8` | `#0D1112` |

Elemento firma del Splash: fondo a pantalla completa en `primary`, logo real con entrada
animada (fade + scale), y el indicador de carga en `accent` como único toque cálido sobre el
fondo frío.

---

## Resumen de cambios

| Archivo | Acción |
|---|---|
| `assets/images/app_logo.png` | Nuevo (copiado de `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png`) |
| `pubspec.yaml` | Actualización — declarar `assets/images/` |
| `lib/core/theme/app_colors.dart` | Actualización — paleta completa |
| `lib/core/theme/app_theme.dart` | Actualización — wiring de `secondary`/`tertiary` en `ColorScheme` y `surface` |
| `lib/features/auth/presentation/screens/splash_screen.dart` | Actualización — rediseño completo con logo + animación + paleta nueva |

---

## 1. app_logo.png (archivo nuevo, binario)

**Ruta:** `assets/images/app_logo.png`

Copiado de `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png` (capa foreground
del ícono adaptativo, ya diseñada con transparencia/padding para verse bien sobre cualquier color
de fondo — ideal para el splash).

## 2. pubspec.yaml (archivo existente — actualización)

**Antes:**
```yaml
flutter:
  uses-material-design: true
  generate: true
```

**Después:**
```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/images/
```

## 3. app_colors.dart (archivo existente — reemplazo completo, todo el contenido cambia)

**Antes:**
```dart
import 'package:flutter/material.dart';

/// Paleta de Colores Centralizada
///
/// SOLID (SRP): Ningún TextBox o Pantalla debe tener un color quemado ("hardcoded").
/// Las pantallas son "ciegas" a los colores reales. Solo conocen nombres abstractos.
/// Esto permite que si el gerente de diseño cambia el rojo por naranja,
/// modificamos solo una línea de código y toda la aplicación se rediseña.
class AppColors {
  // --- TEMA CLARO (LIGHT THEME) ---
  static const Color primaryLight = Color(0xFF6200EE);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceLight = Colors.white;
  static const Color textLight = Color(0xFF1F1F1F);
  static const Color errorLight = Color(0xFFB00020);

  // --- TEMA OSCURO (DARK THEME) ---
  static const Color primaryDark = Color(0xFFBB86FC);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textDark = Color(0xFFE0E0E0);
  static const Color errorDark = Color(0xFFCF6679);

  // --- COLORES NEUTROS Y COMPARTIDOS ---
  static const Color grey = Colors.grey;
  static const Color transparent = Colors.transparent;
}
```

**Después:**
```dart
import 'package:flutter/material.dart';

/// Paleta de Colores Centralizada — identidad "Tercer Tiempo"
///
/// SOLID (SRP): Ningún TextBox o Pantalla debe tener un color quemado ("hardcoded").
/// Las pantallas son "ciegas" a los colores reales. Solo conocen nombres abstractos.
///
/// Sistema de color: primary/secondary/accent comparten familia de saturación y la
/// misma lógica de luminosidad invertida entre modos (oscuro en light-mode, claro en
/// dark-mode), para sentirse como un solo sistema y no colores sueltos.
class AppColors {
  // --- TEMA CLARO (LIGHT THEME) ---
  static const Color primaryLight = Color(0xFF224349); // teal de club / post-partido
  static const Color secondaryLight = Color(0xFF295B3C); // verde de cancha
  static const Color accentLight = Color(0xFFCA602B); // terracota — calidez del 3er tiempo
  static const Color backgroundLight = Color(0xFFFAFEFF);
  static const Color surfaceLight = Color(0xFFF6F8F8);
  static const Color textLight = Color(0xFF091415);
  static const Color errorLight = Color(0xFFB00020);

  // --- TEMA OSCURO (DARK THEME) ---
  static const Color primaryDark = Color(0xFFB6D7DD);
  static const Color secondaryDark = Color(0xFFA4D6B6);
  static const Color accentDark = Color(0xFFDF8F68);
  static const Color backgroundDark = Color(0xFF000405);
  static const Color surfaceDark = Color(0xFF0D1112);
  static const Color textDark = Color(0xFFEAF5F6);
  static const Color errorDark = Color(0xFFCF6679);

  // --- COLORES NEUTROS Y COMPARTIDOS ---
  static const Color grey = Colors.grey;
  static const Color transparent = Colors.transparent;
}
```

## 4. app_theme.dart (archivo existente — actualización)

**Antes (fragmento `lightTheme`):**
```dart
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        surface: AppColors.surfaceLight, // 'background' se fusionó con 'surface' en Material 3
        error: AppColors.errorLight,
        onPrimary: Colors.white,
        onSurface: AppColors.textLight, // 'onBackground' desapareció en favor de 'onSurface'
        onError: Colors.white,
      ),
```

**Después (fragmento `lightTheme`):**
```dart
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        tertiary: AppColors.accentLight, // "accent" de marca vive en el slot tertiary de M3
        surface: AppColors.surfaceLight, // 'background' se fusionó con 'surface' en Material 3
        error: AppColors.errorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: AppColors.textLight, // 'onBackground' desapareció en favor de 'onSurface'
        onError: Colors.white,
      ),
```

**Antes (fragmento `darkTheme`):**
```dart
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        surface: AppColors.surfaceDark, // Reemplazamos background antiguo por surface
        error: AppColors.errorDark,
        onPrimary: Colors.black,
        onSurface: AppColors.textDark, // Reemplazamos onBackground por onSurface
        onError: Colors.black,
      ),
```

**Después (fragmento `darkTheme`):**
```dart
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        secondary: AppColors.secondaryDark,
        tertiary: AppColors.accentDark,
        surface: AppColors.surfaceDark, // Reemplazamos background antiguo por surface
        error: AppColors.errorDark,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onTertiary: Colors.black,
        onSurface: AppColors.textDark, // Reemplazamos onBackground por onSurface
        onError: Colors.black,
      ),
```

El resto de `app_theme.dart` (AppBar, botones, inputs) no cambia — sigue referenciando
`AppColors.primaryLight`/`primaryDark`, que ya apuntan a los nuevos valores.

## 5. splash_screen.dart (archivo existente — reemplazo completo)

**Antes:** (ver versión previa con `Icon(Icons.security)` centrado sobre fondo default).

**Después (archivo completo):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tercer_tiempo/l10n/app_localizations.dart';
import '../cubit/auth_cubit.dart';

/// Splash Screen — primer instante de la identidad visual de Tercer Tiempo.
///
/// Elemento firma: logo real con entrada animada (fade + scale) sobre un fondo
/// a pantalla completa en `primary`, con el indicador de carga en `accent` como
/// único toque cálido sobre el fondo frío.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().checkSession();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.85 + (0.15 * value),
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.splashLoadingMessage,
              style: TextStyle(fontSize: 18, color: colorScheme.onPrimary),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Orden de aplicación

1. Copiar `app_logo.png` a `assets/images/`.
2. Actualizar `pubspec.yaml` (declarar el asset) y correr `flutter pub get`.
3. Actualizar `app_colors.dart`.
4. Actualizar `app_theme.dart`.
5. Reemplazar `splash_screen.dart`.
6. Correr `flutter analyze` y `flutter test` (checklist de producción).
7. Verificar visualmente en modo claro y oscuro (`ThemeMode.system`).

## Notas de accesibilidad

- Contraste verificado heurísticamente vía luminosidad HSL (todos los pares texto/fondo quedan en
  extremos opuestos de luminosidad dentro de cada modo). Se recomienda verificar con una
  herramienta de contraste WCAG antes de considerar el cambio 100% cerrado para producción.
- La animación del logo respeta `MediaQuery.disableAnimations` (ajuste de movimiento reducido del
  sistema), reduciendo la duración a cero si el usuario lo tiene activado.
