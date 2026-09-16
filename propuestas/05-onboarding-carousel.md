# Propuesta: Onboarding — carrusel de presentación QUESIVO

**Estado: aplicada** — `flutter analyze` sin issues, `flutter test` 42/42.

Carrusel de presentación (3 slides) que se muestra **una sola vez**, antes de Login,
cuando la app se abre sin sesión y sin haberlo visto. No está definido en
`Design/quesivo-design-system.yaml` — hereda la identidad QUESIVO por las reglas de
continuidad visual (§5): fondo blanco, `QuesivoBackdrop`, íconos navy sobre círculo
`quesivoIconSurface`, dots navy/`quesivoBorder`, botón pill amarillo con texto navy.
Flat 2D, sin sombras ni degradados.

Flujo resultante:

```
splash ──(sin sesión + !hasSeenOnboarding)──▶ /onboarding ──▶ /login
       └─(sin sesión + ya visto)───────────▶ /login
       └─(con sesión)──────────────────────▶ /home
```

**Decisiones tomadas (defaults elegidos, revisables):**

- **Persistencia del flag**: `shared_preferences` (dep nueva). `flutter_secure_storage`
  quedó descartada: es para secretos (Keychain/EncryptedSharedPreferences — en iOS el
  keychain sobrevive al uninstall, y un flag "ya visto" no es un secreto).
- **Destino post-onboarding**: `/login` — la pantalla `welcome` del design doc aún no
  existe; cuando se construya se cambia una línea (`_finish()`).
- **Ilustraciones**: íconos Material outlined navy sobre círculo `#EEF2F7` (mismo patrón
  del `information_card` de forgot_password). No hay assets de ilustración en el repo.
- **Flag sincrónico**: el store se carga una vez en `AppBootstrap.init()` (antes de
  `runApp`), así `AuthGuard.evaluate()` sigue siendo síncrono — no se hace async.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | Dep nueva — `shared_preferences` (vía `flutter pub add`) |
| `lib/l10n/app_es.arb` | +9 claves |
| `lib/l10n/app_en.arb` | +9 claves |
| `lib/l10n/app_pt.arb` | +9 claves |
| `lib/features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart` | **Nuevo** — interfaz del flag |
| `lib/features/onboarding/data/datasources/implementations/shared_prefs_onboarding_status_store.dart` | **Nuevo** — impl SharedPreferences |
| `lib/features/onboarding/presentation/widgets/onboarding_page.dart` | **Nuevo** — slide individual |
| `lib/features/onboarding/presentation/widgets/onboarding_dots.dart` | **Nuevo** — indicador de página |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | **Nuevo** — pantalla del carrusel |
| `lib/core/routes/auth_guard.dart` | Actualización — ruta `/onboarding` pública + redirect por flag |
| `lib/core/routes/app_router.dart` | Actualización — `GoRoute /onboarding` |
| `lib/core/di/setup_di.dart` | Actualización — registro del store + nuevo arg del `AuthGuard` |
| `lib/core/bootstrap/app_bootstrap.dart` | Actualización — `await locator.allReady()` |
| `test/core/routes/auth_guard_test.dart` | Actualización — mock del store + 3 tests nuevos |

**i18n:** se agregan claves a los 3 `.arb` y hay que ejecutar `flutter gen-l10n`.
**DI:** registro nuevo en `setup_di.dart`. **Rutas:** `/onboarding` en `AppRouter` y
en `AuthGuard.publicRoutes`. **Test:** el constructor de `AuthGuard` cambia
(nuevo parámetro) — el spec existente se actualiza.

---

## 0. Dependencia nueva

```powershell
flutter pub add shared_preferences
```

## 1. app_es.arb / app_en.arb / app_pt.arb (existentes — +9 claves c/u)

**Rutas:** `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_pt.arb`

**Antes** (cierre de cada archivo):
```json
  "homeWelcomeMessage": "...",
  "@homeWelcomeMessage": { ... }
}
```

**Después — `app_es.arb`:**
```json
  "homeWelcomeMessage": "...",
  "@homeWelcomeMessage": { ... },
  "onboardingSkip": "Saltar",
  "onboardingNext": "Siguiente",
  "onboardingStart": "Comenzar",
  "onboardingSlide1Title": "Registra tu producción",
  "onboardingSlide1Description": "Controla la recepción de leche y la producción de tus quesos en un solo lugar.",
  "onboardingSlide2Title": "Gestiona tus productores",
  "onboardingSlide2Description": "Lleva precios, adelantos y liquidaciones de cada productor sin papeleo.",
  "onboardingSlide3Title": "Pagos sin complicaciones",
  "onboardingSlide3Description": "Genera liquidaciones y mantén el control de ventas, gastos e inventario."
}
```

**Después — `app_en.arb`:**
```json
  "onboardingSkip": "Skip",
  "onboardingNext": "Next",
  "onboardingStart": "Get Started",
  "onboardingSlide1Title": "Track your production",
  "onboardingSlide1Description": "Control milk reception and cheese production in one place.",
  "onboardingSlide2Title": "Manage your producers",
  "onboardingSlide2Description": "Track prices, advances and settlements for each producer without paperwork.",
  "onboardingSlide3Title": "Payments made simple",
  "onboardingSlide3Description": "Generate settlements and keep sales, expenses and inventory under control."
}
```

**Después — `app_pt.arb`:**
```json
  "onboardingSkip": "Pular",
  "onboardingNext": "Avançar",
  "onboardingStart": "Começar",
  "onboardingSlide1Title": "Registre sua produção",
  "onboardingSlide1Description": "Controle a recepção de leite e a produção de queijos em um só lugar.",
  "onboardingSlide2Title": "Gerencie seus produtores",
  "onboardingSlide2Description": "Controle preços, adiantamentos e liquidações de cada produtor sem papelada.",
  "onboardingSlide3Title": "Pagamentos sem complicações",
  "onboardingSlide3Description": "Gere liquidações e mantenha vendas, despesas e estoque sob controle."
}
```

> Luego ejecutar `flutter gen-l10n` — los `app_localizations*.dart` se regeneran solos.

## 2. i_onboarding_status_store.dart (archivo nuevo)

**Ruta:** `lib/features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart`

```dart
/// Fuente de verdad para saber si el usuario ya vio el onboarding.
///
/// SOLID (DIP): los consumidores (AuthGuard, OnboardingScreen) dependen de esta
/// interfaz, no de SharedPreferences. Se carga una sola vez al arrancar la app
/// (AppBootstrap → locator.allReady()) para que el guard pueda leer el flag de
/// forma síncrona en cada redirect.
abstract class IOnboardingStatusStore {
  /// `true` si el carrusel ya se completó o se saltó alguna vez.
  bool get isSeen;

  /// Persiste `isSeen = true` (al terminar o saltar el carrusel).
  Future<void> markSeen();
}
```

## 3. shared_prefs_onboarding_status_store.dart (archivo nuevo)

**Ruta:** `lib/features/onboarding/data/datasources/implementations/shared_prefs_onboarding_status_store.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../interfaces/i_onboarding_status_store.dart';

/// Persiste el flag `has_seen_onboarding` en SharedPreferences
/// (almacenamiento plano — no es un secreto, no va en secure storage).
class SharedPrefsOnboardingStatusStore implements IOnboardingStatusStore {
  static const _key = 'has_seen_onboarding';

  final SharedPreferences _prefs;
  bool _isSeen = false;

  SharedPrefsOnboardingStatusStore(this._prefs);

  /// Lee el flag persistido. Se invoca una sola vez desde el registro
  /// async en `setup_di.dart`, resuelto por `locator.allReady()` en bootstrap.
  Future<void> load() async {
    _isSeen = _prefs.getBool(_key) ?? false;
  }

  @override
  bool get isSeen => _isSeen;

  @override
  Future<void> markSeen() async {
    _isSeen = true;
    await _prefs.setBool(_key, true);
  }
}
```

## 4. onboarding_page.dart (archivo nuevo)

**Ruta:** `lib/features/onboarding/presentation/widgets/onboarding_page.dart`

Slide individual del carrusel: ícono navy sobre círculo `quesivoIconSurface`
(patrón del `information_card` del design doc), título navy y descripción secundaria.

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Slide individual del carrusel de onboarding: ícono + título + descripción.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: const BoxDecoration(
              color: AppColors.quesivoIconSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: AppColors.quesivoNavy),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 16),
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

## 5. onboarding_dots.dart (archivo nuevo)

**Ruta:** `lib/features/onboarding/presentation/widgets/onboarding_dots.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Indicador de página del carrusel: dot activo alargado navy,
/// inactivos como círculos `quesivoBorder`.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.quesivoNavy
                : AppColors.quesivoBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
```

## 6. onboarding_screen.dart (archivo nuevo)

**Ruta:** `lib/features/onboarding/presentation/screens/onboarding_screen.dart`

`PageView` de 3 slides sobre `QuesivoBackdrop`. "Saltar" (arriba derecha) y el botón
pill amarillo terminan el flujo: `markSeen()` + `context.go('/login')`. Sin Cubit —
es UI pura con `PageController` local; el store llega **inyectado por constructor**
(DIP — resuelto desde el locator en `app_router.dart`, la pantalla no lo conoce).

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tercer_tiempo/l10n/app_localizations.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../data/datasources/interfaces/i_onboarding_status_store.dart';
import '../widgets/onboarding_dots.dart';
import '../widgets/onboarding_page.dart';

/// Onboarding — carrusel de presentación QUESIVO (no definido en
/// quesivo-design-system.yaml; hereda la identidad por continuidad visual §5).
///
/// Se muestra una sola vez: al terminar ("Comenzar") o saltar ("Saltar") se
/// persiste `IOnboardingStatusStore.markSeen()` y se navega a /login.
/// Sin Cubit: es UI pura con PageController local — el flag lo maneja el store.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.statusStore});

  final IOnboardingStatusStore statusStore;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _icons = [
    Icons.water_drop_outlined, // recepción de leche / producción
    Icons.groups_outlined, // productores
    Icons.payments_outlined, // liquidaciones / pagos
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.statusStore.markSeen();
    if (mounted) context.go(AuthGuard.loginRoute);
  }

  void _next() {
    if (_currentPage == _icons.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final titles = [
      l10n.onboardingSlide1Title,
      l10n.onboardingSlide2Title,
      l10n.onboardingSlide3Title,
    ];
    final descriptions = [
      l10n.onboardingSlide1Description,
      l10n.onboardingSlide2Description,
      l10n.onboardingSlide3Description,
    ];
    final isLast = _currentPage == _icons.length - 1;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
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
  }
}
```

> **Nota `physics`:** con `disableAnimations` el swipe se bloquea
> (`NeverScrollableScrollPhysics`) y la navegación queda solo por botones —
> consistente con el resto de la app que neutraliza animaciones.

## 7. auth_guard.dart (existente — actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

**Antes:**
```dart
class AuthGuard {
  final ILoggerService logger;

  AuthGuard(this.logger);

  // Lista declarativa de rutas abiertas a todo público sin sesión
  static const List<String> publicRoutes = ['/login', '/forgot-password'];

  static const String splashRoute = '/splash';
  static const String homeRoute = '/home';
  static const String loginRoute = '/login';
```

**Después:**
```dart
class AuthGuard {
  final ILoggerService logger;
  final IOnboardingStatusStore onboardingStatus;

  AuthGuard(this.logger, this.onboardingStatus);

  // Lista declarativa de rutas abiertas a todo público sin sesión
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

**Antes:**
```dart
    if (authState is AuthInitial || authState is AuthError) {
      if (!isGoingToPublicRoute) {
        logger.warning(
          'AuthGuard -> Acción: $loginRoute (Acceso restringido a ruta protegida)',
        );
        return loginRoute;
      }
    }
```

**Después:**
```dart
    if (authState is AuthInitial || authState is AuthError) {
      if (!isGoingToPublicRoute) {
        // Sin sesión: si nunca vio el onboarding, esa es su primera parada.
        final target = onboardingStatus.isSeen ? loginRoute : onboardingRoute;
        logger.warning(
          'AuthGuard -> Acción: $target (Acceso restringido a ruta protegida)',
        );
        return target;
      }
    }
```

**Antes (imports):**
```dart
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../logging/interfaces/i_logger_service.dart';
```

**Después (imports):**
```dart
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../logging/interfaces/i_logger_service.dart';
```

## 8. app_router.dart (existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Antes:**
```dart
import '../../features/splash/presentation/screens/splash_screen.dart';
```

**Después:**
```dart
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
```

**Antes:**
```dart
      GoRoute(
        path: '/login',
```

**Después:**
```dart
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => CustomTransitions.fade(
          context: context,
          state: state,
          // El store se resuelve acá (DIP) — la pantalla no conoce el locator.
          child: OnboardingScreen(
            statusStore: locator<IOnboardingStatusStore>(),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
```

## 9. setup_di.dart (existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
```

**Después:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../../features/onboarding/data/datasources/implementations/shared_prefs_onboarding_status_store.dart';
```

**Antes (sección Storage):**
```dart
  // Storage
  locator.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
```

**Después:**
```dart
  // Storage
  locator.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // El flag "onboarding ya visto" (IOnboardingStatusStore) NO se registra acá:
  // SharedPreferences se inicializa async, así que se crea cargado y se
  // registra como singleton síncrono en AppBootstrap — un get() sobre una
  // registración async sin resolver devuelve null en runtime.
```

> Requiere agregar `import 'package:shared_preferences/shared_preferences.dart';`
> junto al import de `flutter_secure_storage`.

**Antes (sección Router):**
```dart
  locator.registerLazySingleton<AuthGuard>(
    () => AuthGuard(locator<ILoggerService>()),
  );
```

**Después:**
```dart
  locator.registerLazySingleton<AuthGuard>(
    () => AuthGuard(
      locator<ILoggerService>(),
      locator<IOnboardingStatusStore>(),
    ),
  );
```

## 10. app_bootstrap.dart (existente — actualización)

**Ruta:** `lib/core/bootstrap/app_bootstrap.dart`

**Antes:**
```dart
    // 2. Inicializar la Inyección de Dependencias
    setupDI();
```

**Después:**
```dart
    // 2. Inicializar la Inyección de Dependencias
    setupDI();

    // Flag "onboarding ya visto": SharedPreferences se inicializa async, así
    // que el store se crea ya cargado y se registra como singleton listo —
    // el AuthGuard puede leer isSeen de forma síncrona en el primer redirect.
    final onboardingStatus = SharedPrefsOnboardingStatusStore(
      await SharedPreferences.getInstance(),
    );
    await onboardingStatus.load();
    locator.registerSingleton<IOnboardingStatusStore>(onboardingStatus);
```

## 11. auth_guard_test.dart (existente — actualización)

**Ruta:** `test/core/routes/auth_guard_test.dart`

**Antes:**
```dart
import 'package:tercer_tiempo/core/logging/interfaces/i_logger_service.dart';
import 'package:tercer_tiempo/core/routes/auth_guard.dart';
import 'package:tercer_tiempo/features/auth/domain/entities/user.dart';
import 'package:tercer_tiempo/features/auth/presentation/cubit/auth_state.dart';

class MockLoggerService extends Mock implements ILoggerService {}

void main() {
  late MockLoggerService mockLogger;
  late AuthGuard authGuard;
```

**Después:**
```dart
import 'package:tercer_tiempo/core/logging/interfaces/i_logger_service.dart';
import 'package:tercer_tiempo/core/routes/auth_guard.dart';
import 'package:tercer_tiempo/features/auth/domain/entities/user.dart';
import 'package:tercer_tiempo/features/auth/presentation/cubit/auth_state.dart';
import 'package:tercer_tiempo/features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';

class MockLoggerService extends Mock implements ILoggerService {}

class MockOnboardingStatusStore extends Mock
    implements IOnboardingStatusStore {}

void main() {
  late MockLoggerService mockLogger;
  late MockOnboardingStatusStore mockOnboardingStatus;
  late AuthGuard authGuard;
```

**Antes (setUp):**
```dart
    // Ahora AuthGuard recibe su dependencia por constructor (DIP real),
    // sin pasar por el Service Locator ni por tipos de go_router.
    authGuard = AuthGuard(mockLogger);
```

**Después:**
```dart
    // Por defecto el onboarding ya fue visto (los tests históricos
    // esperan redirect a /login); los casos first-run lo sobrescriben.
    when(() => mockOnboardingStatus.isSeen).thenReturn(true);

    // Ahora AuthGuard recibe sus dependencias por constructor (DIP real),
    // sin pasar por el Service Locator ni por tipos de go_router.
    authGuard = AuthGuard(mockLogger, mockOnboardingStatus);
```

Y en `setUp` agregar `mockOnboardingStatus = MockOnboardingStatusStore();` junto a
`mockLogger = MockLoggerService();`.

**Tests nuevos** (agregar al final del `group('AuthGuard.evaluate')`):

```dart
    test('primera vez (!isSeen) sin sesión en ruta protegida, '
        'redirige a /onboarding', () {
      when(() => mockOnboardingStatus.isSeen).thenReturn(false);

      final result = authGuard.evaluate(
        AuthGuard.homeRoute,
        const AuthInitial(),
      );

      expect(result, AuthGuard.onboardingRoute);
    });

    test('primera vez (!isSeen) sin sesión en /splash, '
        'redirige a /onboarding', () {
      when(() => mockOnboardingStatus.isSeen).thenReturn(false);

      final result = authGuard.evaluate(
        AuthGuard.splashRoute,
        const AuthInitial(),
      );

      expect(result, AuthGuard.onboardingRoute);
    });

    test('sin sesión ya en /onboarding (ruta pública), no redirige', () {
      when(() => mockOnboardingStatus.isSeen).thenReturn(false);

      final result = authGuard.evaluate(
        AuthGuard.onboardingRoute,
        const AuthInitial(),
      );

      expect(result, isNull);
    });
```

---

## Orden de aplicación

1. `flutter pub add shared_preferences`.
2. Agregar las 9 claves a `app_es.arb`, `app_en.arb`, `app_pt.arb` y correr
   `flutter gen-l10n`.
3. Crear `i_onboarding_status_store.dart` + `shared_prefs_onboarding_status_store.dart`.
4. Crear `onboarding_page.dart` + `onboarding_dots.dart` + `onboarding_screen.dart`.
5. Actualizar `auth_guard.dart` (import, constructor, `publicRoutes`, redirect).
6. Actualizar `app_router.dart` (import + `GoRoute /onboarding`).
7. Actualizar `setup_di.dart` (import de `shared_preferences`, registro async del
   store, nuevo arg de `AuthGuard`).
8. Actualizar `app_bootstrap.dart` (`await locator.allReady()`).
9. Actualizar `auth_guard_test.dart` (mock del store + tests nuevos).
10. `flutter analyze` y `flutter test`; verificar en emulador: primera apertura
    muestra el carrusel, "Saltar"/"Comenzar" llevan a login, segunda apertura va
    directo a login.

## Notas

- **Sobre el flag en tests e2e/dev**: si se necesita resetear el flag para probar,
  basta desinstalar la app o borrar datos — no se agrega UI de reset (no es MVP).
- **`welcome` pendiente**: cuando se construya la pantalla welcome del design doc,
  el destino en `_finish()` cambia de `AuthGuard.loginRoute` a la ruta de welcome
  y el guard agregaría esa ruta a `publicRoutes`.
- **Tipografía**: los `TextStyle` no fijan `fontFamily` — la migración a Poppins es
  una propuesta aparte (aún no hay fuentes en `pubspec.yaml`); mientras tanto se usa
  la familia por defecto, igual que el resto de pantallas actuales.
