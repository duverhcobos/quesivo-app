// lib/features/auth/data/datasources/remote_auth_datasource_impl.dart
import '../../../../../core/constants/environment/environment.dart';
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

  RemoteAuthDataSourceImpl(this.networkService);

  @override
  Future<UserModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // El backend real (stg/prod) espera un email real en el body de login.
    // El truco de convertirlo en "username" es EXCLUSIVO de DummyJSON (dev),
    // que exige nombres de usuario puros (ej. 'emilys') y no acepta '@'.
    // Fuera de `dev` este bloque nunca se ejecuta, evitando que un backend
    // real reciba un payload con forma incorrecta.
    final body = Environment.currentEnvironment == EnvType.dev
        ? {
            'username': email.contains('@') ? email.split('@')[0] : email,
            'password': password,
          }
        : {'email': email, 'password': password};

    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/login',
      data: body,
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
    // ⚠️ MOCK EXCLUSIVO DE DESARROLLO: DummyJSON no expone /auth/register.
    // En stg/prod se llama al endpoint real del backend Quesera
    // (planeaciones/001 §3.1: organización + usuario admin en una
    // transacción atómica — el nombre de la quesera viaja en el payload).
    if (Environment.currentEnvironment == EnvType.dev) {
      await Future.delayed(const Duration(seconds: 1));
      return UserModel(id: '3', email: email, name: name);
    }

    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'organizationName': organizationName,
        'name': name,
        'email': email,
        'password': password,
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
}
