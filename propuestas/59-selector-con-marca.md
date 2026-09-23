# Propuesta: Selector con identidad de marca (rediseño visual)

El usuario reportó que el selector (`HomeTab` con `enteredOrg=false`) se ve
"muy genérico y feo" y pidió: usar las skills de diseño, mejorar toda la
pantalla y quitar el título "Inicio" en ese estado.

Dirección: el selector es el primer instante post-auth — merece el lenguaje
del splash/welcome. Elemento firma: la **porción de queso con huecos**
(`DrawerBrandDecoration`) asomando de cada card — mismo recurso del header
navy y del drawer. Navy queda reservado al hero activo; blanco + queso +
pill amarillo = "entrá".

Nada de l10n nuevo: se reusa `personalGreeting` ("Hola, {name}") y
`chooseQueseraHint`, ambas ya existentes (`personalGreeting` quedó huérfana
de §55).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/queseras/presentation/widgets/quesera_card.dart` | Rediseño completo de la card "Entrar" (queso peeking + chip de rol + pill CTA amarillo) |
| `lib/features/home/presentation/screens/home_tab.dart` | En el selector: saludo personal reemplaza al `TabPageTitle` "Inicio" + hint suelto |
| `test/features/queseras/presentation/widgets/quesera_hero_carousel_test.dart` | Actualizar el grupo §58 al nuevo markup del selector |
| `Design/quesivo-design-system.yaml` | Spec del selector + bump `1.18.0` |

---

## 1. quesera_card.dart (archivo existente — actualización)

**Ruta:** `lib/features/queseras/presentation/widgets/quesera_card.dart`

La card pasa de "fila con ícono + texto + chevron" a una card con identidad:
queso amarillo con huecos asomando por la esquina superior-derecha (recurso
de marca ya usado en header/drawer), nombre navy, chip de rol en tinte navy
suave y pill amarillo full-width "Entrar". El ícono `business_outlined` se
elimina — era lo más genérico de la card. El tap sigue siendo toda la card;
el pill es affordance visual, no un botón anidado. `loading` muestra el
`QuesivoLoader` dentro del pill.

**Antes:** el `build` completo actual (Material > InkWell > Container con
Row[icono círculo, Column nombre+rol, "Entrar" + chevron]).

**Después:**

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../auth/domain/entities/organization_summary.dart';
import '../../../shell/presentation/widgets/drawer/drawer_brand_decoration.dart';

/// Card "Entrar" del `QueseraHeroCarousel` (§56 → restilo §59): blanca con
/// borde, la porción de queso de marca asomando por la esquina
/// superior-derecha (misma técnica del ShellHeader y el drawer), nombre
/// navy, chip de rol y pill amarillo full-width como CTA. Navy queda
/// reservado al hero activo — esta card siempre invita a entrar.
/// `loading` muestra spinner dentro del pill y el tap queda bloqueado
/// (`enabled`).
class QueseraCard extends StatelessWidget {
  const QueseraCard({
    super.key,
    required this.organization,
    required this.loading,
    required this.enabled,
    required this.enterLabel,
    required this.roleLabel,
    required this.onTap,
  });

  final OrganizationSummary organization;
  final bool loading;
  final bool enabled;
  final String enterLabel;
  final String roleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.quesivoWhite,
      borderRadius: BorderRadius.circular(20),
      // Clip antiAlias: recorta la porción de queso que asoma por la
      // esquina (misma técnica del header/drawer).
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.quesivoBorder),
          ),
          child: Stack(
            children: [
              // Elemento firma: porción de queso asomando por la esquina.
              const Positioned(
                top: -44,
                right: -38,
                child: DrawerBrandDecoration(
                  diameter: 110,
                  color: AppColors.quesivoYellow,
                  withCheeseHoles: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.quesivoNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Chip de rol — tinte navy suave (el amarillo queda
                    // para el CTA, una sola señal de acción).
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.quesivoNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.quesivoNavy,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Pill CTA full-width — affordance visual del tap que
                    // ya cubre toda la card (no es un botón anidado).
                    Container(
                      height: 44,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.quesivoYellow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: loading
                          ? const QuesivoLoader(size: 20)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  enterLabel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.quesivoNavy,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.quesivoNavy,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 2. home_tab.dart (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/home_tab.dart`

En el selector el `TabPageTitle` "Inicio" + el hint suelto se reemplazan por
el saludo personal + el hint como subtítulo (jerarquía de primer instante,
no de tab). Con quesera activa el título "Inicio" vuelve — el layout de
quesera no cambia. El padding inferior del hint (16px) se absorbe en el gap
de 20px que ya separa título del carousel.

**Antes:**

```dart
    final enteredOrg = context.select<AuthCubit, bool>(
      (cubit) =>
          cubit.state is AuthSuccess && (cubit.state as AuthSuccess).enteredOrg,
    );
```

```dart
      children: [
        TabPageTitle(title: l10n.navHome),
        const SizedBox(height: 20),
        const QueseraHeroCarousel(),
        if (!enteredOrg) ...[
          const SizedBox(height: 16),
          Text(
            l10n.chooseQueseraHint,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        const HomeQuickActions(),
        const SizedBox(height: 28),
        const HomeRecentActivity(),
      ],
```

**Después:**

```dart
    // §58/§59 — mismo select de enteredOrg, más el nombre para el saludo
    // del selector (primer nombre — "Hola, Juan").
    final (enteredOrg, userName) = context.select<AuthCubit, (bool, String)>(
      (cubit) => cubit.state is AuthSuccess
          ? (
              (cubit.state as AuthSuccess).enteredOrg,
              (cubit.state as AuthSuccess).user.name,
            )
          : (false, ''),
    );
```

```dart
      children: [
        // §59 — el selector abre con saludo personal (primer instante de
        // marca, como el splash), no con el título del tab. Con quesera
        // activa vuelve "Inicio".
        if (enteredOrg)
          TabPageTitle(title: l10n.navHome)
        else ...[
          Text(
            l10n.personalGreeting(name: userName.trim().split(' ').first),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chooseQueseraHint,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ],
        const SizedBox(height: 20),
        const QueseraHeroCarousel(),
        const SizedBox(height: 24),
        const HomeQuickActions(),
        const SizedBox(height: 28),
        const HomeRecentActivity(),
      ],
```

Doc comment de la clase: actualizar — §59 el selector tiene composición
propia (saludo + hint como subtítulo + carousel con cards de marca).

## 3. quesera_hero_carousel_test.dart (archivo existente — actualización)

**Ruta:** `test/features/queseras/presentation/widgets/quesera_hero_carousel_test.dart`

El grupo `'HomeTab — layout único (§58)'` se actualiza al nuevo markup:

- `'sin entrar…'`: ahora espera `find.text('Hola, Ana')` (saludo con el
  primer nombre del `tPersonalUser`) + `chooseQueseraHint` ("Elegí tu
  quesera para entrar") + quick actions + actividad; `'Inicio'` ausente.
- `'con org entrada…'`: sigue esperando `'Inicio'` + sin hint; sumar
  `find.text('Hola, Ana')` ausente.

Además, la card nueva cambia su markup: si algún test existente busca el
texto "Entrar" junto a `chevron_right`, ajustar al nuevo pill
(`Icons.arrow_forward_rounded`).

## 4. quesivo-design-system.yaml (archivo existente — actualización)

**Ruta:** `../Design/quesivo-design-system.yaml` (raíz del repo)

- `metadata.version` → `1.18.0`.
- `pages.home`: el `personal_mode` / spec del selector refleja la
  composición propia (saludo `personalGreeting` 26px w800 navy +
  `chooseQueseraHint` como subtítulo; sin `TabPageTitle` en ese estado).
- `pages.queseras` → spec de `QueseraCard`: documentar queso
  `DrawerBrandDecoration` (diameter 110, top -44 right -38,
  withCheeseHoles), chip de rol navy 8%, pill amarillo 44px radius 12 con
  label + `arrow_forward_rounded`, y la regla de color (navy = activa,
  blanco+queso = entrar).
- Changelog `1.18.0` con el rediseño del selector.

---

## Orden de aplicación

1. `quesera_card.dart` — rediseño de la card.
2. `home_tab.dart` — saludo + hint integrados, título condicional.
3. `quesera_hero_carousel_test.dart` — ajustar expectativas.
4. `quesivo-design-system.yaml` — spec + version.
5. `flutter analyze` + `flutter test`.
6. Validación visual del usuario → `revisor` → commit.

Sin pasos de `gen-l10n`, DI ni rutas.
