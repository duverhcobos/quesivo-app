enum EnvType { dev, stg, prod }

/// Configurador Global de Entornos (SRP y OCP)
///
/// SOLID (OCP): Evalúa las variables de compilación (`--dart-define`) para inyectar
/// automáticamente la configuración correcta según el entorno (BaseURLs, API Keys).
///
/// Si necesitas agregar un entorno nuevo (Ej: QA), solo agregas un caso al `switch`
/// y toda tu arquitectura se adapta sin tocar ni un solo repositorio o servicio HTTP.
class Environment {
  // Lee la variable ENV inyectada por consola (Ej: flutter build apk --dart-define=ENV=prod)
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  // ¡AQUÍ ESTÁ TU NUEVA VARIABLE! Atrapa dinámicamente el API_TOKEN de la terminal:
  static const String apiToken = String.fromEnvironment(
    'API_TOKEN',
    defaultValue: 'token_vacio_por_defecto',
  );

  /// URL del backend quesivo-api por entorno. En dev se puede sobreescribir
  /// con `--dart-define=API_URL=http://<ip-lan>:3000` (dispositivo físico);
  /// el default `10.0.2.2` es localhost del host visto desde el emulador
  /// Android.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Versión de la app mostrada en UI (pie del drawer) — mantener sincronizada
  /// con `version:` de pubspec.yaml (Dart no puede leer el pubspec en runtime).
  static const String appVersion = '0.1.0';

  static EnvType get currentEnvironment {
    switch (_env) {
      case 'prod':
        return EnvType.prod;
      case 'stg':
        return EnvType.stg;
      case 'dev':
        return EnvType.dev;
      default:
        return EnvType.dev;
    }
  }

  /// Retorna la URL de Autenticación dinámica.
  ///
  /// La URL real de cada entorno (stg/prod) NO vive en el código — se
  /// inyecta siempre vía `--dart-define=API_URL=...` (ver `.vscode/launch.json`).
  /// Así cambiar de backend (redeploy, nuevo proveedor) no requiere tocar ni
  /// recompilar el código fuente, solo el perfil de lanzamiento/CI.
  static String get urlAuth => apiBaseUrl;
}
