# Propuesta 51: Listado — feedback de refetch y error con datos

Dos gaps de UX del listado real (§49), detectados por el usuario en el
emulador:

1. **Refiltro sin feedback**: al buscar o cambiar el chip de rol, la lista
   vieja queda idéntica y quieta hasta que llega la respuesta — se siente
   como que el filtro "no hizo nada" y de repente cambia sola.
2. **Error de refetch mata la lista**: si la página 1 ya estaba cargada y
   el `?search=`/`?role=` falla, `status: error` reemplaza TODO con la
   pantalla de error — se pierde una lista perfectamente válida.

Fix: loading-con-datos atenúa la lista + loader de marca encima;
error-con-datos conserva la lista + toast de error (la pantalla de error
queda solo para cuando no hay nada que mostrar).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/users/presentation/cubit/users_list_cubit.dart` | `refresh()` ya no emite `status: loading` (el RefreshIndicator ya ES el indicador — evita doble spinner + atenuado) |
| `lib/features/users/presentation/screens/users_screen.dart` | `error`-con-miembros cae a la lista (no a la pantalla de error); `loading`-con-miembros = lista atenuada + loader encima; `BlocConsumer` dispara toast de error |
| `test/features/users/presentation/cubit/users_list_cubit_test.dart` | `refresh` ya no espera emisión `loading` |
| `test/features/users/presentation/screens/users_screen_test.dart` | Tests nuevos: dim+loader en refetch, lista conservada + toast en error-con-datos |
| `../Design/quesivo-design-system.yaml` | Bump `1.11.0` → `1.11.1` + spec + changelog |

---

## 1. users_list_cubit.dart (actualización)

**Ruta:** `lib/features/users/presentation/cubit/users_list_cubit.dart`

`refresh()` comparte la lógica de `load()` pero **sin emitir `loading`**:
el `RefreshIndicator` ya muestra su propio indicador — emitir `loading`
metería además el loader centrado + la atenuación (doble feedback).

**Antes:**
```dart
  /// Carga la página 1 con los filtros activos — entry point del init,
  /// del retry y de cada cambio de búsqueda/rol. Conserva `members`
  /// mientras carga: un refresh muestra la lista actual bajo el
  /// indicador en vez de flashear a spinner vacío.
  Future<void> load() async {
    final token = ++_loadToken;
    emit(
      state.copyWith(
        status: UsersListStatus.loading,
        isLoadingMore: false,
        failure: null,
      ),
    );
    final result = await _listUsers(
```

**Después:**
```dart
  /// Carga la página 1 con los filtros activos — entry point del init,
  /// del retry y de cada cambio de búsqueda/rol. Conserva `members`
  /// mientras carga: la screen los muestra atenuados bajo el loader
  /// (§51) en vez de flashear a spinner vacío.
  Future<void> load() => _fetchPage1(showLoading: true);

  /// Pull-to-refresh — misma página 1 con el query/filtro actuales, pero
  /// SIN emitir `loading` (§51): el `RefreshIndicator` ya ES el
  /// indicador visual; marcar `loading` encima metería el loader
  /// centrado + la atenuación — doble feedback.
  Future<void> refresh() => _fetchPage1(showLoading: false);

  Future<void> _fetchPage1({required bool showLoading}) async {
    final token = ++_loadToken;
    emit(
      state.copyWith(
        status: showLoading ? UsersListStatus.loading : state.status,
        isLoadingMore: false,
        failure: null,
      ),
    );
    final result = await _listUsers(
```

**Antes** (el `refresh` viejo, que se elimina):
```dart
  /// Pull-to-refresh — misma página 1 con el query/filtro actuales.
  Future<void> refresh() => load();
```

**Después:** eliminado (quedó arriba como `_fetchPage1(showLoading: false)`).

> Nota: un `load()` posterior (filtro/búsqueda) sí emite `loading` aunque
> un refresh esté en vuelo — el token nuevo invalida su respuesta igual.
> Un `error` durante refresh sigue emitiendo `status: error` (la screen
> decide: sin datos → pantalla de error; con datos → toast §51).

## 2. users_screen.dart (actualización)

**Ruta:** `lib/features/users/presentation/screens/users_screen.dart`

### 2a. `Expanded` del cuerpo: `BlocBuilder` → `BlocConsumer`

El error-con-datos dispara toast (efecto → listener, no builder). Solo
cuando la lista tiene filas — sin datos sigue siendo pantalla de error.

**Antes:**
```dart
              // ── Listado sobre surface — estados del GET real ──
              Expanded(
                child: BlocBuilder<UsersListCubit, UsersListState>(
                  builder: (context, state) => _buildBody(context, state),
                ),
              ),
```

**Después:**
```dart
              // ── Listado sobre surface — estados del GET real ──
              Expanded(
                child: BlocConsumer<UsersListCubit, UsersListState>(
                  // §51: error CON lista cargada → toast (la pantalla de
                  // error se reserva para cuando no hay nada que mostrar).
                  // Solo en la transición a error — un rebuild con el
                  // error ya presente no repite el toast.
                  listenWhen: (p, c) =>
                      c.status == UsersListStatus.error &&
                      p.status != UsersListStatus.error &&
                      c.members.isNotEmpty,
                  listener: (context, state) => QuesivoToast.error(
                    context,
                    message: l10n.usersLoadError,
                  ),
                  builder: (context, state) => _buildBody(context, state),
                ),
              ),
```

### 2b. `_buildBody` — `error` con datos cae a la lista; `loading` con datos = atenuada + loader

**Antes:**
```dart
    switch (state.status) {
      case UsersListStatus.initial:
      case UsersListStatus.loading:
        // Un refresh/filtro en vuelo conserva las filas cargadas debajo
        // del indicador — sin lista previa, spinner centrado.
        if (state.members.isEmpty) {
          // Primera carga — el momento grande del loader de marca.
          return Center(
            child: QuesivoLoader(size: 40, semanticLabel: l10n.loadingLabel),
          );
        }
      case UsersListStatus.error:
        return UsersListErrorState(
          onRetry: () => context.read<UsersListCubit>().load(),
        );
      case UsersListStatus.loaded:
        break;
    }
```

**Después:**
```dart
    switch (state.status) {
      case UsersListStatus.initial:
      case UsersListStatus.loading:
        // Sin lista previa → loader de marca centrado; con lista, cae
        // al render de abajo que la muestra ATENUADA bajo el loader
        // (§51 — feedback visible del refetch por búsqueda/filtro).
        if (state.members.isEmpty) {
          // Primera carga — el momento grande del loader de marca.
          return Center(
            child: QuesivoLoader(size: 40, semanticLabel: l10n.loadingLabel),
          );
        }
      case UsersListStatus.error:
        // §51: la pantalla de error solo cuando no hay NADA que mostrar;
        // con filas cargadas la lista se conserva y el listener ya
        // disparó el toast de error (reintento = pull-to-refresh o
        // reescribir la búsqueda).
        if (state.members.isEmpty) {
          return UsersListErrorState(
            onRetry: () => context.read<UsersListCubit>().load(),
          );
        }
      case UsersListStatus.loaded:
        break;
    }
```

**Antes** (el return final del listado):
```dart
    return RefreshIndicator(
      color: AppColors.quesivoNavy,
      backgroundColor: AppColors.quesivoWhite,
      onRefresh: () => context.read<UsersListCubit>().refresh(),
      // Padding en el ListView (no en un wrapper): las cards
      // pueden scrollear bajo el nav navy y el último ítem sube
      // por encima — inset = shellNavBarHeight (§39) + alto del
      // FAB (56) + su margen (16) para que el ⋮ de la última
      // card nunca quede tapado al llegar al fondo.
      child: ListView.separated(
        ...
      ),
    );
  }
```

**Después:**
```dart
    final list = RefreshIndicator(
      color: AppColors.quesivoNavy,
      backgroundColor: AppColors.quesivoWhite,
      onRefresh: () => context.read<UsersListCubit>().refresh(),
      // Padding en el ListView (no en un wrapper): las cards
      // pueden scrollear bajo el nav navy y el último ítem sube
      // por encima — inset = shellNavBarHeight (§39) + alto del
      // FAB (56) + su margen (16) para que el ⋮ de la última
      // card nunca quede tapado al llegar al fondo.
      child: ListView.separated(
        ... // sin cambios
      ),
    );

    // §51 — refetch con lista previa (búsqueda/filtro): la lista queda
    // atenuada y sin gestos bajo el loader de marca — se ve que está
    // trabajando y la data vieja no se lee como fresca. El pull-to-
    // refresh queda bloqueado mientras vuela el refetch (ya hay carga).
    if (state.status == UsersListStatus.loading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Opacity(opacity: 0.45, child: list),
          ),
          Center(
            child: QuesivoLoader(size: 28, semanticLabel: l10n.loadingLabel),
          ),
        ],
      );
    }
    return list;
  }
```

## 3. Tests

**`users_list_cubit_test.dart`**: el test de `refresh()` ya no debe
esperar `[loading, loaded]` — ahora emite solo `loaded` (el estado de
loading del pull es visual del RefreshIndicator, no del cubit). Revisar
si hay otros tests que llamen `refresh()` esperando `loading`.

**`users_screen_test.dart`** — nuevos:

- `loading con miembros → lista atenuada (Opacity 0.45) + QuesivoLoader
  encima` — emitir loaded con filas → luego emitir loading con las mismas
  filas → cards siguen + `find.byType(Opacity)` con 0.45 + loader.
- `error con miembros → conserva la lista y dispara toast` — loaded con
  filas → emitir error con filas → cards siguen visibles + el
  `UsersListErrorState` NO aparece + el toast quedó en el overlay.
- `error sin miembros → UsersListErrorState` (ya debe existir — mantener).
- `refresh (pull) no muestra el loader centrado` — emitir `loading` con
  `status` del estado previo loaded... el cubit ya no emite loading en
  refresh; a nivel screen el caso loading+members = atenuado (ya cubierto
  arriba). El caso relevante a nivel cubit es el test de arriba.

## 4. Design system yaml

- `version` → `1.11.1` (ajuste visual dentro de una pantalla existente).
- Spec `users_screen.member_list`: actualizar `data` (los estados del
  cuerpo) y `pagination.failures` (error de página 1 con lista previa →
  toast + lista conservada; sin lista → pantalla de error) y el
  comportamiento de `refresh` (sin emisión loading — el indicador es el
  RefreshIndicator).
- Changelog `1.11.1` page "users_screen", status completed — citar el
  feedback del usuario en emulador (refiltro sin feedback + error que
  mataba la lista).

---

## Orden de aplicación

1. `users_list_cubit.dart` (`_fetchPage1` + `refresh` sin loading)
2. `users_screen.dart` (BlocConsumer + `_buildBody` + Stack atenuada)
3. Tests (cubit + screen)
4. `flutter analyze` + `flutter test`
5. yaml 1.11.1
