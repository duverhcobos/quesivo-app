// lib/features/auth/data/datasources/remote_auth_datasource_impl.dart
import '../../../../../core/constants/environment/environment.dart';
import '../../../../../core/device/i_device_info_service.dart';
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/user_model.dart';
import '../interfaces/i_remote_auth_datasource.dart';

/// Implementación ÚNICA del DataSource remoto.
///
/// SOLID (DIP): Ahora esta clase no depende ni de Dio ni de Http.
/// Depende del `INetworkService` central de la app. Si cambias
/// el proveedor de red, esta clase NUNCA cambiará.
class RemoteAuthDataSourceImpl implements IRemoteAuthDataSource {
  final INetworkService networkService;
  final IDeviceInfoService deviceInfoService;

  RemoteAuthDataSourceImpl(this.networkService, this.deviceInfoService);

  @override
  Future<UserModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // Backend real en todos los entornos (propuesta 36) — contrato
    // documentacion/api/auth/002-post-login.md.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        // Metadatos del dispositivo para la sesión (propuesta 43) —
        // opcionales server-side; sin ellos el logout no agrupa por device.
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );

    // Mapeamos el JSON dinámico devuelto al Modelo y fin.
    return UserModel.fromJson(responseData);
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    // ⚠️ MOCK EXCLUSIVO DE DESARROLLO: todavía no existe integración real con
    // Google Sign-In. Se bloquea explícitamente fuera de `dev` para que nunca
    // llegue a producción un login "exitoso" falso.
    if (Environment.currentEnvironment != EnvType.dev) {
      throw UnimplementedError(
        'Login con Google no está implementado para este entorno todavía.',
      );
    }

    await Future.delayed(const Duration(seconds: 1));
    return const UserModel(
      id: '2',
      email: 'user@google.com',
      name: 'Google User',
    );
  }

  @override
  Future<UserModel> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    // Backend real en todos los entornos (propuesta 36) — contrato
    // documentacion/api/auth/001-post-register.md: organización + usuario
    // admin en una transacción atómica.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'organizationName': organizationName,
        'name': name,
        'email': email,
        'password': password,
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );
    return UserModel.fromJson(responseData);
  }

  @override
  Future<void> forgotPassword(String email) async {
    // ⚠️ MOCK EXCLUSIVO DE DESARROLLO: DummyJSON no expone este endpoint.
    // Se bloquea explícitamente fuera de `dev` para que la app nunca reporte
    // un "correo enviado" falso en staging/producción.
    if (Environment.currentEnvironment != EnvType.dev) {
      throw UnimplementedError(
        'Recuperación de contraseña no está implementada para este entorno todavía.',
      );
    }

    await Future.delayed(const Duration(seconds: 1));
    return;
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    // ⚠️ MOCK EXCLUSIVO DE DESARROLLO: DummyJSON no expone
    // /auth/reset-password. En stg/prod va al endpoint real del backend.
    if (Environment.currentEnvironment == EnvType.dev) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    }

    await networkService.post<void>(
      '/auth/reset-password',
      data: {'token': token, 'password': password},
    );
  }

  @override
  Future<UserModel> getMe() async {
    // Contrato real (documentacion/api/auth/005-get-me.md): identidad
    // resuelta del JWT — sin body ni params. Real en todos los entornos
    // (en dev apunta al backend local/Render igual que login).
    final responseData = await networkService.get<Map<String, dynamic>>(
      '/auth/me',
    );
    return UserModel.fromJson(responseData);
  }

  @override
  Future<void> logout(String refreshToken) async {
    // Real en todos los entornos (propuesta 42) — endpoint público desde
    // la propuesta backend 047: el body es la credencial a revocar.
    await networkService.post<void>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }
}
