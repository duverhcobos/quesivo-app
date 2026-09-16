// lib/core/logging/implementations/debug_logger_service_impl.dart
import 'dart:developer' as dev;
import '../interfaces/i_logger_service.dart';

/// Implementación concreta del ILoggerService exclusiva para desarrollo local.
///
/// Utiliza `dart:developer` para imprimir en la consola del IDE.
/// Con códigos ANSI intenta darle color a los logs para que sea fácil
/// de leer por el Arquitecto o el Desarrollador local.
class DebugLoggerServiceImpl implements ILoggerService {
  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    // Gris / Estándar para debugs masivos (ej: enrutador)
    dev.log('[DEBUG] $message', error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    // Azul para información importante
    dev.log(
      '\x1B[34m[INFO] $message\x1B[0m',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    // Amarillo para advertencias
    dev.log(
      '\x1B[33m[WARNING] $message\x1B[0m',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    // Rojo para errores que atrapamos pero que fallaron lógicas
    dev.log(
      '\x1B[31m[ERROR] $message\x1B[0m',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void crash(String message, Object error, StackTrace stackTrace) {
    // Púrpura/Fuerte para caídas estrepitosas (Crashlytics simulation)
    dev.log(
      '\x1B[35m[CRASH FATAL] $message\x1B[0m',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
