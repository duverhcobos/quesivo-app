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

import '../deeplink/i_deep_link_service.dart';
import '../deeplink/app_links_deep_link_service_impl.dart';
import '../logging/interfaces/i_logger_service.dart';
import '../logging/implementations/debug_logger_service_impl.dart';
import '../logging/implementations/crashlytics_logger_service_impl.dart';

import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../network/interfaces/i_network_info.dart';
import '../network/implementations/network_info_impl.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';
import '../../features/auth/data/datasources/interfaces/i_google_auth_datasource.dart';
import '../../features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart';
import '../../features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';
import '../../features/auth/data/datasources/implementations/google_auth_datasource_impl.dart';
import '../../features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart';
import '../../features/auth/data/datasources/implementations/secure_local_auth_datasource_impl.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';

import '../../features/auth/domain/use_cases/accept_invite_use_case.dart';
import '../../features/auth/domain/use_cases/accept_org_invite_use_case.dart';
import '../../features/auth/domain/use_cases/decline_org_invite_use_case.dart';
import '../../features/auth/domain/use_cases/login_use_case.dart';
import '../../features/auth/domain/use_cases/login_with_google_use_case.dart';
import '../../features/auth/domain/use_cases/check_auth_status_use_case.dart';
import '../../features/auth/domain/use_cases/logout_use_case.dart';
import '../../features/auth/domain/use_cases/forgot_password_use_case.dart';
import '../../features/auth/domain/use_cases/register_use_case.dart';
import '../../features/auth/domain/use_cases/resend_verification_use_case.dart';
import '../../features/auth/domain/use_cases/reset_password_use_case.dart';
import '../../features/auth/domain/use_cases/select_organization_use_case.dart';
import '../../features/auth/domain/use_cases/verify_email_use_case.dart';
import '../../features/auth/presentation/cubit/accept_invite_cubit.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/check_email_cubit.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/presentation/cubit/register_cubit.dart';
import '../../features/auth/presentation/cubit/reset_password_cubit.dart';
import '../../features/auth/presentation/cubit/verify_email_cubit.dart';
import '../../features/users/data/datasources/implementations/remote_users_datasource_impl.dart';
import '../../features/users/data/datasources/interfaces/i_remote_users_datasource.dart';
import '../../features/users/data/repositories/users_repository_impl.dart';
import '../../features/users/domain/repositories/i_users_repository.dart';
import '../../features/users/domain/use_cases/create_user_use_case.dart';
import '../../features/users/domain/use_cases/link_user_use_case.dart';
import '../../features/users/domain/use_cases/list_users_use_case.dart';
import '../../features/users/domain/use_cases/remove_org_member_use_case.dart';
import '../../features/users/domain/use_cases/resend_invite_use_case.dart';
import '../../features/users/domain/use_cases/update_user_password_use_case.dart';
import '../../features/users/domain/use_cases/update_user_role_use_case.dart';
import '../../features/users/domain/use_cases/update_user_status_use_case.dart';
import '../../features/users/presentation/cubit/create_user_cubit.dart';
import '../../features/users/presentation/cubit/link_user_cubit.dart';
import '../../features/users/presentation/cubit/reset_password_cubit.dart'
    as users_reset_password;
import '../../features/users/presentation/cubit/users_list_cubit.dart';
import '../../features/organization/data/datasources/implementations/remote_organization_datasource_impl.dart';
import '../../features/organization/data/datasources/interfaces/i_remote_organization_datasource.dart';
import '../../features/organization/data/repositories/organization_repository_impl.dart';
import '../../features/organization/domain/repositories/i_organization_repository.dart';
import '../../features/organization/domain/use_cases/skip_org_name_setup_use_case.dart';
import '../../features/organization/domain/use_cases/update_organization_name_use_case.dart';
import '../../features/organization/presentation/cubit/org_name_setup_cubit.dart';
import '../../features/queseras/presentation/cubit/org_invites_cubit.dart';
import '../../features/queseras/presentation/cubit/quesera_selection_cubit.dart';
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
  // SDK de Google Sign-In (propuesta 70): wrapper fino del plugin —
  // initialize() es lazy en el primer uso, no bloquea el arranque.
  locator.registerLazySingleton<IGoogleAuthDataSource>(
    () => GoogleAuthDataSourceImpl(),
  );

  // 3. Repositories
  locator.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(
      locator<IRemoteAuthDataSource>(),
      locator<IGoogleAuthDataSource>(),
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
  locator.registerLazySingleton(
    () => VerifyEmailUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => AcceptInviteUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => ResendVerificationUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => SelectOrganizationUseCase(locator<IAuthRepository>()),
  );
  // §69 — invitaciones de org (backend 072): accept/decline de la capa
  // personal + cancelación admin.
  locator.registerLazySingleton(
    () => AcceptOrgInviteUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => DeclineOrgInviteUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton(
    () => RemoveOrgMemberUseCase(locator<IUsersRepository>()),
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
  locator.registerFactoryParam<CheckEmailCubit, String, void>(
    (email, _) =>
        CheckEmailCubit(locator<ResendVerificationUseCase>(), email: email),
  );
  locator.registerFactoryParam<VerifyEmailCubit, String, String>(
    (token, email) => VerifyEmailCubit(
      locator<VerifyEmailUseCase>(),
      locator<ResendVerificationUseCase>(),
      token: token,
      email: email,
    ),
  );
  // §68 — Email-C: token + email del deep link `quesivo://accept-invite?…`.
  locator.registerFactoryParam<AcceptInviteCubit, String, String>(
    (token, email) => AcceptInviteCubit(
      locator<AcceptInviteUseCase>(),
      locator<ResendVerificationUseCase>(),
      token: token,
      email: email,
    ),
  );

  // Capa personal (§55/§56): cubit del tap en card de quesera —
  // factory, nace y muere con el QueseraHeroCarousel del Inicio.
  locator.registerFactory(
    () => QueseraSelectionCubit(
      locator<SelectOrganizationUseCase>(),
      locator<AuthCubit>(),
    ),
  );

  // §69 — cards de invitación de la capa personal: factory, nace y
  // muere con OrgInvitesSection.
  locator.registerFactory(
    () => OrgInvitesCubit(
      locator<AcceptOrgInviteUseCase>(),
      locator<DeclineOrgInviteUseCase>(),
      locator<AuthCubit>(),
    ),
  );

  // ── Módulo Usuarios ──
  locator.registerLazySingleton<IRemoteUsersDataSource>(
    () => RemoteUsersDataSourceImpl(locator<INetworkService>()),
  );
  locator.registerLazySingleton<IUsersRepository>(
    () => UsersRepositoryImpl(
      locator<IRemoteUsersDataSource>(),
      locator<INetworkInfo>(),
      locator<ILoggerService>(),
    ),
  );
  locator.registerLazySingleton(
    () => CreateUserUseCase(locator<IUsersRepository>()),
  );
  locator.registerLazySingleton(
    () => LinkUserUseCase(locator<IUsersRepository>()),
  );
  locator.registerLazySingleton(
    () => ListUsersUseCase(locator<IUsersRepository>()),
  );
  locator.registerLazySingleton(
    () => UpdateUserStatusUseCase(locator<IUsersRepository>()),
  );
  locator.registerLazySingleton(
    () => UpdateUserPasswordUseCase(locator<IUsersRepository>()),
  );
  locator.registerLazySingleton(
    () => UpdateUserRoleUseCase(locator<IUsersRepository>()),
  );
  // §68 — Email-C: reenvío de la invitación (POST /users/:id/resend-invite).
  locator.registerLazySingleton(
    () => ResendInviteUseCase(locator<IUsersRepository>()),
  );
  // Cubits de sheet: factory — nacen y mueren con cada apertura.
  locator.registerFactory(() => CreateUserCubit(locator<CreateUserUseCase>()));
  locator.registerFactory(() => LinkUserCubit(locator<LinkUserUseCase>()));
  // §52 — cubit del sheet de reset de contraseña (users). Prefijo en el
  // import: auth ya tiene un ResetPasswordCubit propio.
  locator.registerFactory(
    () => users_reset_password.ResetPasswordCubit(
      locator<UpdateUserPasswordUseCase>(),
    ),
  );
  // Cubit del listado (§49): factory — efímero como los demás del
  // módulo, nace con la pantalla y dispara el primer load().
  locator.registerFactory(
    () => UsersListCubit(
      locator<ListUsersUseCase>(),
      locator<UpdateUserStatusUseCase>(),
      locator<UpdateUserRoleUseCase>(),
      locator<ResendInviteUseCase>(),
      locator<RemoveOrgMemberUseCase>(),
    ),
  );

  // ── Módulo Organization (§71 — backend 087: PATCH /organizations/me) ──
  locator.registerLazySingleton<IRemoteOrganizationDataSource>(
    () => RemoteOrganizationDataSourceImpl(locator<INetworkService>()),
  );
  locator.registerLazySingleton<IOrganizationRepository>(
    () => OrganizationRepositoryImpl(
      locator<IRemoteOrganizationDataSource>(),
      locator<ILocalAuthDataSource>(),
      locator<INetworkInfo>(),
      locator<ILoggerService>(),
    ),
  );
  locator.registerFactory(
    () => UpdateOrganizationNameUseCase(locator<IOrganizationRepository>()),
  );
  locator.registerFactory(
    () => SkipOrgNameSetupUseCase(locator<IOrganizationRepository>()),
  );
  // Factory — nace y muere con la pantalla de nombrado; el AuthCubit
  // global se inyecta para aplicar el rename/limpiar el flag sin /me.
  locator.registerFactory(
    () => OrgNameSetupCubit(
      locator<UpdateOrganizationNameUseCase>(),
      locator<SkipOrgNameSetupUseCase>(),
      // La pantalla va antes del home: con sesión personal el submit
      // entra a la org del signup por debajo (select-organization) antes
      // del PATCH — el endpoint pide token org-scoped.
      locator<SelectOrganizationUseCase>(),
      locator<AuthCubit>(),
    ),
  );

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

  // Deep link de forgot/reset password (propuesta 66) — se inicializa
  // desde main.dart una vez que el router ya existe. `onOrgInvites`
  // (§69): tras aterrizar en /home por un quesivo://org-invites se
  // refetchea /me en silencio — el invitado con sesión viva ve la card
  // sin re-login.
  locator.registerLazySingleton<IDeepLinkService>(
    () => AppLinksDeepLinkServiceImpl(
      locator<ILoggerService>(),
      onOrgInvites: () => locator<AuthCubit>().refreshSessionSilently(),
    ),
  );
}
