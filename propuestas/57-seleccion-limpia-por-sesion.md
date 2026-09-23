# Propuesta: Selección limpia por sesión — ninguna quesera pre-seleccionada

Corrección de comportamiento sobre §56 (validación visual del usuario):
la selección de quesera **no se restaura ni se pre-selecciona nunca**.
Toda sesión arranca en el selector limpio — mismo flujo en el primer
login, en un re-login, o al reabrir la app con sesión guardada. Así la
pantalla es siempre la misma y el usuario nunca ve "a veces sí hay
información, a veces no" sin saber por qué.

## Modelo resultante

- `AuthSuccess` gana `enteredOrg` (bool, default `false`) — flag **de
  sesión de app**, no del JWT. `checkSession`/`refreshSession` siempre
  lo emiten en `false` aunque el token guardado sea org-scoped.
- El "estoy dentro de una quesera" lo decide **`enteredOrg`**, ya no
  `user.organizationId != null`. Header, nav bar, drawer, guard y el
  estado activo del carousel se cuelgan de ese flag.
- Tap en una card → `select-organization` → `refreshSession` →
  `AuthCubit.enterOrganization()` prende el flag → el home re-renderiza
  en modo quesera (hero navy + KPIs + accesos + nav bar).
- Tap en la card cuya org **ya es la del JWT** (sesión restaurada) →
  entrada gratis: solo `enterOrganization()`, sin llamada — la card se
  muestra como "Entrar" igual que las demás (uniforme visualmente).
- Se **elimina el auto-enter** de §56 (1 sola quesera también espera el
  tap — el flujo es idéntico siempre).
- El org token restaurado queda válido abajo pero invisible: mientras
  `enteredOrg == false` ninguna ruta de módulo es alcanzable y ningún
  dato de quesera se muestra.

Sin cambios de backend ni de API.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/cubit/auth_state.dart` | `AuthSuccess` + campo `enteredOrg` |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | + `enterOrganization()`; `_loadSession` emite enteredOrg:false |
| `lib/features/queseras/presentation/cubit/quesera_selection_cubit.dart` | shortcut mismo-org + `enterOrganization()` tras refresh |
| `lib/features/queseras/presentation/widgets/quesera_hero_carousel.dart` | quitar auto-select; activa = `enteredOrg && id==orgId` |
| `lib/features/home/presentation/screens/home_tab.dart` | `hasOrgContext` → flag `enteredOrg` |
| `lib/features/shell/presentation/widgets/main_layout.dart` | ídem para la nav bar |
| `lib/features/shell/presentation/widgets/quesivo_drawer.dart` | `personalMode` ← `!enteredOrg` |
| `lib/features/shell/presentation/widgets/shell_header.dart` | fallback subtitle ya cubierto — verificar que el flag usado sea `enteredOrg` si aplica |
| `lib/core/routes/auth_guard.dart` | regla sin-org ahora usa `enteredOrg` |
| `test/` | actualizar specs (guard, carousel, cubit) |
| `../Design/quesivo-design-system.yaml` | §57: selector limpio por sesión; bump 1.16.0 |

---

## 1. `auth_state.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/presentation/cubit/auth_state.dart`

**Antes:**
```dart
/// Estado de éxito. Pasa el User hacia la UI para navegación y guardado.
class AuthSuccess extends AuthState {
  final User user;

  const AuthSuccess(this.user);

  @override
  List<Object> get props => [user];
}
```

**Después:**
```dart
/// Estado de éxito. Pasa el User hacia la UI para navegación y guardado.
///
/// `enteredOrg` (§57) es estado de SESIÓN DE APP, no del JWT: nace en
/// `false` en toda carga de sesión y solo se prende con
/// `AuthCubit.enterOrganization()` tras el tap en una quesera. Así el
/// selector arranca siempre limpio aunque el token guardado sea
/// org-scoped — mismo flujo en login fresco y en sesión restaurada.
class AuthSuccess extends AuthState {
  final User user;
  final bool enteredOrg;

  const AuthSuccess(this.user, {this.enteredOrg = false});

  @override
  List<Object> get props => [user, enteredOrg];
}
```

## 2. `auth_cubit.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/presentation/cubit/auth_cubit.dart`

Agregar después de `refreshSession`:

```dart
  /// Marca que el usuario entró a una quesera en esta sesión de app
  /// (§57). Lo llama `QueseraSelectionCubit` tras un select-organization
  /// exitoso — o directo cuando el tap cayó en la org que el JWT ya
  /// traía (sesión restaurada, entrada gratis).
  void enterOrganization() {
    final current = state;
    if (current is AuthSuccess && !current.enteredOrg) {
      emit(AuthSuccess(current.user, enteredOrg: true));
    }
  }
```

`_loadSession` queda igual — emite `AuthSuccess(user)` (enteredOrg=false
por default, que es exactamente lo que queremos: la sesión restaurada
NO implica quesera seleccionada).

## 3. `quesera_selection_cubit.dart` (archivo existente — actualización)

**Ruta:** `lib/features/queseras/presentation/cubit/quesera_selection_cubit.dart`

**Antes:**
```dart
  /// Devuelve `true` si la quesera quedó activa (tokens org-scoped
  /// guardados + sesión recargada). La UI navega a /home solo entonces.
  Future<bool> select(String organizationId) async {
    if (state.isSelecting) return false;
    emit(
      state.copyWith(selectingId: organizationId, clearError: true),
    );

    final result = await _selectOrganization(organizationId);

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            clearSelection: true,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) async {
        // Los tokens nuevos ya están en storage; /me rehidrata el User
        // con organizationId + organizations frescas (la membresía
        // muerta desaparece sola de la lista si fue ese el error).
        await _authCubit.refreshSession();
        if (isClosed) return false;
        emit(state.copyWith(clearSelection: true));
        return true;
      },
    );
  }
```

**Después:**
```dart
  /// Entra a la quesera tocada (§57). Devuelve `true` si quedó activa.
  /// Si el JWT restaurado ya traía ESA org, la entrada es gratis — el
  /// usuario ve la misma card "Entrar" y el mismo tap, pero se omite el
  /// POST (la selección limpia es visual; el token sigue sirviendo).
  Future<bool> select(String organizationId) async {
    if (state.isSelecting) return false;

    final auth = _authCubit.state;
    if (auth is AuthSuccess &&
        auth.user.organizationId == organizationId &&
        !auth.enteredOrg) {
      _authCubit.enterOrganization();
      return true;
    }

    emit(
      state.copyWith(selectingId: organizationId, clearError: true),
    );

    final result = await _selectOrganization(organizationId);

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            clearSelection: true,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) async {
        // Los tokens nuevos ya están en storage; /me rehidrata el User
        // con organizationId + organizations frescas (la membresía
        // muerta desaparece sola de la lista si fue ese el error).
        await _authCubit.refreshSession();
        if (isClosed) return false;
        _authCubit.enterOrganization();
        emit(state.copyWith(clearSelection: true));
        return true;
      },
    );
  }
```

## 4. `quesera_hero_carousel.dart` (archivo existente — actualización)

**Ruta:** `lib/features/queseras/presentation/widgets/quesera_hero_carousel.dart`

**Antes:**
```dart
    final (orgs, activeOrgId) = context
        .select<AuthCubit, (List<OrganizationSummary>, String?)>(
          (cubit) => cubit.state is AuthSuccess
              ? (
                  (cubit.state as AuthSuccess).user.organizations,
                  (cubit.state as AuthSuccess).user.organizationId,
                )
              : (const <OrganizationSummary>[], null),
        );
```

**Después:**
```dart
    // §57 — "activa" exige las DOS cosas: el JWT trae la org Y el
    // usuario ya entró en esta sesión de app. Con token restaurado
    // (orgId presente pero enteredOrg=false) todas son cards "Entrar":
    // el selector siempre arranca limpio.
    final (orgs, activeOrgId) = context
        .select<AuthCubit, (List<OrganizationSummary>, String?)>(
          (cubit) => cubit.state is AuthSuccess
              ? (
                  (cubit.state as AuthSuccess).user.organizations,
                  (cubit.state as AuthSuccess).enteredOrg
                      ? (cubit.state as AuthSuccess).user.organizationId
                      : null,
                )
              : (const <OrganizationSummary>[], null),
        );
```

Y **eliminar** el bloque de auto-entrada (la sección
`if (!_autoSelectAttempted && ...)` completa) junto con el campo
`_autoSelectAttempted` — la quesera única también espera el tap.

## 5. `home_tab.dart` (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/home_tab.dart`

**Antes:**
```dart
    final hasOrgContext = context.select<AuthCubit, bool>(
      (cubit) =>
          cubit.state is AuthSuccess &&
          (cubit.state as AuthSuccess).user.organizationId != null,
    );
```

**Después:**
```dart
    // §57 — modo quesera solo cuando el usuario YA entró en esta
    // sesión (no alcanza con que el JWT traiga org).
    final hasOrgContext = context.select<AuthCubit, bool>(
      (cubit) =>
          cubit.state is AuthSuccess &&
          (cubit.state as AuthSuccess).enteredOrg,
    );
```

## 6. `main_layout.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/main_layout.dart`

Mismo cambio del flag `hasOrgContext`: la condición pasa a
`state is AuthSuccess && state.enteredOrg` (verificar el nombre real del
select agregado en §56 y actualizar la expresión).

## 7. `quesivo_drawer.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/quesivo_drawer.dart`

`personalMode` pasa a alimentarse de `enteredOrg` (mismo select):
`personalMode: !enteredOrg`. El fallback del subtítulo
(`chooseQueseraHint` cuando no hay org) queda igual — cubre el caso
selector limpio.

## 8. `shell_header.dart` (archivo existente — actualización)

**Ruta:** `lib/features/shell/presentation/widgets/shell_header.dart`

Verificar: con token restaurado el `user.organizationName` viene
poblado aunque `enteredOrg` sea false — el header NO debe mostrarla en
modo selector. El `select` de `organizationName` debe quedar:

```dart
    final organizationName = context.select<AuthCubit, String?>(
      (cubit) => cubit.state is AuthSuccess &&
              (cubit.state as AuthSuccess).enteredOrg
          ? (cubit.state as AuthSuccess).user.organizationName
          : null,
    );
```

## 9. `auth_guard.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

**Antes:**
```dart
    // Si la sesión es válida (AuthSuccess)
    if (authState is AuthSuccess) {
      final hasOrgContext = authState.user.organizationId != null;
```

**Después:**
```dart
    // Si la sesión es válida (AuthSuccess)
    if (authState is AuthSuccess) {
      // §57 — contexto de quesera = flag de sesión, no el claim del
      // JWT: con token restaurado sin entrar, solo /home es alcanzable.
      final hasOrgContext = authState.enteredOrg;
```

El comentario del bloque `!hasOrgContext` queda igual (la regla es la
misma: sin haber entrado, todo redirige a `/home`).

## 10. Tests

- `auth_guard_test.dart` — los casos "personal" se renombran a "sin
  entrar a quesera (§57)": `AuthSuccess(tUser)` con org en el user pero
  `enteredOrg=false` → rutas de módulo → `/home`; `enteredOrg=true` →
  comportamiento normal. Agregar el caso: org en user + enteredOrg
  true → módulos permitidos.
- `quesera_hero_carousel_test.dart` — eliminar el grupo de auto-select;
  nuevo caso: user con `organizationId` pero `enteredOrg=false` → todas
  las cards son "Entrar" (sin hero navy, sin badge Actual).
- `quesera_selection_cubit_test.dart` — casos nuevos: tap en la org que
  ya trae el JWT → `enterOrganization` sin llamar al use case
  (`verifyNever(selectOrganization)`); tap en otra → llamada + refresh
  + enter; `enteredOrg` ya true → flujo normal de select.
- `auth_cubit_test.dart` (si existe — si no, cubrir vía cubit de
  selección): `enterOrganization` prende el flag solo en `AuthSuccess`.

## 11. `Design/quesivo-design-system.yaml`

En `pages.queseras` (spec del carousel) documentar §57:

- La activa exige `enteredOrg && org.id == organizationId` — el
  selector siempre arranca limpio por sesión de app.
- Sin auto-entrada: 1 quesera también espera el tap.
- Tap sobre la org que el JWT ya traía → entrada gratis (sin POST).
- "En qué quesera estoy" lo dan el hero navy + el header — nunca un
  estado restaurado silencioso.

Bump a `1.16.0` + changelog.

---

## Orden de aplicación

1. `auth_state.dart` (`enteredOrg`) + `auth_cubit.dart` (`enterOrganization`).
2. `quesera_selection_cubit.dart` (shortcut + enter tras refresh).
3. `quesera_hero_carousel.dart` (activa = flag; quitar auto-select).
4. `home_tab.dart`, `main_layout.dart`, `quesivo_drawer.dart`, `shell_header.dart` (flag `enteredOrg`).
5. `auth_guard.dart`.
6. Tests + `flutter analyze` + `flutter test`.
7. `design-system.yaml` bump 1.16.0.
