// lib/core/network/auth_api_service.dart
import 'dart:io';
import 'dart:developer' as dev;

import '../../constants/environment/environment.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class AuthApiService {
  final Dio _dio;

  // Solo IPs privadas reales (RFC 1918) o localhost. Matching exacto por
  // octetos, no por substring (evita bypass accidental en hosts como
  // "miapi172.com").
  static final RegExp _localDevHostRegex = RegExp(
    r'^(localhost|127\.0\.0\.1|10(\.\d{1,3}){3}|172\.(1[6-9]|2\d|3[0-1])(\.\d{1,3}){2}|192\.168(\.\d{1,3}){2})$',
  );

  AuthApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: Environment.urlAuth,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    // Permitir certificados auto-firmados SOLO en desarrollo local y SOLO
    // para IPs privadas reales o localhost. Nunca se activa en stg/prod.
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        if (Environment.currentEnvironment != EnvType.dev) return false;
        return _localDevHostRegex.hasMatch(host);
      };
      return client;
    };

    // Este logging de diagnóstico SOLO corre en `dev`, y nunca imprime
    // cuerpos de petición/respuesta completos (pueden incluir credenciales
    // o datos personales). Solo se registran metadatos no sensibles.
    if (Environment.currentEnvironment == EnvType.dev) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            dev.log('AuthApi - Petición: ${options.method} ${options.path}');
            return handler.next(options);
          },
          onResponse: (response, handler) {
            dev.log('AuthApi - Response status code: ${response.statusCode}');
            return handler.next(response);
          },
          onError: (DioException e, handler) {
            dev.log('AuthApi - Error status code: ${e.response?.statusCode}');
            // next (no reject): el error debe seguir viajando por la cadena —
            // RefreshTokenInterceptor viene después en la lista y su onError
            // es quien dispara el refresh. Con reject la cadena se corta acá
            // y ningún 401 autenticado llega a intentar refresco.
            return handler.next(e);
          },
        ),
      );
    }
  }

  Dio get dio => _dio;
}
