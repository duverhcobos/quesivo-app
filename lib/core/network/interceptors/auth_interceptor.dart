// lib/core/network/interceptors/auth_interceptor.dart
import 'package:dio/dio.dart';
import '../../../features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';

/// Interceptor responsable de inyectar el Token JWT en cada petición.
///
/// SOLID (SRP): Extrae la lógica de autenticación HTTP fuera del DataSource
/// o del ApiService maestro, permitiendo escalarlo o testearlo aisladamente.
class AuthInterceptor extends Interceptor {
  final ILocalAuthDataSource localDataSource;

  AuthInterceptor(this.localDataSource);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await localDataSource.getToken();

    // Si existe el token, se inyecta en la cabecera estándar de Autorización
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    super.onRequest(options, handler);
  }
}
