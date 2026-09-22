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

  @override
  Future<T> patch<T>(String path, {Map<String, dynamic>? data}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await client.patch(
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
    } else if (response.statusCode == 401) {
      throw UnauthorizedException();
    } else {
      throw RestApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response.body),
        errorCode: _extractErrorCode(response.body),
      );
    }
  }

  /// Mismo shape que el servicio Dio: `message` del body NestJS puede ser
  /// string o array de strings (validación) — se toma el primero.
  String _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) return 'Http Error';
      final message = data['message'];
      if (message is String) return message;
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
      return 'Http Error';
    } catch (_) {
      return 'Http Error';
    }
  }

  /// Paridad con el servicio Dio — mismo campo `errorCode` del
  /// DomainExceptionFilter.
  String? _extractErrorCode(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) return null;
      final code = data['errorCode'];
      return code is String ? code : null;
    } catch (_) {
      return null;
    }
  }
}
