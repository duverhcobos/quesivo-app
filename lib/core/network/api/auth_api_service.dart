// lib/core/network/auth_api_service.dart
import 'dart:convert';
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

    // Logging de diagnóstico SOLO en `dev`: vuelca cada request con sus
    // headers finales (incluye credenciales/tokens — nunca habilitar en
    // stg/prod) como cURL lista para Postman, y la respuesta en JSON
    // indentado. Se imprime en onResponse/onError (no en onRequest):
    // recién ahí `requestOptions.headers` ya lleva lo que inyectaron
    // los interceptores posteriores (AuthInterceptor agrega el Bearer
    // DESPUÉS de este en la lista).
    if (Environment.currentEnvironment == EnvType.dev) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            dev.log('AuthApi - Petición: ${options.method} ${options.path}');
            return handler.next(options);
          },
          onResponse: (response, handler) {
            _logHttpExchange(
              response.requestOptions,
              response.statusCode,
              response.data,
            );
            return handler.next(response);
          },
          onError: (DioException e, handler) {
            _logHttpExchange(
              e.requestOptions,
              e.response?.statusCode,
              e.response?.data,
            );
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

/// Dev-only: vuelca el request completo como cURL lista para Postman
/// (Import → Raw text) + la respuesta en JSON indentado. Se llama con
/// los `requestOptions` FINALES del intercambio — el Authorization que
/// inyecta AuthInterceptor ya está presente, así que el cURL reproduce
/// el request tal cual salió.
void _logHttpExchange(
  RequestOptions options,
  int? statusCode,
  dynamic responseData,
) {
  final buffer = StringBuffer()
    ..writeln('┌─ HTTP ${options.method} ${options.uri} ─');
  options.headers.forEach((k, v) => buffer.writeln('│   $k: $v'));
  if (options.data != null) {
    buffer
      ..writeln('│   body:')
      ..writeln(_prettyJson(options.data));
  }
  buffer
    ..writeln('├─ cURL (Postman → Import → Raw text) ─')
    ..writeln(_toCurl(options))
    ..writeln('└─ status: ${statusCode ?? '-'} ─');
  if (responseData != null) buffer.writeln(_prettyJson(responseData));
  // ignore: avoid_print
  print(buffer.toString());
}

String _toCurl(RequestOptions o) {
  final sb = StringBuffer("curl -X ${o.method} '${o.uri}'");
  o.headers.forEach((k, v) => sb.write(" \\\n  -H '$k: $v'"));
  if (o.data != null) {
    try {
      sb.write(" \\\n  -d '${jsonEncode(o.data)}'");
    } catch (_) {
      // FormData/bytes no son jsonEncode-able — el body legible ya salió arriba.
    }
  }
  return sb.toString();
}

String _prettyJson(dynamic data) {
  try {
    return const JsonEncoder.withIndent('  ').convert(data);
  } catch (_) {
    return data.toString();
  }
}
