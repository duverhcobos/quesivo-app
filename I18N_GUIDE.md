# Guía de Internacionalización Nativa (i18n)

¡Bienvenido! Nuestra aplicación implementa el sistema de Traducción Nativo de Flutter (`flutter_localizations`) que es 100% compatible con los estándares de **Arquitectura Limpia y S.O.L.I.D**. 

Nunca almacenes texto estático ni en español ni en inglés en los Widgets (`Text('Login')`). Todo el texto de la app debe inyectarse puramente en tiempo de renderizado basándose en diccionarios externos.

---

## 1. Archivos Clave del Motor

1. **`l10n.yaml` (Raíz)**: Le indica al Motor Generador de Dart de dónde leer los diccionarios y dónde depositar las clases auto-generadas.
2. **`lib/l10n/`**: La fortaleza de idiomas. Cada archivo con terminación `.arb` (Application Resource Bundle) equivale a un idioma nativo. (Ej. `app_es.arb` = Español).
3. **`LocaleCubit` (Core)**: Nuestro State Management de Responsabilidad Única (`SRP`) alojado secretamente en `setup_di.dart`, encargado exclusivamente de mantener el idioma "forzado" si el usuario elige manualmente cambiarlo en el AppBar.

---

## 2. Flujo de Trabajo: ¿Cómo agrego un  texto nuevo?

Si estás construyendo una pantalla nueva (ej: *"Mi Perfil"*) y necesitas un botón de *"Cerrar Sesión"*, sigue estos tres estrictos pasos:

### Paso 1: Edita todos los Diccionarios (.arb)
Abre absolutamente todos los archivos dentro de `lib/l10n/` y añade la misma variable genérica en cada uno de ellos respetando el modelo JSON (`camelCase`):

**En `app_es.arb` (Español):**
```json
"logoutButton": "Cerrar Sesión"
```

**En `app_en.arb` (Inglés):**
```json
"logoutButton": "Logout"
```

**En `app_pt.arb` (Portugués):**
```json
"logoutButton": "Sair"
```

### Paso 2: El Comando Mágico
Flutter no sabrá mágicamente que modificaste esos JSON. Tienes que ordenarle que construya los Traductores Nativos en Lenguaje Dart.
Cada vez que toques un archivo `.arb`, tu deber es correr en terminal:

```bash
flutter gen-l10n
```
*(Tip: Puedes usar la consola del VS Code o tu terminal preferida)*

### Paso 3: Consúmelo en el Widget Reactivamente
Ve a tu Widget donde pretendes usar tu nuevo botón.
Añade la clase generada en tus importaciones en la parte superior del archivo:
```dart
import 'package:quesivo/l10n/app_localizations.dart';
```

Extrae el texto dinámico dentro del método `build`:
```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!; // <--- El Motor entra en Acción

  return ElevatedButton(
    onPressed: () {},
    child: Text(l10n.logoutButton), // <--- Adiós quemado manual, bienvenido Polimorfismo
  );
}
```

---

## 3. ¿Cómo Cambio el Idioma a la Fuerza en Código?

Nuestros `MaterialApp` delegaron la responsabilidad a la clase `LocaleCubit`.
Si diseñas un Switch o un RadioBotón donde el usuario oprime *"Quiero la app en Inglés"*, llama a su contexto desde en cualquier parte del código:

```dart
// Forzar Inglés
context.read<LocaleCubit>().changeLocale(const Locale('en'));

// Forzar Español
context.read<LocaleCubit>().changeLocale(const Locale('es'));
```

Automáticamente el Cubit avisará al gestor raíz y re-construirá sin parpadeos cada `AppLocalizations` de cada pantalla existente en `16ms`.
