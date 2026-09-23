# Propuesta: Home siempre completo — la quesera solo se manifiesta en la card y el drawer

Corrección de diseño sobre §56/§57 (validación visual del usuario):
**no hay pantalla ni modo intermedio entre auth y home**. El Inicio es
una sola pantalla que se ve igual siempre — la selección de quesera es
la card del hero, no un "modo" que cambia la cara de la app.

## Reglas resultantes

- **ShellHeader**: solo el nombre del usuario — se elimina la línea de
  quesera/hint **siempre** (dentro o fuera de quesera). El "en qué
  quesera estoy" lo comunica la card del hero, que es donde el usuario
  la mira.
- **HomeTab**: layout único — título `Inicio` + carousel + accesos
  rápidos + actividad reciente, siempre. Sin modo elección que oculta
  secciones. Sin haber entrado a una quesera solo se agrega el hint
  `chooseQueseraHint` bajo el carousel (los accesos rápidos ya nacen
  `onTap: null` — inertes igual para todos).
- **Drawer**: opciones generales siempre (Inicio + Cerrar sesión +
  versión). Las 4 categorías de módulos **solo** cuando ya se entró a
  una quesera (`enteredOrg`). La tarjeta de identidad muestra org + rol
  solo estando dentro; en selector queda solo el nombre (sin tap — los
  datos de org no aplican).
- **Nav bar**: sigue oculta hasta entrar (los tabs son módulos de
  quesera — misma regla que el drawer).
- **Guard / enteredOrg / selección limpia por sesión**: sin cambios
  (§57 se mantiene: toda sesión arranca en el selector, ninguna card
  pre-activa).

Sin cambios de backend, API ni l10n.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/shell/presentation/widgets/shell_header.dart` | Quitar la línea de org/hint — solo nombre |
| `lib/features/shell/presentation/widgets/drawer/drawer_identity.dart` | Org + rol + tap solo con `enteredOrg` |
| `lib/features/shell/presentation/widgets/quesivo_drawer.dart` | Pasar `enteredOrg` a la identidad; limpiar fallback |
| `lib/features/shell/presentation/widgets/drawer/drawer_menu_list.dart` | Inicio + logout siempre; categorías solo con `enteredOrg` |
| `lib/features/home/presentation/screens/home_tab.dart` | Quitar modo elección — layout único + hint condicional |
| `test/` | Actualizar specs afectados |
| `../Design/quesivo-design-system.yaml` | §58: header solo-nombre, home único, drawer general+módulos; bump 1.17.0 |

---

## 1. `shell_header.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/shell_header.dart`

Eliminar el `select` de `organizationName` y el segundo `Text` del
Column de identidad — el header muestra **solo el nombre** (la quesera
activa la comunica el hero card, no el chrome):

**Antes:**
```dart
    final organizationName = context.select<AuthCubit, String?>(
      (cubit) => cubit.state is AuthSuccess &&
              (cubit.state as AuthSuccess).enteredOrg
          ? (cubit.state as AuthSuccess).user.organizationName
          : null,
    );

    final trimmedName = userName?.trim() ?? '';
    final displayName = trimmedName.isNotEmpty ? trimmedName : l10n.orgName;

    // §56 — sin org activa (token personal) la segunda línea invita a
    // elegir quesera en vez del placeholder "Mi quesera".
    final trimmedOrgName = organizationName?.trim() ?? '';
    final displayOrgName = trimmedOrgName.isNotEmpty
        ? trimmedOrgName
        : l10n.chooseQueseraHint;
```

**Después:**
```dart
    final trimmedName = userName?.trim() ?? '';
    final displayName = trimmedName.isNotEmpty ? trimmedName : l10n.orgName;
```

Y en el Column del nombre queda un solo `Text` (eliminar el
`SizedBox(height: 2)` + el `Text` de `displayOrgName`). El Row ya no
necesita el Column con dos líneas: simplificar a un `Expanded` con el
`Text` del nombre directamente (o Column de un solo hijo — decisión del
implementador, lo más simple posible). Actualizar el doc comment del
widget: "avatar + nombre + hamburguesa" — la quesera ya no va acá (§58).

## 2. `drawer_identity.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/drawer/drawer_identity.dart`

`displayOrgName` pasa a `String?` (nullable). Cuando es null —modo
selector— la tarjeta muestra **solo el nombre**: ni la línea de org, ni
el chip de rol, ni el chevron, y `onTap` queda null (Datos de la
organización no aplica sin quesera).

**Después** (fragmentos):

```dart
  final String displayName;
  final String? displayOrgName; // null = sin quesera activa (§58)
```

En el `InkWell`: `onTap: displayOrgName == null ? null : () { ...actual... }`.

En el Column de textos:

```dart
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.quesivoWhite,
                      ),
                    ),
                    // §58 — org + rol solo cuando ya se entró a una
                    // quesera; en el selector la identidad es solo el
                    // nombre de la persona.
                    if (displayOrgName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        displayOrgName!,
                        ... (igual que hoy)
                      ),
                      const SizedBox(height: 8),
                      Container(
                        ... chip de rol igual que hoy ...
                      ),
                    ],
```

Y el chevron `Icon(Icons.chevron_right ...)` se envuelve en el mismo
`if (displayOrgName != null)` (o se deja con opacidad — decisión visual
menor del implementador; preferido: ocultarlo, la tarjeta no es
accionable sin org).

## 3. `quesivo_drawer.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/quesivo_drawer.dart`

- El `select` de `organizationName` ya está gated por `enteredOrg`
  (§57) — mantenerlo.
- Eliminar el fallback `l10n.orgName`/`chooseQueseraHint`: pasar el
  nullable crudo a `DrawerIdentity`.

**Antes:**
```dart
    final trimmedOrgName = organizationName?.trim() ?? '';
    final displayOrgName = trimmedOrgName.isNotEmpty
        ? trimmedOrgName
        : l10n.chooseQueseraHint;
```

**Después:**
```dart
    final trimmedOrgName = organizationName?.trim() ?? '';
    final displayOrgName =
        trimmedOrgName.isNotEmpty ? trimmedOrgName : null;
```

## 4. `drawer_menu_list.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/drawer/drawer_menu_list.dart`

Las **opciones generales quedan siempre visibles** — solo las
categorías de módulos dependen de `enteredOrg` (`personalMode`).

**Antes:** el `DrawerHomeTile` está dentro del `if (!widget.personalMode)`
junto con las 4 `DrawerCategoryCard`.

**Después:**
```dart
        children: [
          // §58 — opciones generales siempre; los módulos de quesera se
          // cargan al entrar (enteredOrg).
          stagger(
            DrawerHomeTile(
              label: l10n.navHome,
              selected: widget.currentLocation == AuthGuard.homeRoute,
              onTap: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(AuthGuard.homeRoute);
              },
            ),
          ),
          if (!widget.personalMode) ...[
            const SizedBox(height: 16),
            // ... las 4 DrawerCategoryCard con sus stagger() igual que hoy
          ],
          const SizedBox(height: 20),
          // ... bloque de logout + versión igual que hoy
        ],
```

## 5. `home_tab.dart` (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/home_tab.dart`

El tab vuelve a ser **un solo layout para todos**: título Inicio +
carousel + accesos + actividad. El hint de elección se agrega bajo el
carousel solo cuando no se ha entrado.

**Antes:**
```dart
    // §57 — modo quesera solo cuando el usuario YA entró en esta
    // sesión (no alcanza con que el JWT traiga org).
    final hasOrgContext = context.select<AuthCubit, bool>(
      (cubit) =>
          cubit.state is AuthSuccess &&
          (cubit.state as AuthSuccess).enteredOrg,
    );
```

**Después:**
```dart
    // §58 — el Inicio es uno solo siempre; sin quesera entrada se suma
    // el hint bajo el carousel (los accesos rápidos ya nacen inertes).
    final enteredOrg = context.select<AuthCubit, bool>(
      (cubit) =>
          cubit.state is AuthSuccess &&
          (cubit.state as AuthSuccess).enteredOrg,
    );
```

**Antes:**
```dart
      children: [
        // §56 — sin org activa el tab es el selector de quesera: título
        // + carousel + hint; con org es el Inicio de siempre.
        TabPageTitle(
          title: hasOrgContext ? l10n.myQueserasTitle : l10n.navHome,
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

**Después:**
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

## 6. Tests

- `quesera_hero_carousel_test.dart` — el grupo "HomeTab modo elección
  vs org" se actualiza: ahora **ambos** modos muestran
  `HomeQuickActions`/`HomeRecentActivity`; sin entrar aparece el hint
  `chooseQueseraHint`; el título es siempre "Inicio".
- Si hay widget tests de `ShellHeader`/`DrawerIdentity`/`DrawerMenuList`:
  actualizar — header sin segunda línea; identidad sin org → solo
  nombre, sin chevron ni tap; drawer sin entrar → Inicio + logout +
  versión, sin categorías.
- `auth_guard_test.dart`, `quesera_selection_cubit_test.dart`,
  `auth_cubit_test.dart` — sin cambios (la semántica `enteredOrg` no se
  toca).

## 7. `Design/quesivo-design-system.yaml`

- `pages.home`: el `personal_mode` desaparece como modo visual — el
  layout es único; documentar "sin quesera entrada solo se suma el hint
  bajo el carousel".
- `pages.shell.header`: "solo nombre — la quesera vive en el hero card
  (§58)".
- `pages.shell.drawer`: opciones generales siempre (Inicio, logout,
  versión); categorías de módulos solo con `enteredOrg`; identidad sin
  org/rol/chevron en selector.
- Bump `1.17.0` + changelog.

---

## Orden de aplicación

1. `shell_header.dart` (solo nombre).
2. `drawer_identity.dart` + `quesivo_drawer.dart` + `drawer_menu_list.dart`.
3. `home_tab.dart` (layout único + hint condicional).
4. Tests + `flutter analyze` + `flutter test`.
5. `design-system.yaml` bump 1.17.0.
