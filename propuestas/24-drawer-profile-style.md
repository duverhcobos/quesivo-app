# Propuesta: Rediseño del drawer estilo "profile menu"

**Estado: aplicada** — `flutter analyze` 0 issues, `flutter test` 77/77.
Revisor: APROBADO con 1 ajuste menor ya corregido (`elevation: 0` en el
`Material` de la tarjeta — el design system es flat). yaml en 1.1.2.

(Aprobada por el usuario: estilo de la ilustración — avatar centrado +
nombre/email + ítems en tarjetas con chevron.)

## Diseño (adaptado al lenguaje Quesivo)

```
┌──────────────────────────────┐
│          ◯ avatar            │  ← 72px, amarillo, person navy 36
│        Ana Pérez             │  ← 18px w700 navy
│      ana@quesera.com         │  ← 13px secondary (user.email
│                              │    o fallback orgName)
│                              │
│  ┌────────────────────────┐  │
│  │ ◯ 🏢 Datos de la org. >│  │  ← tarjeta: ícono en círculo
│  └────────────────────────┘  │    iconSurface 40px + navy 20,
│  ┌────────────────────────┐  │    label navy w500 15px,
│  │ ◯ 👥 Usuarios         >│  │    chevron_right placeholder
│  └────────────────────────┘  │    20px — gap entre tarjetas 12
│                              │
│  ┌────────────────────────┐  │
│  │ ◯ ⎋  Cerrar sesión   >│  │  ← ícono+label+ chevron error
│  └────────────────────────┘  │
│                              │
│       Quesivo v0.1.0         │
└──────────────────────────────┘
```

- **Fondo** `quesivoWhite`; sin banda navy interna — la identidad la da el
  avatar amarillo + la tipografía navy (más fiel a la referencia, que es
  limpia).
- **Header centrado**: `SafeArea` + padding top 32; avatar círculo 72px
  `quesivoYellow` con `Icons.person` navy 36 + borde blanco fino; nombre
  18px w700 navy (mismo `context.select`); debajo el **email del usuario**
  (`user.email` del `AuthSuccess` si la entidad lo tiene — verificar; si no,
  `orgName`) 13px `quesivoTextSecondary`. Gap 12/4.
- **Ítems = tarjetas** `DrawerMenuCard` (widget nuevo privado): `Container`
  blanco radius 16, `Border.all(quesivoBorder)`, padding `14×16`; Row[
  círculo `quesivoIconSurface` 40px + ícono navy 20, `SizedBox(14)`,
  `Expanded` label 15px w500 navy, `Icons.chevron_right` `quesivoPlaceholder`
  20]. `Material`+`InkWell` para el ripple cuando estén activos.
- **Deshabilitados**: `onTap: null` → opacidad 0.45 y sin chevron (mismo
  criterio que `ModuleMenuTile` — no agregar "próximamente" textual).
- **Cerrar sesión**: misma tarjeta; ícono `logout`, label y chevron en
  `quesivoError`. `onTap` → pop + `AuthCubit.logout()` (idéntica lógica
  actual, cubit capturado antes del pop).
- **Sin label de sección "Cuenta"** — la referencia no agrupa; cuando haya
  más secciones se reintroduce.
- **Pie**: versión centrada igual que ahora.
- Espaciado: lateral 20, tarjetas separadas 12, header→items 28.

## Archivos

| Archivo | Acción |
|---------|--------|
| `features/home/presentation/widgets/quesivo_drawer.dart` | **Reescribir** — header centrado + `DrawerMenuCard` privado + pie |
| `app_*.arb` ×3 | `drawerAccountSection` queda huérfana → eliminar (verificar refs) |
| `quesivo-design-system.yaml` | `shell.header.menu.drawer` → estilo profile + changelog |

## Notas

- El email del `User` se verifica contra la entidad; si no existe, se usa
  `orgName` como fallback localizado.
- Logout sigue abajo (convención) — acá es el último ítem de la lista,
  no separado por spacer, igual que la referencia.
- Verificación: `analyze` 0, `test` 77, visual.
