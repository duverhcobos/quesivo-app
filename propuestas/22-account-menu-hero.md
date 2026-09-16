# Propuesta: Menú de cuenta con transición Hero (sin PopupMenuButton)

**Estado: REVERTIDA** — se implementó y luego el usuario la retiró
visualmente. Todo lo relacionado al ⋮ eliminado: `account_menu_button.dart`
borrado, `shell_header.dart` sin trigger de menú, yaml 1.1.0 documenta la
remoción. **Pendiente:** definir dónde vive la cuenta/logout.

(Propuesta aprobada por el usuario: reemplazar el `PopupMenuButton` — "el
recuadro no me gusta" — por un menú premium donde el ⋮ se comporte como un
hero.)

## Diseño

El `⋮` del header abre una **tarjeta flotante** anclada arriba a la derecha
que aparece "creciendo" desde el ícono — el ícono y el cierre ✕ comparten tag
`Hero`, así la transición lee como el ícono transformándose en el menú:

```
tap ⋮ →
                    ┌────────────────────────┐
                    │  ◯  Ana Pérez      ✕   │  ← eco del header
                    │     Lácteos El Roble   │
                    ├────────────────────────┤
                    │  🏢  Datos de la org   │  (disabled)
                    │  👥  Usuarios          │  (disabled)
                    │  ⎋   Cerrar sesión     │  (rojo — acción destructiva)
                    └────────────────────────┘
```

- `showGeneralDialog` con barrera `black.withValues(alpha: 0.35)` dismissible.
- `Hero(tag: 'account-menu')` en el `⋮` y en el `✕` de la tarjeta → la morph
  ícono↔menú. Entrada adicional: `transitionBuilder` fade + slide sutil
  (Offset 0,-0.02 → 0) 200ms; respeta `disableAnimations`.
- Tarjeta: blanco, radius 20, sombra `quesivoShadow` blur 24, ancho ~272,
  margen `top` debajo del header (≈ SafeArea top + 60) y `right: 16`.
- Encabezado interno: mini avatar amarillo (32px, `Icons.person` navy 18) +
  columna nombre/org (mismo `context.select` del header) + `✕` Hero para
  cerrar — refuerza la continuidad avatar→tarjeta.
- Items: `ListTile` denso — `business_outlined` Datos de la organización y
  `group_outlined` Usuarios (`enabled: false`); `logout` Cerrar sesión con
  ícono y texto `quesivoError` (convención destructiva) →
  `Navigator.pop` + `context.read<AuthCubit>().logout()` (el guard redirige).

## Archivos

| Archivo | Acción |
|---------|--------|
| `features/home/presentation/widgets/account_menu_button.dart` | **Nuevo** — `AccountMenuButton` (⋮ con Hero) + `_AccountMenuCard` (tarjeta) + `_openAccountMenu` |
| `widgets/shell_header.dart` | Reemplazar `PopupMenuButton` por `AccountMenuButton` |
| `app_*.arb` ×3 | Sin claves nuevas — reusa `orgDataItem`/`orgUsersItem`/`logoutTooltip`/`orgName` |
| `quesivo-design-system.yaml` | `shell.header.menu` → hero_card + changelog |

## Notas

- `Hero` solo anima entre rutas/diálogos del mismo `Navigator` — el diálogo
  usa el root navigator; verificar que el tag no choque (único en la app).
- `Semantics` button/label en el ⋮ (se conserva la accesibilidad del popup).
- Verificación: `analyze` 0, `test` 77, manual (tap ⋮ → tarjeta crece del
  ícono; tap fuera o ✕ → vuelve).
