import 'package:dio/dio.dart';
import 'package:quesivo/features/auth/data/exceptions/auth_exceptions.dart';
import '../interfaces/i_network_service.dart';

/// Implementación del cliente de Red usando Dio.
class DioNetworkServiceImpl implements INetworkService {
  final Dio dio;

  DioNetworkServiceImpl(this.dio);

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.get<T>(path, queryParameters: queryParameters);
      return response.data as T;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<T> post<T>(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await dio.post<T>(path, data: data);
      // Dio ya parsea el JSON y lo expone como T en response.data
      return response.data as T;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw ServerException();
    }
  }

  Never _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 500;
      if (statusCode == 401 || statusCode == 400) {
        throw UnauthorizedException();
      }
      throw RestApiException(
        statusCode: statusCode,
        message: e.response!.statusMessage ?? 'Error desconocido',
      );
    } else {
      // Error de red (sin internet, timeout)
      throw ServerException();
    }
  }
}
