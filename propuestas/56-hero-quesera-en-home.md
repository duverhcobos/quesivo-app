# Propuesta: Hero de quesera en el home — selector siempre visible

Corrige el diseño de la §55 tras la validación visual del usuario: la
selección de quesera **no vive en una pantalla aparte** — vive en el
hero del tab Inicio, siempre visible. El usuario debe saber en qué
quesera está parado sin abrir ningún menú.

## Diseño

- `/home` reemplaza `HomeHeroCard` por **`QueseraHeroCarousel`**
  (PageView en la zona del hero):
  - **Card activa** (página 0): navy — nombre de la quesera + rol +
    badge "Actual" + la fila de KPIs del hero actual.
  - **Cards no-activas**: blancas — nombre + rol + "Entrar" + chevron.
  - `viewportFraction 0.88` cuando hay >1 → el borde de la siguiente
    card asoma = el slide se descubre solo. Dots indicator abajo.
  - Tap en card activa → nada. Tap en otra → `select-organization` +
    `refreshSession` → la org nueva queda activa (la PageView vuelve a
    la página 0 con el orden recomputado). **Nunca** se cambia de
    quesera por swipe — el swipe solo navega el carousel.
- **Modo elección** (token personal, `organizationId == null`): la misma
  `/home` — carousel con todas las queseras como cards "Entrar" +
  título "Tus queseras" + hint, `QuesivoNavBar` oculta, drawer reducido
  (identidad + logout, sin módulos — toda ruta de módulo redirige a
  /home igual).
- **Auto-entrada**: si `/me` devuelve **exactamente 1** quesera y no hay
  org activa, se dispara `select-organization` automáticamente al montar
  — el usuario de una sola quesera entra directo como antes, sin tap
  extra. Con ≥2 quedan las cards esperando el tap.
- Se **elimina** `/queseras` (ruta + `QueserasScreen`) y el ítem
  "Cambiar quesera" del drawer — el carousel los reemplaza.

## Reuso de la §55 (ya implementada, sin commitear)

Se conservan tal cual: `OrganizationSummary`, `User.organizations`,
`OrganizationSessionModel`, `selectOrganization` (datasource/repo/use
case), `AuthCubit.refreshSession`/`_loadSession`, persistencia de
`organizations` en storage, `QueseraSelectionCubit`/`State`,
`role_label_for.dart`, y las claves l10n ya creadas.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/queseras/presentation/screens/queseras_screen.dart` | **Eliminar** |
| `lib/features/queseras/presentation/widgets/quesera_hero_carousel.dart` | Nuevo — PageView + dots + auto-enter |
| `lib/features/queseras/presentation/widgets/quesera_hero_card.dart` | Nuevo — card activa navy (org + rol + KPIs) |
| `lib/features/queseras/presentation/widgets/quesera_card.dart` | Restilo → card "Entrar" (blanca) |
| `lib/features/home/presentation/screens/home_tab.dart` | Hero → carousel + modo elección |
| `lib/features/home/presentation/widgets/home_hero_card.dart` | **Eliminar** (absorbida por quesera_hero_card) |
| `lib/features/shell/presentation/widgets/main_layout.dart` | Ocultar nav bar sin org |
| `lib/features/shell/presentation/widgets/quesivo_drawer.dart` | Subtítulo sin org → hint |
| `lib/features/shell/presentation/widgets/shell_header.dart` | Ídem |
| `lib/features/shell/presentation/widgets/drawer/drawer_menu_list.dart` | Quitar "Cambiar quesera"; modo personal = solo logout |
| `lib/core/routes/auth_guard.dart` | `queserasRoute` → eliminar; sin org → `/home` |
| `lib/core/routes/app_router.dart` | Quitar `GoRoute /queseras` |
| `lib/l10n/app_{es,en,pt}.arb` | + `chooseQueseraHint`, `queseraEnterCta` |
| `test/` | Actualizar specs de guard/screen; tests del carousel |
| `../Design/quesivo-design-system.yaml` | Reescribir spec `queseras` → hero carousel; bump 1.15.0 |

---

## 1. Eliminar `queseras_screen.dart`

**Ruta:** `lib/features/queseras/presentation/screens/queseras_screen.dart`

Borrar el archivo. Su rol lo absorbe `HomeTab` en modo elección.

## 2. `quesera_hero_card.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/widgets/quesera_hero_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/organization_summary.dart';

/// Card de la quesera ACTIVA dentro del `QueseraHeroCarousel` (§56):
/// hero navy con el nombre de la quesera + chip de rol + badge "Actual"
/// + la fila de KPIs del día (mismos placeholders del HomeHeroCard que
/// reemplaza — datos reales en F5). Ocupa la página 0 del PageView.
class QueseraHeroCard extends StatelessWidget {
  const QueseraHeroCard({super.key, required this.organization});

  final OrganizationSummary organization;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.quesivoNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  organization.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quesivoWhite,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.quesivoYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.queseraActiveBadge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.quesivoNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.roleLabelFor(organization.role),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.quesivoWhite.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          // Fila de KPIs — mismo contenido del HomeHeroCard saliente
          // (placeholders hasta F5). Reusar aquí los mismos tres
          // indicadores con su maquetación actual.
          Row(
            children: [
              // ... mismos KPIs del HomeHeroCard (litros / recepciones /
              // saldo) — ver home_hero_card.dart para los valores y
              // estilos exactos a trasladar.
            ],
          ),
        ],
      ),
    );
  }
}
```

**Nota para el implementador:** trasladar la fila de KPIs literal desde
`home_hero_card.dart` (etiqueta "Hoy" + los 3 indicadores con sus estilos
actuales). Si `HomeHeroCard` tiene widgets extraíbles reutilizables,
reusarlos en vez de duplicar.

## 3. `quesera_card.dart` (archivo existente — restilo)

**Ruta:** `lib/features/queseras/presentation/widgets/quesera_card.dart`

La card pasa a ser exclusivamente la variante **"Entrar"** (quesera no
activa): quitar `isActive`/`activeLabel` del widget (el badge "Actual"
vive ahora solo en `QueseraHeroCard`), agregar el CTA textual
`l10n.queseraEnterCta` junto al chevron. Resto igual (ícono navy 8%,
nombre 16px w600 `quesivoDarkText`, rol secondary, `QuesivoLoader`
cuando `loading`, tap bloqueado cuando `!enabled`).

```dart
// Firma resultante:
const QueseraCard({
  super.key,
  required this.organization,
  required this.loading,
  required this.enabled,
  required this.enterLabel,   // l10n.queseraEnterCta
  required this.roleLabel,
  required this.onTap,
});
```

## 4. `quesera_hero_carousel.dart` (archivo nuevo)

**Ruta:** `lib/features/queseras/presentation/widgets/quesera_hero_carousel.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/organization_summary.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/quesera_selection_cubit.dart';
import '../cubit/quesera_selection_state.dart';
import 'quesera_card.dart';
import 'quesera_hero_card.dart';

/// Selector de quesera en la zona del hero del Inicio (§56) — el "en
/// qué quesera estoy" siempre a la vista, sin menús.
///
/// - 1 quesera + org activa → una sola `QueseraHeroCard` navy a todo
///   ancho (PageView de una página — sin dots, sin peek).
/// - N queseras → `viewportFraction 0.88`: el borde de la siguiente
///   card asoma a la derecha y los dots marcan la posición — el slide
///   se descubre solo. Página 0 = la activa (hero navy); las demás son
///   `QueseraCard` "Entrar". El swipe NUNCA cambia de quesera — solo
///   el tap sobre una card no-activa dispara `select-organization`.
/// - Sin org activa (token personal): todas son `QueseraCard` "Entrar";
///   con exactamente 1 se auto-selecciona al montar (login directo a
///   su única quesera).
///
/// El cubit es factory y vive acá — nace y muere con el carousel.
class QueseraHeroCarousel extends StatefulWidget {
  const QueseraHeroCarousel({super.key});

  @override
  State<QueseraHeroCarousel> createState() => _QueseraHeroCarouselState();
}

class _QueseraHeroCarouselState extends State<QueseraHeroCarousel> {
  static const double _cardHeight = 148;

  /// 0.88 → la siguiente card asoma ~12% a la derecha: el slide se
  /// descubre solo. Solo aplica cuando hay >1 quesera (con 1 se
  /// renderiza la card a ancho completo, sin PageView).
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _page = 0;
  bool _autoSelectAttempted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (orgs, activeOrgId) = context
        .select<AuthCubit, (List<OrganizationSummary>, String?)>(
          (cubit) => cubit.state is AuthSuccess
              ? (
                  (cubit.state as AuthSuccess).user.organizations,
                  (cubit.state as AuthSuccess).user.organizationId,
                )
              : (const <OrganizationSummary>[], null),
        );

    // La activa primero; el resto detrás, en el orden del /me.
    final ordered = [...orgs]
      ..sort((a, b) {
        if (a.id == activeOrgId) return -1;
        if (b.id == activeOrgId) return 1;
        return 0;
      });

    return BlocProvider(
      create: (_) => locator<QueseraSelectionCubit>(),
      child: BlocConsumer<QueseraSelectionCubit, QueseraSelectionState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, selection) {
          // Auto-entrada: token personal + exactamente 1 quesera →
          // entra sola, sin tap. Solo una vez por montaje.
          if (!_autoSelectAttempted &&
              activeOrgId == null &&
              ordered.length == 1 &&
              !selection.isSelecting) {
            _autoSelectAttempted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.read<QueseraSelectionCubit>().select(
                  ordered.first.id,
                );
              }
            });
          }

          // Defensivo (el gate 065 hace que no ocurra, pero el estado
          // vacío no debe crashear): sin queseras → mensaje centrado.
          if (ordered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  l10n.noQueserasAvailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.quesivoTextSecondary,
                  ),
                ),
              ),
            );
          }

          final multi = ordered.length > 1;

          // 1 sola quesera → card única a ancho completo, sin PageView
          // ni dots (viewportFraction 0.88 la dejaría al 88%).
          if (!multi) {
            final org = ordered.first;
            final isActive = org.id == activeOrgId;
            return SizedBox(
              height: _cardHeight,
              child: isActive
                  ? QueseraHeroCard(organization: org)
                  : QueseraCard(
                      organization: org,
                      loading: selection.selectingId == org.id,
                      enabled: !selection.isSelecting,
                      enterLabel: l10n.queseraEnterCta,
                      roleLabel: l10n.roleLabelFor(org.role),
                      onTap: () => context
                          .read<QueseraSelectionCubit>()
                          .select(org.id),
                    ),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: _cardHeight,
                child: PageView.builder(
                  controller: _controller,
                  // padEnds false: el peek se ve solo a la derecha —
                  // la página 0 arranca pegada al margen de la pantalla.
                  padEnds: false,
                  itemCount: ordered.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final org = ordered[i];
                    final isActive = org.id == activeOrgId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: isActive
                          ? QueseraHeroCard(organization: org)
                          : QueseraCard(
                              organization: org,
                              loading: selection.selectingId == org.id,
                              enabled: !selection.isSelecting,
                              enterLabel: l10n.queseraEnterCta,
                              roleLabel: l10n.roleLabelFor(org.role),
                              onTap: () => context
                                  .read<QueseraSelectionCubit>()
                                  .select(org.id),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < ordered.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _page == i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? AppColors.quesivoNavy
                              : AppColors.quesivoBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
```

**Ajuste del PageController al construir:** para el peek de §56 el
controller debe crearse con `viewportFraction` — declararlo como

```dart
final PageController _controller = PageController(
  viewportFraction: 0.88,
);
```

solo cuando hay >1 quesera. Como `orgs` se conoce en build, crear el
controller lazily en `didChangeDependencies`/build guardando la fracción
usada, o usar dos widgets: `PageView` con `viewportFraction` calculado
en cada build (`PageController` no admite cambiar la fracción en caliente
— recrear el controller cuando cambie `multi`, o fijar siempre 0.88 y
que con 1 sola card el padEnd la deje a ancho completo igual). Decisión
del implementador; el requisito visual: 1 card = ancho completo, >1 =
peek de la siguiente.

## 5. `home_tab.dart` (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/home_tab.dart`

**Antes:**
```dart
      children: [
        TabPageTitle(title: l10n.navHome),
        const SizedBox(height: 20),
        const HomeHeroCard(),
        const SizedBox(height: 24),
        const HomeQuickActions(),
        const SizedBox(height: 28),
        const HomeRecentActivity(),
      ],
```

**Después:**
```dart
      children: [
        // §56 — sin org activa el tab es el selector de quesera: título
        // + carousel + hint; con org es el Inicio de siempre.
        TabPageTitle(
          title: hasOrgContext ? l10n.navHome : l10n.myQueserasTitle,
        ),
        const SizedBox(height: 20),
        const QueseraHeroCarousel(),
        if (hasOrgContext) ...[
          const SizedBox(height: 24),
          const HomeQuickActions(),
          const SizedBox(height: 28),
          const HomeRecentActivity(),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            l10n.chooseQueseraHint,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ],
      ],
```

Arriba del `ListView`, leer el flag:

```dart
    final hasOrgContext = context.select<AuthCubit, bool>(
      (cubit) =>
          cubit.state is AuthSuccess &&
          (cubit.state as AuthSuccess).user.organizationId != null,
    );
```

Imports: `flutter_bloc`, `auth_cubit`/`auth_state`, `app_colors`,
`quesera_hero_carousel.dart`. Quitar el de `home_hero_card.dart`.

## 6. Eliminar `home_hero_card.dart`

**Ruta:** `lib/features/home/presentation/widgets/home_hero_card.dart`

Borrar — su fila de KPIs se traslada a `QueseraHeroCard` (paso 2).
Verificar que no queden otros imports antes de borrar.

## 7. `main_layout.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/main_layout.dart`

Ocultar el nav bar sin contexto de org:

**Antes:**
```dart
          const Positioned(top: 0, left: 0, right: 0, child: ShellHeader()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: QuesivoNavBar(navigationShell: navigationShell),
          ),
```

**Después:**
```dart
          const Positioned(top: 0, left: 0, right: 0, child: ShellHeader()),
          // §56 — sin org activa (token personal, modo elección) el nav
          // de módulos no aplica: toda ruta de módulo redirige a /home.
          if (hasOrgContext)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: QuesivoNavBar(navigationShell: navigationShell),
            ),
```

Con el flag arriba del `build` (mismo `select` del HomeTab). Además el
`endDrawer` puede quedarse — su contenido ya se reduce en el paso 10.

## 8. `shell_header.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/shell_header.dart`

**Antes:**
```dart
    final trimmedOrgName = organizationName?.trim() ?? '';
    final displayOrgName = trimmedOrgName.isNotEmpty
        ? trimmedOrgName
        : l10n.orgName;
```

**Después:**
```dart
    final trimmedOrgName = organizationName?.trim() ?? '';
    // §56 — sin org activa (token personal) la segunda línea invita a
    // elegir quesera en vez del placeholder "Mi quesera".
    final displayOrgName = trimmedOrgName.isNotEmpty
        ? trimmedOrgName
        : l10n.chooseQueseraHint;
```

## 9. `quesivo_drawer.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/quesivo_drawer.dart`

Mismo cambio de fallback en `displayOrgName` (`l10n.orgName` →
`l10n.chooseQueseraHint`). Además pasar a `DrawerMenuList` un flag
`personalMode` (sin org) para el paso 10 — leerlo con el mismo
`select` de siempre:

```dart
    final hasOrgContext = context.select<AuthCubit, bool>(
      (cubit) =>
          cubit.state is AuthSuccess &&
          (cubit.state as AuthSuccess).user.organizationId != null,
    );
```

y `DrawerMenuList(currentLocation: ..., personalMode: !hasOrgContext)`.

## 10. `drawer_menu_list.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/drawer/drawer_menu_list.dart`

- Nuevo param `personalMode` (bool, required).
- **Eliminar** el ítem "Cambiar quesera" agregado en §55 (el carousel lo
  reemplaza — esa era la queja: opción oculta).
- En `personalMode` la lista renderiza **solo** el bloque de logout +
  versión (sin Inicio ni las 4 `DrawerCategoryCard` — en modo personal
  ningún módulo es navegable):

```dart
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        children: [
          if (!widget.personalMode) ...[
            stagger(DrawerHomeTile(...)),
            const SizedBox(height: 16),
            // ... las 4 DrawerCategoryCard como están
          ],
          const SizedBox(height: 20),
          stagger(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1, color: AppColors.quesivoBorder),
                const SizedBox(height: 12),
                DrawerMenuItemRow(
                  icon: Icons.logout,
                  label: l10n.logoutTooltip,
                  color: AppColors.quesivoError,
                  showChevron: false,
                  onTap: _confirmLogout,
                ),
              ],
            ),
          ),
          // ... versión igual que hoy
        ],
      ),
    );
```

(Adaptar los `stagger(...)`/índices — el patrón se conserva, solo se
envuelven los bloques de módulos en el `if`.)

## 11. `auth_guard.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

- Eliminar la constante `queserasRoute` (la ruta ya no existe).
- La regla sin-org redirige ahora a `homeRoute`:

**Antes:**
```dart
      // Token personal (sin org): solo la capa personal es alcanzable —
      // los módulos del shell necesitan el JWT org-scoped que emite
      // select-organization. Desde /queseras se queda quieto.
      if (!hasOrgContext) {
        if (location != queserasRoute) {
          logger.info(
            'AuthGuard -> Acción: $queserasRoute (token sin org, capa personal)',
          );
          return queserasRoute;
        }
        return null;
      }
```

**Después:**
```dart
      // Token personal (sin org): el usuario puede existir solo en el
      // Inicio — el carousel de queseras ES la puerta de entrada a los
      // módulos (§56); cualquier otra ruta redirige acá.
      if (!hasOrgContext) {
        if (location != homeRoute) {
          logger.info(
            'AuthGuard -> Acción: $homeRoute (token sin org, selector en home)',
          );
          return homeRoute;
        }
        return null;
      }
```

## 12. `app_router.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

Eliminar el `GoRoute` de `AuthGuard.queserasRoute` agregado en §55 y su
import de `queseras_screen.dart`. El `StatefulShellRoute` queda como
estaba — `/home` sigue siendo la raíz del branch 0.

## 13. l10n (`app_es.arb` / `app_en.arb` / `app_pt.arb`)

Agregar (y `flutter gen-l10n`):

| Clave | es | en | pt |
|-------|----|----|-----|
| `chooseQueseraHint` | `Elegí tu quesera para entrar` | `Pick your factory to enter` | `Escolha sua queijaria para entrar` |
| `queseraEnterCta` | `Entrar` | `Enter` | `Entrar` |

`personalGreeting`, `myQueserasTitle`, `changeQuesera`,
`queseraActiveBadge`, `noQueserasAvailable`, `queseraSelectError` ya
existen (§55) — `changeQuesera` queda sin uso (eliminarla de los 3 arbs
para no arrastrar claves muertas).

## 14. `Design/quesivo-design-system.yaml`

- `pages.queseras` se reescribe: ya no es pantalla propia — es
  `QueseraHeroCarousel` dentro de `pages.home` (o mover la spec bajo
  home y dejar `queseras` como widget, decisión del implementador
  siguiendo la estructura actual del yaml).
- Documentar: peek `viewportFraction 0.88` + dots + regla "swipe navega,
  tap cambia" + auto-entrada con 1 sola + modo elección sin nav bar.
- Bump a `1.15.0` + changelog.

## 15. Tests

- `auth_guard_test.dart` — el grupo de token personal pasa a esperar
  `/home` (no `/queseras`); caso `/home` con personal → `null`.
- `queseras_screen_test.dart` — **borrar**; su cobertura migra a:
- `quesera_hero_carousel_test.dart` (nuevo) — 1 org+activa: solo hero,
  sin dots; N orgs: dots + cards "Entrar"; tap en card no-activa →
  `select` del cubit; tap en activa → sin llamada; personal+1 org →
  auto-select disparado una sola vez.
- `quesera_card_test.dart` — actualizar a la firma nueva (sin
  `isActive`/`activeLabel`; `enterLabel` + loading bloquea tap).
- `home_tab_test.dart` (si existe — si no, cubrir en el del carousel) —
  modo elección oculta `HomeQuickActions`; con org los muestra.
- `quesera_selection_cubit_test.dart` — sin cambios.

---

## Orden de aplicación

1. `quesera_hero_card.dart` (trasladar KPIs de `home_hero_card.dart`).
2. `quesera_card.dart` restilo → variante "Entrar".
3. `quesera_hero_carousel.dart` (incluye el BlocProvider del cubit).
4. `home_tab.dart` + borrar `home_hero_card.dart`.
5. `main_layout.dart` (nav condicional) + `shell_header.dart` +
   `quesivo_drawer.dart` + `drawer_menu_list.dart` (personalMode,
   quitar ítem §55).
6. `auth_guard.dart` + `app_router.dart` (quitar /queseras) + borrar
   `queseras_screen.dart`.
7. `.arb` ×3 (agregar 2, quitar `changeQuesera`) + `flutter gen-l10n`.
8. Tests + `flutter analyze` + `flutter test`.
9. `design-system.yaml` bump 1.15.0.
