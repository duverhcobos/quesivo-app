# Propuesta: Pantalla de Bienvenida (Welcome Screen)

**Estado: aplicada** — `flutter analyze` sin issues, `flutter test` 43/43.
Auditoría SOLID: APROBADO CON OBSERVACIONES (ver notas al pie).

Implementación de la pantalla de bienvenida definida en
`Design/quesivo-design-system.yaml` §welcome. Pantalla estática (sin estado de
negocio, sin Cubit) — su único rol es presentar la marca y ofrecer dos acciones:
"Iniciar Sesión" y "Registrarse".

**Spec clave del design doc:**
- 61% superior: área blanca con imagotipo centrado (~65% del ancho, ~42% del alto del área).
- 39% inferior: panel navy (`#07275C`), esquinas superiores redondeadas (30px),
  padding horizontal 8%, vertical 7%.
- Título "Bienvenido" (blanco, bold, ~44px, alineado izquierda).
- Descripción (blanco, 95% opacidad, ~18px, max 3 líneas, alineado izquierda).
- Dos botones pill horizontales: "Iniciar Sesión" (amarillo, texto navy) +
  "Registrarse" (blanco, texto navy). Sin bordes, sin sombras.
- Flat 2D, sin efectos.

**Sin tocar:** `IOnboardingStatusStore`, `setup_di.dart`, `app_bootstrap.dart`,
`auth_guard_test.dart` (no hay nueva lógica de guard). El welcome es una ruta
pública sin protección especial — el guard ya redirige a login si no hay sesión.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/welcome/presentation/screens/welcome_screen.dart` | **Nuevo** |
| `lib/features/welcome/presentation/widgets/welcome_panel.dart` | **Nuevo** |
| `lib/l10n/app_es.arb` | Agregar 4 keys |
| `lib/l10n/app_en.arb` | Agregar 4 keys |
| `lib/l10n/app_pt.arb` | Agregar 4 keys |
| `lib/core/routes/app_router.dart` | Agregar ruta `/welcome` |
| `lib/core/routes/auth_guard.dart` | Agregar `/welcome` a `publicRoutes`, cambiar destino de onboarding/guard a `/welcome` en vez de `/login` |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Cambiar destino `_finish()` de `/login` a `/welcome` |
| `test/core/routes/auth_guard_test.dart` | Actualizar expectativas (destino welcome en vez de login para unauthenticated) |

---

## 0. Localización (4 keys nuevas × 3 idiomas)

### app_es.arb — agregar al final (antes del `}`):

```json
  "welcomeTitle": "Bienvenido",
  "welcomeDescription": "Gestiona tu quesera de forma simple: controla producción, inventario, proveedores y pagos desde un solo lugar.",
  "welcomeSignIn": "Iniciar Sesión",
  "welcomeSignUp": "Registrarse"
```

### app_en.arb — agregar al final:

```json
  "welcomeTitle": "Welcome",
  "welcomeDescription": "Manage your cheese factory simply: control production, inventory, suppliers, and payments from one place.",
  "welcomeSignIn": "Sign In",
  "welcomeSignUp": "Sign Up"
```

### app_pt.arb — agregar al final:

```json
  "welcomeTitle": "Bem-vindo",
  "welcomeDescription": "Gerencie sua queijaria de forma simples: controle produção, estoque, fornecedores e pagamentos em um só lugar.",
  "welcomeSignIn": "Entrar",
  "welcomeSignUp": "Cadastrar"
```

Después: `flutter gen-l10n`

---

## 1. welcome_panel.dart (archivo nuevo)

**Ruta:** `lib/features/welcome/presentation/widgets/welcome_panel.dart`

Panel navy inferior reutilizable — diseño §welcome `welcome_panel`. Recibe
título, descripción y acciones como parámetros (DIP — la pantalla compone, el
panel presenta).

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Panel navy inferior de la pantalla de bienvenida
/// (quesivo-design-system.yaml §welcome.welcome_panel).
///
/// Esquinas superiores redondeadas 30px, ancho completo, pegado al borde
/// inferior. Flat 2D: sin sombras, sin bordes, sin degradados.
class WelcomePanel extends StatelessWidget {
  const WelcomePanel({
    super.key,
    required this.title,
    required this.description,
    required this.actions,
  });

  final String title;
  final String description;

  /// Fila de botones (ej. "Iniciar Sesión" + "Registrarse").
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.quesivoNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width * 0.08,
            vertical: MediaQuery.sizeOf(context).height * 0.035,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: AppColors.quesivoWhite,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: AppColors.quesivoWhite.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 30),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 2. welcome_screen.dart (archivo nuevo)

**Ruta:** `lib/features/welcome/presentation/screens/welcome_screen.dart`

Pantalla estática — sin Cubit (no hay estado de negocio). Compuesta por:
- Área superior 61%: imagotipo centrado al ~42% vertical.
- Área inferior 39%: `WelcomePanel` con título, descripción y dos botones.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tercer_tiempo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/routes/auth_guard.dart';
import '../widgets/welcome_panel.dart';

/// Pantalla de bienvenida QUESIVO (quesivo-design-system.yaml §welcome).
///
/// Presenta la marca y ofrece dos acciones de autenticación: iniciar sesión
/// o registrarse. Sin Cubit — es UI pura sin estado de negocio.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: Column(
        children: [
          // --- Área de marca (61% superior) ---
          SizedBox(
            height: size.height * 0.61,
            width: double.infinity,
            child: Center(
              child: Padding(
                // Ubicar el logo al ~42% vertical del área de marca
                padding: EdgeInsets.only(top: size.height * 0.61 * 0.10),
                child: Image.asset(
                  'assets/images/imagotipo_quesivo.png',
                  width: size.width * 0.65,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // --- Panel navy (39% inferior) ---
          Expanded(
            child: WelcomePanel(
              title: l10n.welcomeTitle,
              description: l10n.welcomeDescription,
              actions: Row(
                children: [
                  // Botón primario: Iniciar Sesión (amarillo, texto navy)
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () => context.go(AuthGuard.loginRoute),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.quesivoYellow,
                          foregroundColor: AppColors.quesivoNavy,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(l10n.welcomeSignIn),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  // Botón secundario: Registrarse (blanco, texto navy)
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        // TODO: navegar a /register cuando exista la pantalla
                        onPressed: () => context.go(AuthGuard.loginRoute),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.quesivoWhite,
                          foregroundColor: AppColors.quesivoNavy,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(l10n.welcomeSignUp),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

> **Nota:** El botón "Registrarse" navega temporalmente a `/login` porque la
> pantalla de registro no existe aún. Se marcó con `TODO` — se cambiará a
> `/register` cuando se implemente esa feature.

---

## 3. Actualizar app_router.dart

**Antes:**
```dart
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../di/setup_di.dart';
```

**Después:**
```dart
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';
import '../di/setup_di.dart';
```

**Antes (rutas, después de `/onboarding` y antes de `/login`):**
```dart
      GoRoute(
        path: '/login',
```

**Después:**
```dart
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => CustomTransitions.fade(
          context: context,
          state: state,
          child: const WelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
```

---

## 4. Actualizar auth_guard.dart

### 4a. Agregar `/welcome` a rutas públicas y constante

**Antes:**
```dart
  static const List<String> publicRoutes = [
    '/login',
    '/forgot-password',
    '/onboarding',
  ];

  static const String splashRoute = '/splash';
  static const String homeRoute = '/home';
  static const String loginRoute = '/login';
  static const String onboardingRoute = '/onboarding';
```

**Después:**
```dart
  static const List<String> publicRoutes = [
    '/welcome',
    '/login',
    '/forgot-password',
    '/onboarding',
  ];

  static const String splashRoute = '/splash';
  static const String homeRoute = '/home';
  static const String welcomeRoute = '/welcome';
  static const String loginRoute = '/login';
  static const String onboardingRoute = '/onboarding';
```

### 4b. Cambiar destino de usuarios sin sesión que ya vieron onboarding

**Antes:**
```dart
        final target = onboardingStatus.isSeen ? loginRoute : onboardingRoute;
```

**Después:**
```dart
        final target = onboardingStatus.isSeen ? welcomeRoute : onboardingRoute;
```

---

## 5. Actualizar onboarding_screen.dart

Cambiar destino al terminar el carrusel: de `/login` a `/welcome`.

**Antes:**
```dart
  Future<void> _finish() async {
    await widget.statusStore.markSeen();
    if (mounted) context.go(AuthGuard.loginRoute);
  }
```

**Después:**
```dart
  Future<void> _finish() async {
    await widget.statusStore.markSeen();
    if (mounted) context.go(AuthGuard.welcomeRoute);
  }
```

---

## 6. Actualizar auth_guard_test.dart

Los tests que esperan `loginRoute` como destino para usuarios sin sesión + onboarding
visto ahora deben esperar `welcomeRoute`:

**Antes:**
```dart
      expect(result, AuthGuard.loginRoute);
```
(en el test "redirige a login si ya vio onboarding")

**Después:**
```dart
      expect(result, AuthGuard.welcomeRoute);
```

También en cualquier test que verifique que un usuario autenticado es redirigido
fuera de `/welcome` → `/home` (agregar un test).

**Test nuevo a agregar** al grupo existente:
```dart
    test('redirige a /home si está autenticado e intenta ir a /welcome', () {
      final result = guard.evaluate('/welcome', tAuthSuccess);
      expect(result, AuthGuard.homeRoute);
    });
```

---

## 7. Regenerar localizaciones

```powershell
cd "C:\Users\Usuario\Documents\DHC30\app-quesera\Frontend"
flutter gen-l10n
```

---

## Orden de aplicación

1. Agregar keys a los 3 `.arb` + `flutter gen-l10n`
2. Crear `welcome_panel.dart`
3. Crear `welcome_screen.dart`
4. Actualizar `auth_guard.dart` (publicRoutes + welcomeRoute + redirect)
5. Actualizar `app_router.dart` (import + GoRoute `/welcome`)
6. Actualizar `onboarding_screen.dart` (destino → `/welcome`)
7. Actualizar `auth_guard_test.dart` (expectativa → welcomeRoute + test nuevo)
8. `flutter analyze` + `flutter test`

## Flujo resultante

```
splash
 ├─ no session + first launch → onboarding → welcome
 ├─ no session + onboarding seen → welcome
 │    ├─ "Iniciar Sesión" → /login
 │    └─ "Registrarse" → /login (temporal, hasta que exista /register)
 └─ valid session → home
```

## Notas

- **Sin backdrop**: la pantalla welcome del design doc no usa círculos
  decorativos — el contraste blanco/navy del panel es el elemento visual.
- **Sin animación de entrada**: pantalla estática, coherente con el diseño
  aprobado (flat, minimal).
- **Botón Registrarse temporal**: navega a `/login` con un `TODO` en el código.
  Se creará la propuesta de `/register` por separado.
- **WelcomePanel reutilizable**: acepta cualquier widget como `actions` — si
  en el futuro se necesita un panel navy con otro contenido, se reutiliza.

## Auditoría post-implementación

Revisor (subagente): 0 críticos, 1 importante, 2 menores, 2 info.

- **Corregido**: numeración rota de comentarios en `auth_guard.dart` (saltaba
  "1." → "3.").
- **Documentado como decisión consciente** (no corregido): `OnboardingScreen`
  y `AuthGuard` consumen `IOnboardingStatusStore` (de `data/`) sin capa
  `domain/` intermedia — es un flag de UI, no una regla de negocio; agregar
  domain solo para esto sería sobre-ingeniería. Nota agregada en
  `i_onboarding_status_store.dart`.
- **Pendiente conocido**: botón "Registrarse" navega a `/login` (placeholder)
  hasta que exista la propuesta de `/register`.
