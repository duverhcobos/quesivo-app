import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:quesivo/features/auth/data/exceptions/auth_exceptions.dart';
import '../../constants/environment/environment.dart';
import '../interfaces/i_network_service.dart';

/// Implementación del cliente de Red usando Http.
class HttpNetworkServiceImpl implements INetworkService {
  final http.Client client;
  // Antes estaba hardcodeado a DummyJSON; ahora respeta el entorno activo
  // igual que DioNetworkServiceImpl/AuthApiService.
  String get baseUrl => Environment.urlAuth;

  HttpNetworkServiceImpl(this.client);

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$path',
      ).replace(queryParameters: queryParameters);
      final response = await client.get(uri);
      return _processResponse<T>(response);
    } catch (e) {
      if (e is RestApiException) rethrow;
      throw ServerException();
    }
  }

  @override
  Future<T> post<T>(String path, {Map<String, dynamic>? data}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return _processResponse<T>(response);
    } catch (e) {
      if (e is RestApiException) rethrow;
      throw ServerException();
    }
  }

  T _processResponse<T>(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as T;
    } else if (response.statusCode == 401 || response.statusCode == 400) {
      throw UnauthorizedException();
    } else {
      throw RestApiException(
        statusCode: response.statusCode,
        message: 'Http Error',
      );
    }
  }
}
