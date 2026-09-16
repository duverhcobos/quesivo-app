---
name: bloc-patterns
description: Cuándo usar context.read/watch/select vs BlocBuilder/BlocListener/BlocConsumer en Quesivo — división UI vs efectos, y dónde vive cada cosa (screen shell vs widgets extraídos)
allowed-tools:
  - read
  - grep
  - glob
triggers:
  - user
  - model
---

Convenciones de `flutter_bloc` para **Quesivo**. Regla de oro: los `context.*`
son funciones; los widgets `Bloc*` son widgets. Elegir según lo que se quiere
hacer — nunca usar `watch`/`select` para efectos ni `read` dentro de `build`.

## Matriz de decisión

| Quiero... | Herramienta | Por qué |
|-----------|-------------|---------|
| Despachar una acción (`onChanged`, `onPressed`, `onTap`) | `context.read<Cubit>()` | Acceso directo no reactivo — despacha sin suscribirse |
| Repintar un pedazo de UI | `BlocBuilder` (+`buildWhen`) | Acota el rebuild al subárbol; `buildWhen` es el filtro fino |
| Leer un valor suelto dentro de `build` | `context.select<Cubit, T>((c) => c.state.x)` | Equivale a `BlocBuilder` con `buildWhen` pero para un valor, no un subárbol |
| Snackbar, navegación, llamar a otro cubit | `BlocListener` (+`listenWhen` o `if` dentro) | Corre FUERA del ciclo de build — el único lugar legal para efectos |
| Rebuild + efecto en el mismo nodo | `BlocConsumer` | Une los dos; si solo hace falta uno, usar el widget específico |
| Varios cubits con efectos | `MultiBlocListener` | Un solo wrapper con la lista de listeners (ver `register_screen.dart`) |

## Reglas duras

- **`context.read` jamás dentro de `build`** — si la instancia se recrea, no
  te enterás. Solo en callbacks de eventos.
- **`watch`/`select` jamás para efectos** — corren durante `build`; un
  snackbar o `context.go()` desde ahí es un efecto ilegal (o exige el hack
  `addPostFrameCallback`). Para eso existe `BlocListener`.
- `select`/`buildWhen`/`listenWhen` filtran por **igualdad del valor
  devuelto** — devolver el objeto de estado entero equivale a no filtrar.

## Patrones de la casa (ver `register_screen.dart` como referencia)

- **Screens = shell**: `Scaffold` → `QuesivoBackdrop` → listeners → scroll →
  `Column` que compone widgets. Las pantallas no llevan `BlocBuilder` de campos
  inline — viven en los widgets extraídos (`register_form_fields.dart`, etc.).
- **Los listeners quedan en la screen** — son wiring entre cubits/efectos, no
  elementos visuales. Con varios cubits: `MultiBlocListener` con un
  `BlocListener` por cubit.
- **Un `BlocBuilder` por campo** del formulario con `buildWhen` sobre el VO
  (`p.email != c.email`) — el checklist vivo usa `p.password.value !=
  c.password.value` (compara el string, no el VO).
- **`context.read` en todos los `onChanged`/`onPressed`** de widgets hijos —
  resuelven el cubit del `BlocProvider` de la screen, nunca por DI ni por param.
- **Filtro de estado**: tanto `listenWhen: (p, c) => c is AuthError` como
  `if (state is AuthError)` dentro del listener son válidos — usar el que
  quede más legible según el caso (si el cuerpo necesita el tipo anyway, el
  `if` adentro evita el cast).
- **Éxito con navegación**: snackbar (o card) + `context.go` cuando el destino
  reemplaza la pila (reset→login); `context.pop` cuando la ruta de abajo debe
  seguir existiendo; `context.push` para entrar a rutas que deben poder volver
  (welcome→login/register).
