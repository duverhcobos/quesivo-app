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

// _opts: request autenticado por defecto (el flujo de refresh exige
// header Authorization); los tests de "sin sesión" pasan withAuth: false.
RequestOptions _opts({String path = '/data', bool withAuth = true}) =>
    RequestOptions(
      path: path,
      headers: withAuth
          ? {'Authorization': 'Bearer token'}
          : <String, String>{},
      extra: {},
    );

DioException _err401({String path = '/data'}) => DioException(
  requestOptions: _opts(path: path),
  response: Response(requestOptions: _opts(path: path), statusCode: 401),
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
    // Fallback para `handler.next(any())`: DioException es un tipo
    // custom no-nullable y mocktail lo exige registrado.
    registerFallbackValue(_err401());
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
    when(() => local.getRefreshToken()).thenAnswer((_) async => 'old-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: _opts(path: '/auth/refresh'),
        statusCode: 200,
        data: {'accessToken': 'new-token', 'refreshToken': 'new-refresh'},
      ),
    );
    when(
      () => local.saveTokens(token: 'new-token', refreshToken: 'new-refresh'),
    ).thenAnswer((_) async {});
    when(() => local.getToken()).thenAnswer((_) async => 'new-token');
    when(() => mainDio.fetch(any())).thenAnswer(
      (i) async => Response(
        requestOptions: i.positionalArguments.first as RequestOptions,
        statusCode: 200,
      ),
    );

    interceptor.onError(_err401(), handler);
    await untilCalled(() => handler.resolve(any()));

    verify(
      () => local.saveTokens(token: 'new-token', refreshToken: 'new-refresh'),
    ).called(1);
    verify(() => handler.resolve(any())).called(1);
    verifyNever(() => local.clearSession());
  });

  test('refresh falla (401 del endpoint) limpia sesión y notifica', () async {
    when(() => local.getRefreshToken()).thenAnswer((_) async => 'dead-refresh');
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

  test(
    'sin refresh token limpia sesión y notifica sin llamar a la API',
    () async {
      when(() => local.getRefreshToken()).thenAnswer((_) async => null);
      when(() => local.clearSession()).thenAnswer((_) async {});

      interceptor.onError(_err401(), handler);
      await untilCalled(() => local.clearSession());

      verify(() => local.clearSession()).called(1);
      verifyNever(() => refreshDio.post(any(), data: any(named: 'data')));
    },
  );

  test('401 en /auth/refresh no re-entra al flujo (anti-loop)', () async {
    interceptor.onError(_err401(path: '/auth/refresh'), handler);
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => local.getRefreshToken());
    verifyNever(() => local.clearSession());
  });

  test('dos 401 concurrentes disparan un solo refresh', () async {
    when(() => local.getRefreshToken()).thenAnswer((_) async => 'old-refresh');
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
    when(
      () => local.saveTokens(
        token: any(named: 'token'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
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

    verify(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).called(1);
  });

  test('error transitorio del refresh (5xx) conserva la sesión', () async {
    when(() => local.getRefreshToken()).thenAnswer((_) async => 'old-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenThrow(
      DioException(
        requestOptions: _opts(path: '/auth/refresh'),
        response: Response(
          requestOptions: _opts(path: '/auth/refresh'),
          statusCode: 502,
        ),
      ),
    );

    interceptor.onError(_err401(), handler);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verifyNever(() => local.clearSession());
    verifyNever(
      () => local.saveTokens(
        token: any(named: 'token'),
        refreshToken: any(named: 'refreshToken'),
      ),
    );
  });

  test('refresh 200 sin campos esperados conserva la sesión', () async {
    when(() => local.getRefreshToken()).thenAnswer((_) async => 'old-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: _opts(path: '/auth/refresh'),
        statusCode: 200,
        data: <String, dynamic>{},
      ),
    );

    interceptor.onError(_err401(), handler);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verifyNever(() => local.clearSession());
  });

  test('401 sin header Authorization no entra al flujo de refresh', () async {
    final err = DioException(
      requestOptions: _opts(withAuth: false), // sin Authorization en headers
      response: Response(
        requestOptions: _opts(withAuth: false),
        statusCode: 401,
      ),
    );

    interceptor.onError(err, handler);
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => local.getRefreshToken());
    verifyNever(() => local.clearSession());
  });

  test('clearSession que lanza igual notifica y propaga el error', () async {
    when(() => local.getRefreshToken()).thenAnswer((_) async => 'dead-refresh');
    when(
      () => refreshDio.post('/auth/refresh', data: any(named: 'data')),
    ).thenThrow(_err401(path: '/auth/refresh'));
    when(() => local.clearSession()).thenThrow(Exception('storage roto'));

    var notified = false;
    notifier.stream.listen((_) => notified = true);

    interceptor.onError(_err401(), handler);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(notified, isTrue);
    verify(() => handler.next(any())).called(1); // el error original propaga
  });
}
