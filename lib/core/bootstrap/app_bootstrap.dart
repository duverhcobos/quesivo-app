// lib/core/bootstrap/app_bootstrap.dart
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../di/setup_di.dart';
import '../logging/interfaces/i_logger_service.dart';
import '../constants/environment/environment.dart';
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../../features/onboarding/data/datasources/implementations/shared_prefs_onboarding_status_store.dart';

/// Clase centralizada para inicializar la aplicación.
///
/// SOLID (SRP): Extrae del main.dart toda la compleja carga inicial
/// de configuración nativa, inyección y monitores de errores globales,
/// dejando que el main() solo se encargue de orquestar y arrancar el widget raíz.
class AppBootstrap {
  static Future<void> init() async {
    // 1. Asegurar bindings nativos ANTES de inyectar dependencias
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Inicializar la Inyección de Dependencias
    setupDI();

    // Flag "onboarding ya visto": SharedPreferences se inicializa async, así
    // que el store se crea ya cargado y se registra como singleton listo —
    // el AuthGuard puede leer isSeen de forma síncrona en el primer redirect.
    final onboardingStatus = SharedPrefsOnboardingStatusStore(
      await SharedPreferences.getInstance(),
    );
    await onboardingStatus.load();
    locator.registerSingleton<IOnboardingStatusStore>(onboardingStatus);

    final logger = locator<ILoggerService>();

    // 3. Captura global de errores sincrónicos (UI, Layouts, Framework de Flutter)
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.crash(
        'Error de Flutter Framework / UI',
        details.exception,
        details.stack ?? StackTrace.empty,
      );
    };

    // 4. Captura global de errores asincrónicos (Futures y Streams "escapados" sin catch)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logger.crash('Error Crítico Asincrónico / Dart puro', error, stack);
      return true; // Retorna true si lograste manejarlo para evitar el cierre forzoso
    };

    logger.info('Motores de la aplicación listos y en marcha...');
    logger.info(
      '🌍 Entorno actual: ${Environment.currentEnvironment.name.toUpperCase()}',
    );
    logger.info('🔗 API URL Activa: ${Environment.urlAuth}');
    // Nunca se loguea el token real, ni siquiera en debug (evita fugas en consola/CI).
    logger.debug(
      '🔑 API Token Inyectado: ${Environment.apiToken.isEmpty ? "(vacío)" : "(presente, oculto)"}',
    );
  }
}
