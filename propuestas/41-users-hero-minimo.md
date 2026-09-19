# Propuesta: Cabecera del módulo Usuarios mínima

Iteración visual directa del usuario sobre §40 — más densidad todavía:

1. **Sin back arrow** — la navegación ya la cubre el drawer, el nav y el gesto atrás del sistema; la flecha era chrome redundante.
2. **Sin subtítulo** — "Gestiona quiénes acceden…" era relleno; las stats ya dan contexto de dominio.
3. **Acción icon-only** — dentro del módulo Usuarios, `person_add` se lee "agregar usuario" sin texto: pill compacto → **círculo amarillo 48px con ícono navy**, hermano del círculo hamburguesa del header. El `tooltip` conserva accesibilidad con `l10n.newUserButton`.

Resultado: hero de ~350px (§39) → ~195px; la fila del título lleva la acción a la derecha y las stats quedan solas abajo.

```
┌─ navy hero ──────────────────┐
│ Usuarios              ( 👤+ )│
│ ● 3 miembros   ● 2 activos   │
╰───────────────────────────────╯
```

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/users/presentation/screens/users_screen.dart` | hero mínimo: Row[título 26 + IconButton circular person_add] + stats; sin back, sin subtítulo |
| `lib/core/widgets/quesivo_primary_button.dart` | **revert §40** — la variante `compact`/`icon` queda sin consumidores; vuelve al widget original |
| `lib/l10n/app_{es,en,pt}.arb` | eliminar key huérfana `usersSubtitle` |
| `lib/l10n/app_localizations*.dart` | **regenerar** con `flutter gen-l10n` (no editar a mano) |
| `test/features/users/presentation/screens/users_screen_test.dart` | assert por tooltip/ícono en vez de texto; sin GoRouter (ya no hay `context.pop()`) |
| `Design/quesivo-design-system.yaml` | spec `module_header` + versión 1.7.3 → **1.7.4** + changelog |

Sin cambios de DI ni rutas. `newUserButton` se conserva (alimenta el tooltip).

## Detalle del hero (users_screen.dart)

```dart
child: Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    SizedBox(height: context.shellHeaderHeight),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // §41: título + acción de creación en una fila — círculo
          // amarillo icon-only (person_add se lee "agregar usuario"
          // sin texto); tooltip mantiene accesibilidad.
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.orgUsersItem,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.quesivoWhite,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.moduleComingSoon)),
                  );
                },
                tooltip: l10n.newUserButton,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.quesivoYellow,
                  foregroundColor: AppColors.quesivoNavy,
                ),
                icon: const Icon(Icons.person_add_outlined, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MemberStatsRow(members: _sampleMembers),
          const SizedBox(height: 18),
        ],
      ),
    ),
  ],
),
```

- Eliminar también: el `Row` del back con su `context.canPop()`, el `Text` del subtítulo, el import de `go_router` (queda sin uso) y la línea §40 del doc de la clase (reemplazar por la nota §41).

## Orden de aplicación

1. `quesivo_primary_button.dart` — revert a la versión pre-§40.
2. `users_screen.dart` — hero mínimo.
3. `app_es/en/pt.arb` — quitar `usersSubtitle`; `flutter gen-l10n`.
4. `users_screen_test.dart` — asserts nuevos (`find.byTooltip('Nuevo usuario')`, `find.byIcon(Icons.person_add_outlined)`), `MaterialApp` plano sin `GoRouter`.
5. `Design/quesivo-design-system.yaml` — spec + 1.7.4 + changelog.
6. `dart format` → `flutter analyze` (0 issues) → `flutter test` (verde).
