---
name: flutter-architecture
description: Stack tecnológico y estructura de carpetas Feature-First de Quesivo
triggers:
  - user
  - model
---

Referencia de arquitectura para crear archivos/features nuevas en **Quesivo** (Flutter,
Clean Architecture + S.O.L.I.D.).

## Stack e infraestructura

- **Framework:** Flutter (SDK `^3.8.1`), canal estable, lints estrictos (`flutter_lints` vía
  `analysis_options.yaml`).
- **Gestor de estado:** `flutter_bloc` (Cubits).
- **DI:** `get_it` (service locator manual en `lib/core/di/setup_di.dart`).
- **Red:** `dio` (implementación activa) + `http` (implementación alternativa disponible pero no
  activa). Todo pasa por interfaces (`INetworkService`).
- **Validación de dominio:** `formz` + Value Objects (`Email`, `Password`).
- **Errores funcionales:** `dartz` (`Either<Failure, SuccessType>`).
- **Navegación:** `go_router` con `AuthGuard` para protección de rutas.
- **Almacenamiento seguro:** `flutter_secure_storage`.
- **Conectividad:** `internet_connection_checker`.
- **i18n:** `flutter_localizations` + `intl`, diccionarios `.arb` en `lib/l10n/`.
- **Testing:** `flutter_test`, `bloc_test`, `mocktail`.
- **Plataformas destino:** android, ios (app móvil — único cliente del MVP, ver
  `../planeaciones/003-decision-plataforma-frontend-movil.md` en el backend). Los scaffolds
  `web/`, `windows/`, `linux/`, `macos/` existen pero no son target de producto.

No agregar dependencias nuevas sin verificar que resuelven un problema real y que no duplican una
ya existente en `pubspec.yaml`.

## Arquitectura de carpetas (Feature-First + Clean Architecture)

```
lib/
├── core/                # Infraestructura transversal, sin lógica de negocio de features
│   ├── bootstrap/       # AppBootstrap: orquesta el arranque
│   ├── constants/       # Environment (dart-defines)
│   ├── di/               # setup_di.dart (GetIt)
│   ├── localization/    # LocaleCubit
│   ├── logging/         # ILoggerService + implementaciones (Debug/Crashlytics)
│   ├── network/         # INetworkService, INetworkInfo, interceptors, api
│   ├── routes/          # AppRouter (GoRouter) + AuthGuard aislado
│   └── theme/           # AppTheme / AppColors (Material 3)
│
├── features/
│   └── <feature>/
│       ├── data/         # models, datasources (interfaces + implementations), repository impl, exceptions
│       ├── domain/       # entities, value_objects, repositories (interfaces), use_cases, failures
│       └── presentation/ # screens, widgets, cubit (state + cubit)
│
├── l10n/                 # Diccionarios .arb + clases generadas (NO editar los `app_localizations*.dart` a mano)
└── main.dart             # Punto de entrada, ultraligero
```

Al crear una feature nueva, replicar exactamente esta estructura dentro de `lib/features/<nombre>/`.

## Convenciones generales de código

- Nombres de archivos: `snake_case.dart`. Interfaces con prefijo `I` (ej. `IAuthRepository`,
  `INetworkService`).
- Implementaciones con sufijo `Impl` (ej. `AuthRepositoryImpl`, `DioNetworkServiceImpl`).
- Comentarios de cabecera que explican el principio SOLID aplicado son parte del estilo del
  proyecto (ver `setup_di.dart`, `environment.dart`); mantener ese patrón al escribir código nuevo
  en `core/` y `domain/`.
- Priorizar `const` siempre que sea posible.
- Todo registro nuevo de dependencia va en `lib/core/di/setup_di.dart`, respetando el orden por
  capas (Core Tools → Logging → Storage → Network → DataSources → Repositories → Use Cases →
  Cubits → Router).
