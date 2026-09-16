// lib/core/logging/implementations/crashlytics_logger_service_impl.dart
import '../interfaces/i_logger_service.dart';

// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Implementación concreta de ILoggerService para PRODUCCIÓN.
///
/// SOLID (LSP y DIP): Esta clase puede sustituir a DebugLoggerServiceImpl
/// sin romper nada. Simula la integración con Firebase Crashlytics.
/// A la capa de dominio no le interesa que por debajo Firebase mande peticiones HTTP.
class CrashlyticsLoggerServiceImpl implements ILoggerService {
  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    // En producción usualmente ignoramos los logs de debug puro
    // para no saturar la red del usuario y ahorrar batería.
  }

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    // Guarda "migajas de pan" en Crashlytics para entender qué hacía
    // el usuario justo antes de que la app se cerrara de golpe.
    // Ej: FirebaseCrashlytics.instance.log('[INFO] $message');
    // print('[PROD-NUBE] Resgistrando paso del usuario: $message');
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    // Ej: FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
    // print('[PROD-NUBE] Se registró advertencia silenciosa en Crashlytics: $message');
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    // Registra errores no-fatales en la consola de Firebase
    // Ej: FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message, fatal: false);
    // print('[PROD-NUBE] ERROR NO FATAL ENVIADO A CRASHLYTICS: $message');
  }

  @override
  void crash(String message, Object error, StackTrace stackTrace) {
    // Registra un fallo monstruoso que destruye el flujo.
    // Ej: FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message, fatal: true);
    // print('[PROD-NUBE] 🚨 CRASH FATAL REPORTADO A EQUIPO DE DESARROLLO 🚨: $message');
  }
}
