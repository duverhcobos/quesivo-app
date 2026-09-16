# Propuesta: Ajustes finales del QuesivoDrawer — backdrop, identidad accionable, ✕ navy, logout confirmado, divider y versión

**Estado: aplicada** (propuesta retroactiva — el usuario pidió cada cambio
verbalmente y se aplicó directo; este documento deja el registro formal).
`flutter analyze` 0 issues, `flutter test` 77/77, `dart format` limpio.
yaml en 1.3.2.

Agrupa los ajustes de diseño aplicados sobre el rediseño §30:

1. **Backdrop simplificado** — el arco navy abajo-derecha se retiró
   (competía con la tarjeta navy de identidad); solo queda el círculo
   amarillo con huecos arriba-derecha.
2. **Identidad accionable** — `DrawerIdentity` envuelta en `Material` navy
   + `InkWell` con `chevron_right` blanco 60%; tap → cierra drawer +
   `push` a `/home/organizacion`.
3. **✕ navy** — `DrawerCloseButton` de círculo blanco con borde a círculo
   navy sólido con ícono blanco.
4. **Confirmación de logout** — diálogo antes de cerrar sesión
   (`DrawerLogoutDialog`, tarjeta blanca con la porción de queso de marca
   asomando por la esquina).
5. **Divider de zona destructiva** — `Divider` `quesivoBorder` antes del
   logout.
6. **Pie de versión** — `v0.1.0` al final del scroll, con la versión en
   `Environment.appVersion`.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `widgets/quesivo_drawer.dart` | Quitado el `Positioned` del arco navy; doc comments actualizados |
| `widgets/drawer/drawer_identity.dart` | `Material` + `InkWell` + chevron + `push` a `AuthGuard.orgDataRoute` |
| `widgets/drawer/drawer_close_button.dart` | Círculo navy + ícono blanco (borde eliminado) |
| `widgets/drawer/drawer_logout_dialog.dart` | **Nuevo** — diálogo de confirmación con identidad de marca |
| `widgets/drawer/drawer_menu_list.dart` | Divider + logout → `_confirmLogout()` con `showDialog` + pie de versión |
| `lib/core/constants/environment/environment.dart` | `static const appVersion = '0.1.0'` |
| `lib/l10n/app_*.arb` | `cancelAction`, `logoutConfirmTitle`, `logoutConfirmMessage`, `logoutConfirmAction`, `appVersion` (es/en/pt) + `flutter gen-l10n` |
| `../Design/quesivo-design-system.yaml` | Changelog 1.3.1 / 1.3.2 |

---

## Detalle aplicado

### 1. Backdrop (`quesivo_drawer.dart`)

Se eliminó el `Positioned` del `DrawerBrandDecoration` navy
(`bottom/right: -width * 0.275`, `diameter: width * 0.55`). Permanece solo
el círculo amarillo con `withCheeseHoles: true` arriba-derecha.

### 2. Identidad accionable (`drawer_identity.dart`)

```dart
return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: Material(
    color: AppColors.quesivoNavy,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        // GoRouter capturado antes del pop — mismo patrón de las filas.
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push(AuthGuard.orgDataRoute);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // ... avatar + nombre/quesera/chip rol (sin cambios) ...
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.quesivoWhite.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    ),
  ),
);
```

Destino provisional: `/home/organizacion` (Datos de la organización) —
cuando exista una pantalla de perfil real solo se repunta la ruta.

### 3. Botón ✕ (`drawer_close_button.dart`)

`Material(color: quesivoWhite, shape: CircleBorder(side: quesivoBorder))`
→ `Material(color: quesivoNavy, shape: CircleBorder())` con
`Icons.close` blanco 20.

### 4. Diálogo de logout (`drawer_logout_dialog.dart`, nuevo)

```dart
Dialog(
  backgroundColor: AppColors.quesivoWhite,
  elevation: 0,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Stack(
      children: [
        // Firma de marca — la misma decoración del drawer recortada.
        const Positioned(
          top: -36,
          right: -36,
          child: DrawerBrandDecoration(
            diameter: 100,
            color: AppColors.quesivoYellow,
            withCheeseHoles: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // círculo quesivoError 12% + Icons.logout 28 error
              // título navy 18 w700 / mensaje secondary 14 (centrados)
              // ElevatedButton quesivoError ancho completo radius 12
              // TextButton "Cancelar" secondary
            ],
          ),
        ),
      ],
    ),
  ),
)
```

El primer intento con `AlertDialog` se descartó: heredó el tema oscuro y
apiló el botón por overflow — quedó documentado en el yaml.

### 5. Divider + logout confirmado (`drawer_menu_list.dart`)

El bloque staggered del logout quedó:

```dart
Column(
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
)
```

Y el método del `State`:

```dart
Future<void> _confirmLogout() async {
  final authCubit = context.read<AuthCubit>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const DrawerLogoutDialog(),
  );

  if (confirmed == true && mounted) {
    Navigator.of(context).pop();
    authCubit.logout();
  }
}
```

El diálogo se abre **sobre** el drawer — cancelar deja el menú intacto;
confirmar cierra drawer + logout.

### 6. Versión al pie

```dart
Center(
  child: Text(
    l10n.appVersion(Environment.appVersion),
    style: const TextStyle(
      fontSize: 12,
      color: AppColors.quesivoTextSecondary,
    ),
  ),
)
```

Propio índice del stagger (7 bloques animados). `Environment.appVersion`
es una const sincronizada manualmente con `pubspec.yaml` (Dart no lee el
pubspec en runtime).

### 7. l10n

Keys nuevas en los 3 ARB: `cancelAction`, `logoutConfirmTitle`,
`logoutConfirmMessage`, `logoutConfirmAction`, `appVersion` (placeholder
`{version}`). Regenerado con `flutter gen-l10n`.

---

## Orden de aplicación (ya ejecutado)

1. Backdrop + identidad + ✕ → `flutter analyze`/`test` OK.
2. l10n + diálogo + divider + versión → `flutter gen-l10n`, `analyze`,
   `test`, `format` OK.
3. Rediseño del diálogo + tamaño de la porción de queso (76 → 100px) →
   `analyze`, `test` OK.
