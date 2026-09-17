# Propuesta: Integrar refresh token real + notificación de sesión expirada

El pipeline de refresh **ya existe y está cableado** (`RefreshTokenInterceptor`
registrado en `setup_di.dart`, `AuthInterceptor` inyectando Bearer vivo,
login/register persistiendo `accessToken`+`refreshToken`). Su contrato
coincide con el real del backend (`documentacion/api/auth/003-post-refresh.md`:
`POST /auth/refresh` `{refreshToken}` → `{accessToken, refreshToken}` rotatorio).

Lo que falta para que el refresh sea **funcional de punta a punta**:

1. **Sesión zombie**: si el refresh falla (token revocado/expirado/reusado),
   el interceptor limpia el storage pero nadie avisa al `AuthCubit` — la UI
   sigue mostrando `AuthSuccess` hasta reiniciar la app. Falta un canal
   interceptor → cubit → `AuthInitial` → `AuthGuard` redirige a welcome
   (el router ya re-evalúa en cada emisión vía `GoRouterRefreshStream`).
2. **Requests concurrentes se caen**: `_isRefreshing` (bool) hace que un
   segundo request que llega a 401 durante un refresh en vuelo falle
   directo en vez de esperar y reintentar con el token ya renovado.
3. **Sin guard anti-loop**: un request reintentado que volviera a dar 401
   re-entraría al flujo de refresh.
4. **No testeable**: el `Dio` de refresh se crea dentro de `onError`
   (`Dio(BaseOptions(...))` hardcodeado) — imposible mockear en unit tests.
5. Comentario `PROVISIONAL` obsoleto — el contrato ya está confirmado.

Detalle de seguridad del backend relevante: reuso de un refresh token
rotado → 401 + revoca TODAS las sesiones (`TOKEN_REUSE_DETECTED`). Ese
caso cae en el camino "refresh falló" → clear + notify, correcto.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/session/session_expired_notifier.dart` | **Nuevo** — bus broadcast "sesión irrecuperable" |
| `lib/core/network/interceptors/refresh_token_interceptor.dart` | Reescrito — single-flight con `Completer`, guard anti-loop, notifier, Dio inyectable |
| `lib/features/auth/presentation/cubit/auth_cubit.dart` | Suscripción al notifier → `AuthInitial` si `AuthSuccess` + `close()` |
| `lib/core/di/setup_di.dart` | Registrar notifier, pasarlo a interceptor y cubit, `refreshDioProvider` |
| `test/features/auth/presentation/cubit/auth_cubit_test.dart` | Ctor nuevo param + test sesión expirada |
| `test/core/network/interceptors/refresh_token_interceptor_test.dart` | **Nuevo** — tests del flujo completo |

Sin cambios de i18n, sin dependencias nuevas, sin rutas.

---

## 1. session_expired_notifier.dart (archivo nuevo)

**Ruta:** `lib/core/session/session_expired_notifier.dart`

```dart
// lib/core/session/session_expired_notifier.dart
import 'dart:async';

/// Bus de evento "la sesión ya no es recuperable".
///
/// Lo emite la capa de red (`RefreshTokenInterceptor`) cuando el refresh
/// token resulta inválido, expirado o revocado — el storage seguro ya
/// quedó limpio antes de notificar. Lo consume `AuthCubit` para emitir
/// `AuthInitial`, y `AuthGuard` redirige a welcome automáticamente
/// (`GoRouterRefreshStream` ya re-evalúa redirects en cada emisión).
///
/// Broadcast porque puede haber más de un listener a futuro (analytics,
/// logging). No expone datos: el evento es solo "sesión muerta".
class SessionExpiredNotifier {
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notifySessionExpired() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
```

## 2. refresh_token_interceptor.dart (archivo existente — reescrito)

**Ruta:** `lib/core/network/interceptors/refresh_token_interceptor.dart`

**Antes:** el archivo entero es la versión provisional (bool `_isRefreshing`,
`Dio(...)` inline, sin notificación de sesión).

**Después:** (archivo completo — reemplazo total)

```dart
// lib/core/network/interceptors/refresh_token_interceptor.dart
import 'dart:async';
import 'package:dio/dio.dart';

import '../../../features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';
import '../../session/session_expired_notifier.dart';

/// Interceptor responsable de capturar errores 401 y refrescar el token.
///
/// SOLID (SRP): Aísla toda la coreografía de "token expiró -> refrescar ->
/// reintentar" fuera del resto de la capa de red.
///
/// Contrato real (documentacion/api/auth/003-post-refresh.md, quesivo-api):
/// `POST /auth/refresh` con body `{ "refreshToken": "..." }` responde 200
/// `{ "accessToken": "...", "refreshToken": "..." }`. El refresh token
/// ROTA en cada llamada — el enviado queda revocado y hay que persistir
/// siempre el nuevo. Un 401 ahí significa sesión irrecuperable (token
/// inválido, expirado, o reuso detectado que revocó todas las sesiones):
/// se limpia storage y se notifica vía [SessionExpiredNotifier].
class RefreshTokenInterceptor extends Interceptor {
  final ILocalAuthDataSource localDataSource;
  final SessionExpiredNotifier sessionExpiredNotifier;

  /// Dio "principal" (con todos sus interceptores) para reintentar la
  /// petición original una vez refrescado el token. Se inyecta como
  /// función porque el propio Dio principal es quien registra este
  /// interceptor (evita dependencia circular en el contenedor de DI).
  final Dio Function() mainDioProvider;

  /// Dio "limpio" (sin interceptores) exclusivo para llamar al endpoint
  /// de refresh: evita recursión si este mismo interceptor volviera a
  /// interceptar su propia llamada. Inyectado para poder testearlo.
  final Dio Function() refreshDioProvider;

  /// Single-flight: un solo refresh en vuelo a la vez. Los 401 que llegan
  /// mientras hay un refresh corriendo esperan este completer y reintentan
  /// UNA vez con el token ya persistido (en vez de fallar directo).
  Completer<void>? _refreshCompleter;

  RefreshTokenInterceptor(
    this.localDataSource,
    this.sessionExpiredNotifier,
    this.mainDioProvider,
    this.refreshDioProvider,
  );

  static const String _refreshPath = '/auth/refresh';

  /// Marca en `RequestOptions.extra` de que el request ya fue reintentado
  /// tras un refresh. Si vuelve a dar 401 se propaga el error en vez de
  /// re-entrar al flujo (guard anti-loop).
  static const String _retriedFlag = 'refreshRetried';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshCallItself = err.requestOptions.path.contains(
      _refreshPath,
    );
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;

    // Solo entra al flujo de refresh un 401 de petición normal aún no
    // reintentada. El 401 del propio /auth/refresh o de un retry se
    // propaga tal cual (sin loops).
    if (!isUnauthorized || isRefreshCallItself || alreadyRetried) {
      return super.onError(err, handler);
    }

    // Otro request ya disparó el refresh: esperar a que termine y
    // reintentar UNA vez con el token ya guardado en storage.
    final inFlight = _refreshCompleter;
    if (inFlight != null) {
      try {
        await inFlight.future;
        return handler.resolve(await _retry(err.requestOptions));
      } catch (_) {
        return super.onError(err, handler);
      }
    }

    _refreshCompleter = Completer<void>();
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw StateError('no refresh token');
      }

      final refreshResponse = await refreshDioProvider().post(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );

      final data = refreshResponse.data as Map<String, dynamic>;
      final newToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newToken == null || newRefreshToken == null) {
        throw StateError('refresh response incompleta');
      }

      await localDataSource.saveTokens(
        token: newToken,
        refreshToken: newRefreshToken,
      );

      _refreshCompleter!.complete();
    } catch (_) {
      // Refresh falló (401 del endpoint, token reusado, red caída o
      // ausencia de refresh token): sesión irrecuperable. Limpiar y
      // avisar para que la UI salga a welcome.
      _refreshCompleter!.completeError(StateError('refresh failed'));
      await _expireSession();
      return super.onError(err, handler);
    } finally {
      _refreshCompleter = null;
    }

    // El refresh salió bien — reintentar el request original. Si el
    // retry falla, es error del request (o de otro refresh posterior),
    // no de esta sesión: se propaga tal cual.
    try {
      return handler.resolve(await _retry(err.requestOptions));
    } catch (_) {
      return super.onError(err, handler);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final token = await localDataSource.getToken();
    options.headers['Authorization'] = 'Bearer $token';
    options.extra[_retriedFlag] = true;
    return mainDioProvider().fetch(options);
  }

  Future<void> _expireSession() async {
    await localDataSource.clearSession();
    sessionExpiredNotifier.notifySessionExpired();
  }
}
```

## 3. auth_cubit.dart (archivo existente — actualización)

**Ruta:** `lib/features/auth/presentation/cubit/auth_cubit.dart`

**Antes:**

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/use_cases/login_use_case.dart';
import '../../domain/use_cases/login_with_google_use_case.dart';
import '../../domain/use_cases/check_auth_status_use_case.dart';
import '../../domain/use_cases/logout_use_case.dart';
import 'auth_state.dart';
```

```dart
  final LoginUseCase _loginUseCase;
  final LoginWithGoogleUseCase _loginWithGoogleUseCase;
  final CheckAuthStatusUseCase _checkAuthStatusUseCase;
  final LogoutUseCase _logoutUseCase;

  // Inyectado y testeable.
  AuthCubit(
    this._loginUseCase,
    this._loginWithGoogleUseCase,
    this._checkAuthStatusUseCase,
    this._logoutUseCase,
  ) : super(
        const AuthLoading(),
      ); // La app arranca siempre en estado MISTERIO (Cargando)
```

**Después:**

```dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_expired_notifier.dart';
import '../../domain/use_cases/login_use_case.dart';
import '../../domain/use_cases/login_with_google_use_case.dart';
import '../../domain/use_cases/check_auth_status_use_case.dart';
import '../../domain/use_cases/logout_use_case.dart';
import 'auth_state.dart';
```

```dart
  final LoginUseCase _loginUseCase;
  final LoginWithGoogleUseCase _loginWithGoogleUseCase;
  final CheckAuthStatusUseCase _checkAuthStatusUseCase;
  final LogoutUseCase _logoutUseCase;
  final SessionExpiredNotifier _sessionExpiredNotifier;

  late final StreamSubscription<void> _sessionExpiredSub;

  // Inyectado y testeable.
  AuthCubit(
    this._loginUseCase,
    this._loginWithGoogleUseCase,
    this._checkAuthStatusUseCase,
    this._logoutUseCase,
    this._sessionExpiredNotifier,
  ) : super(
        const AuthLoading(),
      ) {
    // La capa de red avisa cuando el refresh token murió (revocado,
    // expirado o reuso detectado): si el usuario estaba adentro de la
    // app, pasarlo a AuthInitial para que AuthGuard lo mande a welcome.
    _sessionExpiredSub = _sessionExpiredNotifier.stream.listen((_) {
      if (state is AuthSuccess) emit(const AuthInitial());
    });
  }

  @override
  Future<void> close() {
    _sessionExpiredSub.cancel();
    return super.close();
  }
```

## 4. setup_di.dart (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**

```dart
    dio.interceptors.add(AuthInterceptor(locator<ILocalAuthDataSource>()));
    dio.interceptors.add(
      RefreshTokenInterceptor(
        locator<ILocalAuthDataSource>(),
        () =>
            dio, // Closure: para cuando se use ya existe la instancia completa.
      ),
    );
```

**Después:**

```dart
    dio.interceptors.add(AuthInterceptor(locator<ILocalAuthDataSource>()));
    dio.interceptors.add(
      RefreshTokenInterceptor(
        locator<ILocalAuthDataSource>(),
        locator<SessionExpiredNotifier>(),
        () =>
            dio, // Closure: para cuando se use ya existe la instancia completa.
        () => Dio(
          BaseOptions(baseUrl: Environment.urlAuth),
        ), // Dio "limpio" sin interceptores, solo para /auth/refresh.
      ),
    );
```

**Antes** (sección storage):

```dart
  // Storage
  locator.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
```

**Después:**

```dart
  // Storage
  locator.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // Evento "sesión irrecuperable": emitido por RefreshTokenInterceptor,
  // consumido por AuthCubit.
  locator.registerLazySingleton<SessionExpiredNotifier>(
    () => SessionExpiredNotifier(),
  );
```

**Antes** (registro del AuthCubit):

```dart
  locator.registerLazySingleton(
    () => AuthCubit(
      locator<LoginUseCase>(),
      locator<LoginWithGoogleUseCase>(),
      locator<CheckAuthStatusUseCase>(),
      locator<LogoutUseCase>(),
    ),
  );
```

**Después:**

```dart
  locator.registerLazySingleton(
    () => AuthCubit(
      locator<LoginUseCase>(),
      locator<LoginWithGoogleUseCase>(),
      locator<CheckAuthStatusUseCase>(),
      locator<LogoutUseCase>(),
      locator<SessionExpiredNotifier>(),
    ),
  );
```

*(más el import nuevo al inicio del archivo: `import '../session/session_expired_notifier.dart';` y verificar que `Environment` ya esté importado — si no, `import '../constants/environment/environment.dart';`)*

## 5. auth_cubit_test.dart (archivo existente — actualización)

**Ruta:** `test/features/auth/presentation/cubit/auth_cubit_test.dart`

**Antes:**

```dart
class MockLogoutUseCase extends Mock implements LogoutUseCase {}
```

**Después:**

```dart
class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockSessionExpiredNotifier extends Mock
    implements SessionExpiredNotifier {}
```

**Antes** (en `setUp`):

```dart
    cubit = AuthCubit(
      mockLoginUseCase,
      mockLoginWithGoogleUseCase,
      mockCheckAuthStatusUseCase,
      mockLogoutUseCase,
    );
```

**Después:**

```dart
    mockSessionExpiredNotifier = MockSessionExpiredNotifier();
    when(
      () => mockSessionExpiredNotifier.stream,
    ).thenAnswer((_) => const Stream<void>.empty());

    cubit = AuthCubit(
      mockLoginUseCase,
      mockLoginWithGoogleUseCase,
      mockCheckAuthStatusUseCase,
      mockLogoutUseCase,
      mockSessionExpiredNotifier,
    );
```

(con su `late MockSessionExpiredNotifier mockSessionExpiredNotifier;` en las
declaraciones del grupo, y el import de `session_expired_notifier.dart` +
`auth_state.dart` ya está)

**Test nuevo** (al final del `main()`, usa un notifier REAL para disparar
el evento — no tiene dependencias):

```dart
  blocTest<AuthCubit, AuthState>(
    'emite AuthInitial cuando el refresh token muere estando autenticado',
    setUp: () {
      when(
        () => mockLoginUseCase(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Right(tUser));
    },
    build: () {
      final notifier = SessionExpiredNotifier();
      final c = AuthCubit(
        mockLoginUseCase,
        mockLoginWithGoogleUseCase,
        mockCheckAuthStatusUseCase,
        mockLogoutUseCase,
        notifier,
      );
      c.login(tEmail, tPassword);
      return c..addPostFrameNotifier(notifier);
    },
    ...
  );
```

*Nota de implementación:* como el notifier real no es un cubit, el test más
simple es un `test(...)` normal: crear cubit con notifier real, `await
cubit.login(...)`, `notifier.notifySessionExpired()`, `await
Future.delayed(Duration.zero)` y `expect(cubit.state, isA<AuthInitial>())`.
Ajustar a lo que compile limpio manteniendo la aserción.

## 6. refresh_token_interceptor_test.dart (archivo nuevo)

**Ruta:** `test/core/network/interceptors/refresh_token_interceptor_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/network/interceptors/refresh_token_interceptor.dart';
import 'package:quesivo/core/session/session_expired_notifier.dart';
import 'package:quesivo/features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';

class MockLocalAuthDataSource extends Mock implements ILocalAuthDataSource {}

class MockDio extends Mock implements Dio {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

RequestOptions _opts({String path = '/data'}) =>
    RequestOptions(path: path, headers: {}, extra: {});

DioException _err401({String path = '/data'}) => DioException(
      requestOptions: _opts(path: path),
      response: Response(
        requestOptions: _opts(path: path),
        statusCode: 401,
      ),
    );

void main() {
  late MockLocalAuthDataSource local;
  late MockDio mainDio;
  late MockDio refreshDio;
  late MockErrorInterceptorHandler handler;
  late SessionExpiredNotifier notifier;
  late RefreshTokenInterceptor interceptor;

  setUpAll(() {
    registerFallbackValue(_opts());
    registerFallbackValue(Response(requestOptions: _opts()));
  });

  setUp(() {
    local = MockLocalAuthDataSource();
    mainDio = MockDio();
    refreshDio = MockDio();
    handler = MockErrorInterceptorHandler();
    notifier = SessionExpiredNotifier();
    interceptor = RefreshTokenInterceptor(
      local,
      notifier,
      () => mainDio,
      () => refreshDio,
    );
  });

  tearDown(() => notifier.dispose());

  test('401 con refresh OK guarda tokens y reintenta el request', () async {
    when(() => local.getRefreshToken())
        .thenAnswer((_) async => 'old-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: _opts(path: '/auth/refresh'),
        statusCode: 200,
        data: {'accessToken': 'new-token', 'refreshToken': 'new-refresh'},
      ),
    );
    when(() => local.saveTokens(
          token: 'new-token',
          refreshToken: 'new-refresh',
        )).thenAnswer((_) async {});
    when(() => local.getToken()).thenAnswer((_) async => 'new-token');
    when(() => mainDio.fetch(any())).thenAnswer(
      (i) async => Response(
        requestOptions: i.positionalArguments.first as RequestOptions,
        statusCode: 200,
      ),
    );

    interceptor.onError(_err401(), handler);
    await untilCalled(() => handler.resolve(any()));

    verify(() => local.saveTokens(
        token: 'new-token', refreshToken: 'new-refresh')).called(1);
    verify(() => handler.resolve(any())).called(1);
    verifyNever(() => local.clearSession());
  });

  test('refresh falla (401 del endpoint) limpia sesión y notifica', () async {
    when(() => local.getRefreshToken())
        .thenAnswer((_) async => 'dead-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenThrow(_err401(path: '/auth/refresh'));
    when(() => local.clearSession()).thenAnswer((_) async {});

    var notified = false;
    notifier.stream.listen((_) => notified = true);

    interceptor.onError(_err401(), handler);
    await untilCalled(() => local.clearSession());
    await Future<void>.delayed(Duration.zero);

    verify(() => local.clearSession()).called(1);
    expect(notified, isTrue);
  });

  test('sin refresh token limpia sesión y notifica sin llamar a la API',
      () async {
    when(() => local.getRefreshToken()).thenAnswer((_) async => null);
    when(() => local.clearSession()).thenAnswer((_) async {});

    interceptor.onError(_err401(), handler);
    await untilCalled(() => local.clearSession());

    verify(() => local.clearSession()).called(1);
    verifyNever(() => refreshDio.post(any(), data: any(named: 'data')));
  });

  test('401 en /auth/refresh no re-entra al flujo (anti-loop)', () async {
    interceptor.onError(_err401(path: '/auth/refresh'), handler);
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => local.getRefreshToken());
    verifyNever(() => local.clearSession());
  });

  test('dos 401 concurrentes disparan un solo refresh', () async {
    when(() => local.getRefreshToken())
        .thenAnswer((_) async => 'old-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return Response(
        requestOptions: _opts(path: '/auth/refresh'),
        statusCode: 200,
        data: {'accessToken': 'new-token', 'refreshToken': 'new-refresh'},
      );
    });
    when(() => local.saveTokens(
          token: any(named: 'token'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(() => local.getToken()).thenAnswer((_) async => 'new-token');
    when(() => mainDio.fetch(any())).thenAnswer(
      (i) async => Response(
        requestOptions: i.positionalArguments.first as RequestOptions,
        statusCode: 200,
      ),
    );

    interceptor.onError(_err401(), handler);
    interceptor.onError(_err401(), MockErrorInterceptorHandler());
    await untilCalled(() => mainDio.fetch(any()));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verify(() => refreshDio.post('/auth/refresh',
        data: any(named: 'data'))).called(1);
  });
}
```

*Nota de implementación:* `onError` es `void` (firma del Interceptor de Dio)
así que los tests esperan efectos con `untilCalled` + micro-delays en vez de
`await` directo. Si algún stub de `Response` pide tipo genérico distinto,
ajustar manteniendo las aserciones.

---

## Orden de aplicación

1. `lib/core/session/session_expired_notifier.dart` (nuevo, sin dependencias)
2. `refresh_token_interceptor.dart` (reescrito)
3. `auth_cubit.dart` (ctor + suscripción + close)
4. `setup_di.dart` (registro notifier + wiring)
5. `auth_cubit_test.dart` (ctor + test nuevo)
6. `refresh_token_interceptor_test.dart` (nuevo)
7. `flutter analyze` + `flutter test` limpios.

## Verificación manual posterior (en el cel con el release de Shorebird)

Con la app instalada vía `shorebird preview` contra Render: hacer login,
esperar el access token (24h en stg — alternativa práctica: revocar la
sesión desde Supabase con `DELETE FROM user_sessions WHERE user_id=...`),
disparar cualquier llamada autenticada y confirmar que la app vuelve a
welcome sola en vez de quedarse colgada.
