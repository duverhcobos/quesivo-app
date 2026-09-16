// lib/features/auth/data/datasources/secure_local_auth_datasource_impl.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/user_model.dart';
import '../interfaces/i_local_auth_datasource.dart';

/// Implementación del almacenamiento local seguro.
/// Utiliza Keychain en iOS y EncryptedSharedPreferences en Android.
class SecureLocalAuthDataSourceImpl implements ILocalAuthDataSource {
  final FlutterSecureStorage secureStorage;

  static const _userKey = 'cached_user_session';
  static const _tokenKey = 'auth_jwt_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  SecureLocalAuthDataSourceImpl(this.secureStorage);

  @override
  Future<void> saveUserSession(UserModel user) async {
    // Solo se persiste el PERFIL (sin tokens) bajo _userKey. Los tokens viven
    // únicamente en sus propias claves (_tokenKey/_refreshTokenKey) para que
    // no existan dos fuentes de verdad que puedan desincronizarse, por
    // ejemplo tras un refresh de token que solo actualice esas claves.
    final profileOnly = UserModel(
      id: user.id,
      email: user.email,
      name: user.name,
      organizationId: user.organizationId,
      organizationName: user.organizationName,
      roles: user.roles,
    );
    final jsonString = jsonEncode(profileOnly.toJson());
    await secureStorage.write(key: _userKey, value: jsonString);

    if (user.token != null) {
      await saveTokens(
        token: user.token!,
        refreshToken: user.refreshToken ?? '',
      );
    }
  }

  @override
  Future<UserModel?> getUserSession() async {
    final jsonString = await secureStorage.read(key: _userKey);
    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      final Map<String, dynamic> map = jsonDecode(jsonString);
      final profile = UserModel.fromJson(map);

      // Los tokens siempre se leen "en vivo" desde su propia clave, nunca
      // desde el JSON cacheado del perfil.
      final token = await getToken();
      final refreshToken = await getRefreshToken();

      return UserModel(
        id: profile.id,
        email: profile.email,
        name: profile.name,
        organizationId: profile.organizationId,
        organizationName: profile.organizationName,
        roles: profile.roles,
        token: token,
        refreshToken: refreshToken,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveTokens({
    required String token,
    required String refreshToken,
  }) async {
    await secureStorage.write(key: _tokenKey, value: token);
    await secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<String?> getToken() async {
    return await secureStorage.read(key: _tokenKey);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await secureStorage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> clearSession() async {
    // Borra únicamente las claves de autenticación. Evita destruir datos
    // seguros de otras features que puedan usar FlutterSecureStorage en el futuro.
    await secureStorage.delete(key: _userKey);
    await secureStorage.delete(key: _tokenKey);
    await secureStorage.delete(key: _refreshTokenKey);
  }
}
