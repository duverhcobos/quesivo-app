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
  static String get urlAuth {
    switch (currentEnvironment) {
      case EnvType.prod:
        return 'https://api.tu-empresa.com/v1'; // Reemplazar con URL Real de Producción
      case EnvType.stg:
        return 'https://stg.tu-empresa.com/v1'; // Reemplazar con URL Real de Pruebas/Staging
      case EnvType.dev:
        // Mantenemos DummyJSON puro y vivo exclusivamente para entorno local
        return 'https://dummyjson.com';
    }
  }
}
