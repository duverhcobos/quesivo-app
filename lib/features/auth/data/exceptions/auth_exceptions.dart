// lib/features/auth/data/exceptions/auth_exceptions.dart

// Excepciones puras de la capa de Datos (Infraestructura).
//
// SOLID (DIP): Al crear nuestras propias excepciones de Data, evitamos que el
// Repository dependa explícitamente de excepciones de librerías de terceros
// como `DioException` o `SocketException` de Http.
// Ambos clientes (Dio o Http) lanzarán estas excepciones estandarizadas.

class RestApiException implements Exception {
  final int statusCode;
  final String message;

  RestApiException({required this.statusCode, required this.message});
}

class UnauthorizedException extends RestApiException {
  UnauthorizedException()
    : super(statusCode: 401, message: 'Invalid credentials');
}

class ServerException extends RestApiException {
  ServerException() : super(statusCode: 500, message: 'Internal server error');
}
