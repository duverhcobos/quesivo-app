// lib/features/auth/data/datasources/remote_auth_datasource_impl.dart
import '../../../../../core/constants/environment/environment.dart';
import '../../../../../core/device/i_device_info_service.dart';
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/organization_session_model.dart';
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
  Future<void> register({
    required String organizationName,
    required String name,
    required String email,
    required String password,
  }) async {
    // Backend real en todos los entornos — contrato
    // documentacion/api/auth/001-post-register.md (propuesta backend
    // 069): 201 con body vacío, la cuenta queda pending_verification.
    // deviceId/deviceName se siguen enviando: el DTO los acepta (los
    // ignora — no hay sesión que etiquetar) y quitarlos rompería contra
    // un backend viejo que aún los exige.
    await networkService.post<void>(
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
  }

  @override
  Future<void> forgotPassword(String email) async {
    // Backend real en todos los entornos (propuesta backend 068) —
    // contrato documentacion/api/auth/013-post-forgot-password.md:
    // siempre 200, nunca revela si el email existe.
    await networkService.post<void>(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    // Backend real en todos los entornos (propuesta backend 068) —
    // contrato documentacion/api/auth/014-post-reset-password.md.
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

  @override
  Future<OrganizationSessionModel> selectOrganization(
    String organizationId,
  ) async {
    // Real en todos los entornos (propuesta backend 064) — contrato
    // documentacion/api/auth/006-post-select-organization.md. El Bearer
    // actual lo inyecta AuthInterceptor; el backend valida la membresía.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/select-organization',
      data: {'organizationId': organizationId},
    );
    return OrganizationSessionModel.fromJson(responseData);
  }

  @override
  Future<UserModel> verifyEmail(String token) async {
    // Contrato real (documentacion/api/auth/015-post-verify-email.md):
    // la sesión emitida es PERSONAL (sin org) — igual que login.
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/verify-email',
      data: {
        'token': token,
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );
    return UserModel.fromJson(responseData);
  }

  @override
  Future<void> resendVerification(String email) async {
    // Contrato real (documentacion/api/auth/016-post-resend-verification.md):
    // siempre 200 — anti-enumeración.
    await networkService.post<void>(
      '/auth/resend-verification',
      data: {'email': email},
    );
  }
}
