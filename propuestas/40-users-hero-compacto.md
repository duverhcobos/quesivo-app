# Propuesta: Cabecera del módulo Usuarios compacta

**Problema** (feedback visual del usuario sobre §39): el hero navy quedó correcto estructuralmente pero ocupa ~350px — más de la mitad de la pantalla útil — y "casi no hay espacio para listar las tarjetas".

**Solución**: misma composición y tokens, menos altura (~240px):

1. El back arrow pasa de fila propia a **inline en la fila del título** (título 26px).
2. `QuesivoPrimaryButton` gana modo **`compact`** (alto 40, ancho al contenido, fontSize 14, `icon` opcional) — el "Nuevo usuario" comparte fila con las stats en vez de ocupar un bloque full-width de 64px + gaps.
3. Gaps internos ajustados (20→16, 24→20).

`QuesivoPrimaryButton` es widget core — los parámetros nuevos son opcionales con defaults que preservan el look actual de auth (cero cambio visual en login/register/etc.).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/widgets/quesivo_primary_button.dart` | modo `compact` + `icon` opcional (defaults = look actual) |
| `lib/features/users/presentation/screens/users_screen.dart` | hero compacto: back inline, stats+acción en una fila, gaps ajustados |
| `Design/quesivo-design-system.yaml` | spec `module_header` + versión 1.7.2 → **1.7.3** + changelog |

Sin cambios de i18n (reusa `newUserButton`), DI ni rutas.

---

## 1. `quesivo_primary_button.dart` (existente — actualización)

**Ruta:** `lib/core/widgets/quesivo_primary_button.dart`

Doc — **antes:**

```dart
/// Pill amarillo 64px/18/w700 de marca (§primary_button) — botón primario
/// compartido por auth y los módulos, con estado disabled atenuado.
///
/// `onPressed` en `null` deja el botón deshabilitado (amarillo/navy
/// atenuados al 45%/50%).
```

**después:**

```dart
/// Pill amarillo de marca (§primary_button) — botón primario compartido
/// por auth y los módulos, con estado disabled atenuado.
///
/// Dos variantes: default 64px/18/w700 a ancho completo (formularios) y
/// `compact` 40px/14/w700 al ancho del contenido con `icon` opcional
/// (acciones inline, §40 — ej. "Nuevo usuario" junto a las stats del
/// módulo). `onPressed` en `null` deja el botón deshabilitado
/// (amarillo/navy atenuados al 45%/50%).
```

Clase — **antes:**

```dart
class QuesivoPrimaryButton extends StatelessWidget {
  const QuesivoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.quesivoYellow,
          foregroundColor: AppColors.quesivoNavy,
          disabledBackgroundColor: AppColors.quesivoYellow.withValues(
            alpha: 0.45,
          ),
          disabledForegroundColor: AppColors.quesivoNavy.withValues(alpha: 0.5),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
```

**después:**

```dart
class QuesivoPrimaryButton extends StatelessWidget {
  const QuesivoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Variante inline 40px al ancho del contenido — para acciones que
  /// comparten fila con otro contenido (§40). Default: 64px full-width.
  final bool compact;

  /// Ícono opcional a la izquierda del label (18px en compact, 22 en
  /// default). Sin ícono el botón queda como siempre.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppColors.quesivoYellow,
      foregroundColor: AppColors.quesivoNavy,
      disabledBackgroundColor: AppColors.quesivoYellow.withValues(alpha: 0.45),
      disabledForegroundColor: AppColors.quesivoNavy.withValues(alpha: 0.5),
      elevation: 0,
      shape: const StadiumBorder(),
      padding: compact ? const EdgeInsets.symmetric(horizontal: 18) : null,
      textStyle: TextStyle(
        fontSize: compact ? 14 : 18,
        fontWeight: FontWeight.w700,
      ),
    );

    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: compact ? 18 : 22),
            label: Text(label),
          )
        : ElevatedButton(onPressed: onPressed, style: style, child: Text(label));

    // En compact el SizedBox no fija width → el pill toma el ancho de su
    // contenido (icono + label) y puede sentarse en un Row.
    return SizedBox(
      width: compact ? null : double.infinity,
      height: compact ? 40 : 64,
      child: button,
    );
  }
}
```

---

## 2. `users_screen.dart` (existente — actualización)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

Doc de la clase: agregar `§40: hero compacto — back inline en la fila del título y la acción primaria (pill compacto 40px) comparte fila con las stats; libera ~110px de alto para el listado.`

Contenido del hero — **antes:**

```dart
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: context.shellHeaderHeight),
                if (context.canPop())
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.quesivoWhite,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.orgUsersItem,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.quesivoWhite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.usersSubtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.quesivoWhite.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MemberStatsRow(members: _sampleMembers),
                      const SizedBox(height: 20),
                      QuesivoPrimaryButton(
                        label: l10n.newUserButton,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.moduleComingSoon)),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
```

**después:**

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
                      // §40: back inline con el título — una sola fila de
                      // contexto, no dos.
                      Row(
                        children: [
                          if (context.canPop()) ...[
                            IconButton(
                              onPressed: () => context.pop(),
                              // Touch target 40 (accesible) sin el aire
                              // extra del padding default del IconButton.
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              icon: const Icon(
                                Icons.arrow_back,
                                size: 24,
                                color: AppColors.quesivoWhite,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
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
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.usersSubtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.quesivoWhite.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // §40: stats del módulo + acción primaria en UNA
                      // fila — los números y el botón que los hace crecer
                      // conviven como toolbar de la cabecera.
                      Row(
                        children: [
                          Expanded(
                            child: MemberStatsRow(members: _sampleMembers),
                          ),
                          const SizedBox(width: 12),
                          QuesivoPrimaryButton(
                            label: l10n.newUserButton,
                            compact: true,
                            icon: Icons.add,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.moduleComingSoon)),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
```

> Se elimina el `if/else` del back con su `SizedBox(height: 16)` — si la ruta no puede popear (raíz del branch), la fila arranca directo con el título, alineado igual.

---

## 3. `Design/quesivo-design-system.yaml`

- `version`: `1.7.2` → `1.7.3`
- `users_screen.module_header`: actualizar layout — back inline en fila del título (26px), stats + pill compacto `QuesivoPrimaryButton(compact, icon: add)` en una sola fila; alto total ~240px.
- `changelog` — nueva entrada:

```yaml
  - version: "1.7.3"
    page: "users_screen"
    status: "completed"
    changes:
      - "Cabecera compacta (propuesta §40, feedback del usuario — 'todo se ve grande, no hay espacio para las tarjetas'): el hero baja de ~350px a ~240px. El back pasa inline a la fila del título (28→26px) y 'Nuevo usuario' deja el bloque full-width 64px por un pill compacto 40px que comparte fila con las stats."
      - "QuesivoPrimaryButton gana variante compact (40px, ancho al contenido, fontSize 14, icon opcional) — defaults intactos, cero cambio visual en las pantallas de auth."
```

---

## Orden de aplicación

1. `quesivo_primary_button.dart` — variante compact.
2. `users_screen.dart` — hero compacto.
3. `Design/quesivo-design-system.yaml` — spec + 1.7.3 + changelog.
4. `dart format` en los archivos tocados.
5. `flutter analyze` — 0 issues.
6. `flutter test` — todo verde (si `users_screen_test` asume el botón full-width o posiciones, ajustar mínimamente).

## Verificación visual esperada

- Hero navy ~240px: `← Usuarios` en una fila, subtítulo, `● stats · [+ Nuevo usuario]` en otra — misma identidad, lista con ~110px más.
- Login/register: botones idénticos a hoy.
