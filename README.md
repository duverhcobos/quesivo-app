# 🚀 Quesivo — App móvil Flutter (Clean Architecture + S.O.L.I.D.)

Bienvenidos al repositorio de **Quesivo**, la aplicación móvil Flutter del sistema de gestión para queseras (SaaS multi-tenant, backend en `app-quesera/`), en desarrollo activo con destino a **producción**, construida bajo un estándar de desarrollo **Nivel Senior / Enterprise**.

Este repositorio implementa un flujo completo de Autenticación (Login interactivo y Protección de Rutas) construido bajo los máximos rigores de **Ingeniería de Software**.

---

## 🏛️ Filosofía y Principios Centrales (S.O.L.I.D.)

Este código fue rigurosamente refactorizado respetando inquebrantablemente los 5 principios base de la Programación Orientada a Objetos Arquitecturizada:

1. **(S) Single Responsibility:** Cada clase, widget y cubit tiene una única razón de existir. Las Vistas visuales son "Tontas" (Dumb Views) confiriendo toda lógica a los Blocs.
2. **(O) Open/Closed:** Componentes como el entorno (`Environment`) o nuestro motor de red (`INetworkService`) están abiertos a extensión (posibilitan migrar de Dio a Http en 1 línea) pero cerrados a modificación interna.
3. **(L) Liskov Substitution:** Las interfaces como `IAuthRepository` aseguran que cualquier implementación (RemoteDataSource o LocalDataSource) sea intercambiable sin romper la aplicación lógica.
4. **(I) Interface Segregation:** Las interfaces son precisas y puras, sin obligar a las clases a depender de métodos inútiles (El Remote Data Source se deshizo del Local Data Source).
5. **(D) Dependency Inversion:** Nadie depende directamente del código de nadie. Todo se inyecta por Interfaces mediante un Contenedor Global de Inyección de Dependencias (`GetIt`).

---

## 🛠️ Stack Tecnológico Premium

La aplicación utiliza la mejor selección moderna de dependencias estables y ampliamente adoptadas por corporaciones como Google, Uber e IBM:

* **Framework:** Flutter (Canal Estable / Strict Lints).
* **Gestor de Estado Frontal:** `flutter_bloc` (Cubits aislados para segregación matemática en la UI).
* **Inyección de Dependencias (DI):** `get_it`.
* **Value Objects (Clean Architecture):** `formz` (Desterró validaciónes en GlobalKeys).
* **Network HTTP & Interceptors:** `dio` purificado + Middleware interno.
* **Navegación:** `go_router` con Re-direccionamiento por Guardias Asíncronos (`AuthGuard`).
* **Storage Local Seguro:** `flutter_secure_storage`.
* **Tests:** `mocktail` y `bloc_test`.
* **Traducción Universal (i18n):** `flutter_localizations` & `intl` (Motores nativos `.arb`).

---

## ⭐ Características (Features) y Logros Técnicos

1. **Entidades Purificadas (Value Objects):** La Interfaz Gráfica ya no conoce expresiones regulares ReGex. Se crearon los Value Objects `Email` y `Password` que se auto-validan intrínsecamente.
2. **Setup de Environments (Flavors Técnicos):** La app lee variables inyectadas herméticamente por línea de comandos en la memoria base (`--dart-define=ENV=dev`) para ocultar secretos, APIs Keys y URLs. *(Documentado en `ENVIRONMENTS.md`)*.
3. **Múltiples Idiomas Nativos Desacoplados:** Textos separados en diccionarios `JSON` de alto poder (`.arb`). Soporte inmediato para Español, Inglés y Portugués administrado velozmente por `LocaleCubit`. *(Documentado en `I18N_GUIDE.md`)*.
4. **Sistema de Diseño Abstracto (Theming):** Colores y diseños ya no están "quemados" (Hardcoded) en los archivos UI. Todo Widget reacciona automáticamente al Modo Oscuro/Claro del sistema consumiendo variables abstractas de `Theme.of(context)`.
5. **Logger Service Invertido (Observabilidad):** El comando `print()` fue desterrado mortalmente de la aplicación. Todo error y éxito pasa por la interfaz `ILoggerService`, el cual usa consola con colores en etapa Debug y enviará los crashes silenciosamente a plataformas como Crashlytics en Producción.
6. **Network Info Inteligente:** Chequeamos proactivamente la disponibilidad de hardware en tiempo real de Internet (`InternetConnectionChecker`) evadiendo así mandar peticiones REST innecesarias al servidor si el celular está desconectado.
7. **Testing 100% Empírico sin Emulador:** Demostramos matemáticamente la independencia de las capas (Dominio y Presentación) mediante Pruebas Unitarias reales. Los Use Cases y Cubits fueron estresados y testeados pasándole dependencias falsas Mocks.

---

## 📂 Arquitectura de Directorios (Folder Structure)

```text
lib/
├── core/
│   ├── bootstrap/      # Orquestador del arranque (AppBootstrap)
│   ├── constants/      # Environment (Acceso a las Dart-Defines estáticas)
│   ├── di/             # Service Locator (Registro en GetIt / setup_di.dart)
│   ├── localization/   # El Cubit que domina el ciclo global del idioma seleccionado
│   ├── logging/        # Sistema Central Analítico (Crashlytics, Debug Logs, ILS)
│   ├── network/        # Wrappers ultra abstractos de Dio y los Interceptores
│   ├── routes/         # Configuración Mapeada de GoRouter y Guardia de Sesión
│   └── theme/          # AppTheme y AppColors (Punto de inflexión Visual Material 3)
│
├── features/
│   └── auth/           
│       ├── data/       # Repositorio Implementado y DataSources (Remote/Local)
│       ├── domain/     # IAuthRepository (Contrato) y Mis Casos de Uso (Use Cases)
│       └── presentation/# UI Visual Screens (UI Dumb) y Cubits Reactivos
│
├── l10n/               # La sede de diccionarios multi-idioma (ARB Files - JSON)
└── main.dart           # Punto de Inyección raíz ultraligero
```

---

## 🏃 Instrucciones de Comando para el Equipo (Correr Local)

1. Sincronizar Árbol de Paquetes:
   ```bash
   flutter pub get
   ```

2. Compilar Archivos Base (Generador de Código para Idiomas):
   ```bash
   flutter gen-l10n
   ```

3. Explotar hacia un emulador adjuntando la inyección de entorno de **Desarrollo (DEV)**:
   ```bash
   flutter run --dart-define=ENV=dev --dart-define=API_TOKEN=<tu-token>
   ```

   *⚠️ Nunca reemplaces `<tu-token>` por un token real dentro de archivos versionados
   (`launch.json`, `README.md`, etc.). Los tokens reales se inyectan solo por terminal
   o por variables de entorno del sistema operativo (ver `ENVIRONMENTS.md`).*

   *💡 Nota Pro-Tip: Si desarrollas bajo Visual Studio Code, los 3 perfiles oficiales de compilación (DEV, STG, PROD) ya están precargados como botones gráficos gracias a la directriz inyectada en nuestra carpeta `.vscode/launch.json`. Los tokens se leen de variables de entorno del SO (`API_TOKEN_DEV`/`API_TOKEN_STG`/`API_TOKEN_PROD`) para que ningún secreto real quede escrito en un archivo versionado:*

   ```json
   {
       // Configuraciones de Perfiles para la Arquitectura S.O.L.I.D.
       // Usa el panel inferior derecho de VS Code para cambiar rápidamente entre Entornos.
       "version": "0.2.0",
       "configurations": [
           {
               "name": "Solid DEV (Entorno Local)",
               "request": "launch",
               "type": "dart",
               "args": [
                   "--dart-define=ENV=dev",
                   "--dart-define=API_TOKEN=${env:API_TOKEN_DEV}"
               ]
           },
           {
               "name": "Solid STG (Servidor Pruebas)",
               "request": "launch",
               "type": "dart",
               "args": [
                   "--dart-define=ENV=stg",
                   "--dart-define=API_TOKEN=${env:API_TOKEN_STG}"
               ]
           },
           {
               "name": "Solid PROD (Modo Release)",
               "request": "launch",
               "type": "dart",
               "flutterMode": "release", // Simula entorno real optimizado compilado
               "args": [
                   "--dart-define=ENV=prod",
                   "--dart-define=API_TOKEN=${env:API_TOKEN_PROD}"
               ]
           }
       ]
   }
   ```

---

*Proyecto moldeado y re-escrito implementando los máximos estándares de calidad tecnológica, pensado exhaustivamente como un base-code altamente mantenible bajo escala a largo plazo.*
