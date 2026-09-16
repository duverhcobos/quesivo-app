// lib/core/logging/interfaces/i_logger_service.dart

/// Contrato global del sistema de monitoreo y bitácoras (Logs).
///
/// SOLID (DIP y SRP): Oculta completamente cómo se hacen los logs
/// en la app. A la capa de Dominio o Presentación no le importa
/// si esto usa `dart:developer`, Firebase Crashlytics, Datadog o Sentry.
abstract class ILoggerService {
  /// Registra información de uso general para los desarrolladores.
  void debug(String message, {Object? error, StackTrace? stackTrace});

  /// Registra información relevante del negocio (Ej. "Usuario hizo login").
  void info(String message, {Object? error, StackTrace? stackTrace});

  /// Registra advertencias de comportamientos extraños pero no fatales.
  void warning(String message, {Object? error, StackTrace? stackTrace});

  /// Registra un error que no crashea la app, pero afecta el flujo.
  void error(String message, {Object? error, StackTrace? stackTrace});

  /// Registra un fallo crítico irrecuperable (Suele mandarse a Crashlytics).
  void crash(String message, Object error, StackTrace stackTrace);
}
