// lib/features/auth/data/datasources/interfaces/i_local_auth_datasource.dart

import '../../models/user_model.dart';

/// Contrato para el Datasource local de Autenticación.
///
/// SOLID (ISP): Se independiza la obtención y guardado local de las
/// operaciones de red (RemoteAuthDataSource).
abstract class ILocalAuthDataSource {
  Future<void> saveUserSession(UserModel user);
  Future<UserModel?> getUserSession();

  Future<void> saveTokens({
    required String token,
    required String refreshToken,
  });
  Future<String?> getToken();
  Future<String?> getRefreshToken();

  Future<void> clearSession();
}
