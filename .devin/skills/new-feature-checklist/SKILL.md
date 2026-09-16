---
name: new-feature-checklist
description: Orden exacto de archivos a crear al agregar un módulo/feature nuevo en Quesivo — del dominio a la pantalla, rutas, l10n, tests y design system
allowed-tools:
  - read
  - grep
  - glob
triggers:
  - user
  - model
---

Orden obligatorio para aterrizar un módulo nuevo (ej. Recepción,
Producción) en **Quesivo**. Es el equivalente frontend del
`new-endpoint-checklist` del backend. Antes de empezar: propuesta en
`propuestas/` aprobada (skill `code-proposals`) y skills `flutter-architecture`,
`solid-clean-architecture`, `ui-design-standard` cargadas.

## Estructura del feature

```
lib/features/<feature>/
├── domain/
│   ├── entities/        # entidad de negocio (Equatable)
│   ├── repositories/    # I<Feature>Repository (interfaz)
│   └── failures/        # <Feature>Failure (patrón AuthFailure)
├── data/
│   ├── models/          # <X>Model.fromJson ↔ entity
│   ├── datasources/     # I + impl remota/local
│   └── repositories/    # <Feature>RepositoryImpl (Either<Failure, T>)
├── application/         # use cases si el feature los justifica
└── presentation/
    ├── cubit/           # <Feature>Cubit + <Feature>State
    ├── screens/         # la pantalla del módulo
    └── widgets/         # piezas propias (o subcarpeta por diseño,
                         # skill file-size-refactoring)
```

## Orden de archivos

1. **Entity + failures** (domain) — modelar lo mínimo del MVP, no el
   esquema completo.
2. **Interfaz de repositorio** (domain) — `I<Feature>Repository`.
3. **Model + datasource** (data) — interfaz + impl; mocks de dev con gate
   `EnvType.dev` si el backend aún no existe (patrón
   `remote_auth_datasource_impl.dart`).
4. **RepositoryImpl** — `Either<Failure, T>`, check `networkInfo.isConnected`
   primero, mapeo excepción → failure (patrón `auth_repository_impl.dart`).
5. **Cubit + State** — estado Equatable; métodos que emiten, sin lógica de
   negocio.
6. **DI** — registrar en `setup_di.dart` (get_it).
7. **Screen** — shell de composición (patrón screens = shell de
   `bloc-patterns`); textos SOLO por l10n.
8. **Ruta** — constante completa en `AuthGuard.*Route` + `GoRoute` hijo con
   segmento RELATIVO dentro de su branch en `app_router.dart` +
   `CustomTransitions` (skill `navigation-routing`); el drawer apunta solo
   (su fila ya lleva `route:`).
9. **l10n** — keys nuevas en los 3 ARB + `flutter gen-l10n`
   (`i18n-workflow`).
10. **Tests** — `.spec`/test del cubit y del use case/repository
    (`testing-workflow`); los widgets solo si traen lógica de estado.
11. **yaml** — spec de la pantalla + changelog (`design-system-docs`).
12. **Checklist final** — `flutter analyze`, `flutter test`,
    `dart format` en archivos tocados (`production-checklist`).

## Reglas de cierre

- El `ModulePlaceholderScreen` de la ruta se reemplaza por la screen real
  en la MISMA ruta — el drawer y su `selected` no se tocan.
- Si el módulo agrega una pantalla hija (`/operaciones/recepcion/nueva`),
  la fila del menú sigue marcándose por el match `route/` — gratis.
- Ningún texto hardcodeado, ningún color quemado, ningún `dynamic`.
