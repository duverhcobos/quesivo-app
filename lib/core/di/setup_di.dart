// lib/core/di/setup_di.dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:get_it/get_it.dart';

import '../device/i_device_info_service.dart';
import '../device/device_info_service_impl.dart';
import '../network/api/auth_api_service.dart'; // Importamos tu AuthApiService
import '../network/interfaces/i_network_service.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../network/interceptors/refresh_token_interceptor.dart';
import '../network/implementations/dio_network_service_impl.dart';
import '../routes/app_router.dart';
import '../routes/auth_guard.dart';
import '../session/session_expired_notifier.dart';

import '../logging/interfaces/i_logger_service.dart';
import '../logging/implementations/debug_logger_service_impl.dart';
import '../logging/implementations/crashlytics_logger_service_impl.dart';

import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../network/interfaces/i_network_info.dart';
import '../network/implementations/network_info_impl.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../../features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart';
import '../../features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';
import '../../features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart';
import '../../features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';

import '../../features/auth/domain/use_cases/login_use_case.dart';
import '../../features/auth/domain/use_cases/login_with_google_use_case.dart';
import '../../features/auth/domain/use_cases/check_auth_status_use_case.dart';
import '../../features/auth/domain/use_cases/logout_use_case.dart';
import '../../features/auth/domain/use_cases/forgot_password_use_case.dart';
import '../../features/auth/domain/use_cases/register_use_case.dart';
import '../../features/auth/domain/use_cases/reset_password_use_case.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/presentation/cubit/register_cubit.dart';
import '../../features/auth/presentation/cubit/reset_password_cubit.dart';
import '../localization/cubit/locale_cubit.dart';

final locator = GetIt.instance;

void setupDI() {
  // 1. Core Tools
  // Aca inicializamos al AuthApiService y sacamos el dio ya purificado
  locator.registerLazySingleton<Dio>(() {
    final dio = AuthApiService().dio;

    // Inyectamos nuestros interceptores de Arquitectura Limpia
    dio.interceptors.add(AuthInterceptor(locator<ILocalAuthDataSource>()));
    // Dio "limpio" de refresh: misma config que el principal (timeouts
    // 30s, cert auto-firmado solo en dev LAN, logging dev) pero SIN
    // AuthInterceptor/RefreshTokenInterceptor — esos se agregan solo
    // sobre `dio` acá, así que no hay recursión. Instancia única: una
    // por app alcanza, no una por refresh.
    final refreshDio = AuthApiService().dio;
    dio.interceptors.add(
      RefreshTokenInterceptor(
        locator<ILocalAuthDataSource>(),
        locator<SessionExpiredNotifier>(),
        () =>
            dio, // Closure: para cuando se use ya existe la instancia completa.
        () => refreshDio,
      ),
    );

    return dio;
  });

  locator.registerLazySingleton<http.Client>(() => http.Client());

  // 0. Logging System
  // Detecta automáticamente si la app fue compilada en modo Release (Producción)
  const bool isProduction = bool.fromEnvironment('dart.vm.product');

  locator.registerLazySingleton<ILoggerService>(
    () => isProduction
        ? CrashlyticsLoggerServiceImpl()
        : DebugLoggerServiceImpl(),
  );

  // Storage
  locator.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // Evento "sesión irrecuperable": emitido por RefreshTokenInterceptor,
  // consumido por AuthCubit.
  locator.registerLazySingleton<SessionExpiredNotifier>(
    () => SessionExpiredNotifier(),
    dispose: (notifier) => notifier.dispose(),
  );

  // El flag "onboarding ya visto" (IOnboardingStatusStore) NO se registra acá:
  // SharedPreferences se inicializa async, así que se crea cargado y se
  // registra como singleton síncrono en AppBootstrap — un get() sobre una
  // registración async sin resolver devuelve null en runtime.

  // Connection Checker
  locator.registerLazySingleton<InternetConnectionChecker>(
    () => InternetConnectionChecker.instance,
  );

  // 1.5 Network Services Wrapper
  // ACA DECIDES QUIEN RESPONDERÁ POR TODA LA APP (DIO O HTTP)
  locator.registerLazySingleton<INetworkService>(
    () => DioNetworkServiceImpl(locator<Dio>()),
    // () => HttpNetworkServiceImpl(locator<http.Client>()),
  );

  // 2. DataSources
  locator.registerLazySingleton<INetworkInfo>(
    () => NetworkInfoImpl(locator<InternetConnectionChecker>()),
  );
  locator.registerLazySingleton<IDeviceInfoService>(
    () => DeviceInfoServiceImpl(DeviceInfoPlugin()),
  );
  locator.registerLazySingleton<IRemoteAuthDataSource>(
    // EL DATASOURCE AHORA ES ÚNICO Y GENÉRICO
    () => RemoteAuthDataSourceImpl(
      locator<INetworkService>(),
      locator<IDeviceInfoService>(),
    ),
  );
  locator.registerLazySingleton<ILocalAuthDataSource>(
    () => SecureLocalAuthDataSourceImpl(locator<FlutterSecureStorage>()),
  );

  // 3. Repositories
  locator.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(
      locator<IRemoteAuthDataSource>(),
      locator<ILocalAuthDataSource>(),
      locator<INetworkInfo>(),
      locator<ILoggerService>(),
    ),
  );

  // 4. Use Cases
  locator.registerLazySingleton(() => LoginUseCase(locator<IAuthRepository>()));
  locator.registerLazySingleton(
    () => LoginWithGoogleUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => CheckAuthStatusUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => LogoutUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => ForgotPasswordUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => ResetPasswordUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => RegisterUseCase(locator<IAuthRepository>()),
  );

  // 5. Blocs / Cubits
  // CRÍTICO: Debe ser LazySingleton para que GoRouter y la UI compartan la misma instancia.
  locator.registerLazySingleton<LocaleCubit>(() => LocaleCubit());

  locator.registerLazySingleton(
    () => AuthCubit(
      locator<LoginUseCase>(),
      locator<LoginWithGoogleUseCase>(),
      locator<CheckAuthStatusUseCase>(),
      locator<LogoutUseCase>(),
      locator<SessionExpiredNotifier>(),
    ),
  );

  // Cubits de Pantalla (Presentation Logic Local) usan Factory
  // para morir y nacer frescos cada vez que el usuario entre a la pantalla.
  locator.registerFactory(() => LoginCubit(locator<LoginUseCase>()));
  locator.registerFactory(
    () => ForgotPasswordCubit(locator<ForgotPasswordUseCase>()),
  );
  locator.registerFactoryParam<ResetPasswordCubit, String, void>(
    (token, _) =>
        ResetPasswordCubit(locator<ResetPasswordUseCase>(), token: token),
  );
  locator.registerFactory(() => RegisterCubit(locator<RegisterUseCase>()));

  // 6. Router Automático
  // AuthGuard se inyecta con su logger por constructor (DIP), y es
  // independiente de go_router: solo conoce Strings y AuthState.
  locator.registerLazySingleton<AuthGuard>(
    () =>
        AuthGuard(locator<ILoggerService>(), locator<IOnboardingStatusStore>()),
  );

  // Le pasamos el AuthCubit global para que escuche sus estados
  locator.registerLazySingleton<AppRouter>(
    () => AppRouter(locator<AuthCubit>(), locator<AuthGuard>()),
  );
}
