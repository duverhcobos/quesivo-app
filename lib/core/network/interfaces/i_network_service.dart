// lib/core/network/i_network_service.dart

/// Contrato para el cliente Http de la aplicación.
///
/// Al crear esta interfaz, los DataSources (como AuthDataSource) ya no
/// dependerán de "Dio" ni de "Http", sino de este contrato.
///
/// Los métodos son genéricos (`Future<T>`): el DataSource declara el tipo
/// que espera recibir (ej. `Map<String, dynamic>`) y la implementación
/// castea el body parseado, en vez de devolver `dynamic` sin tipado.
abstract class INetworkService {
  Future<T> post<T>(String path, {Map<String, dynamic>? data});
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters});
  Future<T> patch<T>(String path, {Map<String, dynamic>? data});

  /// Sin body — el identificador viaja en el path (ej. `DELETE
  /// /auth/users/:id`, backend 072). Devuelve el body parseado si lo hay
  /// (los 204 llegan como null → `delete<void>`).
  Future<T> delete<T>(String path);
}
