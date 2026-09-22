import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/logging/interfaces/i_logger_service.dart';
import 'package:quesivo/core/network/interfaces/i_network_info.dart';
import 'package:quesivo/features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';
import 'package:quesivo/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart';
import 'package:quesivo/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:quesivo/features/auth/data/models/user_model.dart';
import 'package:quesivo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';

class MockRemoteAuthDataSource extends Mock implements IRemoteAuthDataSource {}

class MockLocalAuthDataSource extends Mock implements ILocalAuthDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

class MockLoggerService extends Mock implements ILoggerService {}

void main() {
  late AuthRepositoryImpl repository;
  late MockRemoteAuthDataSource mockRemoteDataSource;
  late MockLocalAuthDataSource mockLocalDataSource;
  late MockNetworkInfo mockNetworkInfo;
  late MockLoggerService mockLogger;

  const tEmail = 'test@test.com';
  const tPassword = 'password123';
  const tUserModel = UserModel(
    id: '1',
    email: tEmail,
    name: 'John Doe',
    token: 'token',
    refreshToken: 'refresh',
  );

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(tUserModel);
  });

  setUp(() {
    mockRemoteDataSource = MockRemoteAuthDataSource();
    mockLocalDataSource = MockLocalAuthDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockLogger = MockLoggerService();

    // El logger nunca debe romper un test: cualquier llamada retorna null.
    when(
      () => mockLogger.warning(
        any(),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.error(
        any(),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    repository = AuthRepositoryImpl(
      mockRemoteDataSource,
      mockLocalDataSource,
      mockNetworkInfo,
      mockLogger,
    );
  });

  void mockConnected(bool isConnected) {
    when(
      () => mockNetworkInfo.isConnected,
    ).thenAnswer((_) async => isConnected);
  }

  group('loginWithEmailPassword', () {
    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.loginWithEmailPassword(
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Left(NetworkFailure()));
      verifyNever(
        () => mockRemoteDataSource.loginWithEmailPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    test('retorna Right(user) y persiste la sesión en éxito', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockLocalDataSource.saveUserSession(tUserModel),
      ).thenAnswer((_) async {});

      final result = await repository.loginWithEmailPassword(
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Right(tUserModel));
      verify(() => mockLocalDataSource.saveUserSession(tUserModel)).called(1);
    });

    test(
      'retorna InvalidCredentialsFailure ante UnauthorizedException',
      () async {
        mockConnected(true);
        when(
          () => mockRemoteDataSource.loginWithEmailPassword(
            email: tEmail,
            password: tPassword,
          ),
        ).thenThrow(UnauthorizedException());

        final result = await repository.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        );

        expect(result, const Left(InvalidCredentialsFailure()));
      },
    );

    test('retorna AccountSuspendedFailure ante RestApiException 403', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenThrow(RestApiException(statusCode: 403, message: 'Suspended'));

      final result = await repository.loginWithEmailPassword(
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Left(AccountSuspendedFailure()));
    });

    test(
      'retorna RoleNotAllowedFailure ante 403 con errorCode ROLE_NOT_ALLOWED (backend 062)',
      () async {
        mockConnected(true);
        when(
          () => mockRemoteDataSource.loginWithEmailPassword(
            email: tEmail,
            password: tPassword,
          ),
        ).thenThrow(
          RestApiException(
            statusCode: 403,
            message: 'Restricted',
            errorCode: 'ROLE_NOT_ALLOWED',
          ),
        );

        final result = await repository.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        );

        expect(result, const Left(RoleNotAllowedFailure()));
      },
    );

    test('retorna TooManyAttemptsFailure ante RestApiException 429', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenThrow(RestApiException(statusCode: 429, message: 'Throttled'));

      final result = await repository.loginWithEmailPassword(
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Left(TooManyAttemptsFailure()));
    });

    test('retorna ServerFailure con el mensaje del RestApiException', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await repository.loginWithEmailPassword(
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Left(ServerFailure('Boom')));
    });

    test('retorna ServerFailure genérico ante un error inesperado', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenThrow(Exception('cualquier cosa'));

      final result = await repository.loginWithEmailPassword(
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Left(ServerFailure('Error inesperado de red')));
    });
  });

  group('loginWithGoogle', () {
    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.loginWithGoogle();

      expect(result, const Left(NetworkFailure()));
      verifyNever(() => mockRemoteDataSource.loginWithGoogle());
    });

    test('retorna Right(user) y persiste la sesión en éxito', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithGoogle(),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockLocalDataSource.saveUserSession(tUserModel),
      ).thenAnswer((_) async {});

      final result = await repository.loginWithGoogle();

      expect(result, const Right(tUserModel));
    });

    test('retorna ServerFailure ante cualquier excepción', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithGoogle(),
      ).thenThrow(UnimplementedError('no disponible'));

      final result = await repository.loginWithGoogle();

      expect(result.isLeft(), true);
    });
  });

  group('checkAuthStatus', () {
    const tFreshModel = UserModel(
      id: '1',
      email: tEmail,
      name: 'John Doe',
      organizationId: 'org-1',
      organizationName: 'Quesera Test',
      roles: ['ADMIN'],
      status: 'active',
    );

    setUp(() {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => mockRemoteDataSource.getMe(),
      ).thenAnswer((_) async => tFreshModel);
      when(
        () => mockLocalDataSource.saveUserSession(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalDataSource.getToken(),
      ).thenAnswer((_) async => 'token');
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'refresh');
    });

    test('retorna perfil fresco y refresca el cache local', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);

      final result = await repository.checkAuthStatus();

      result.fold((_) => fail('debía ser Right'), (user) {
        expect(user.name, 'John Doe');
        expect(user.organizationName, 'Quesera Test');
        expect(user.status, 'active');
        expect(user.token, tUserModel.token); // tokens se conservan
      });
      verify(() => mockLocalDataSource.saveUserSession(any())).called(1);
    });

    test('retorna sesión local sin conectividad (sin llamar remoto)', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);

      final result = await repository.checkAuthStatus();

      expect(result, const Right(tUserModel));
      verifyNever(() => mockRemoteDataSource.getMe());
    });

    test(
      'retorna sesión local si /auth/me da error transitorio (5xx)',
      () async {
        when(
          () => mockLocalDataSource.getUserSession(),
        ).thenAnswer((_) async => tUserModel);
        when(
          () => mockRemoteDataSource.getMe(),
        ).thenThrow(RestApiException(statusCode: 500, message: 'server error'));

        final result = await repository.checkAuthStatus();

        expect(result, const Right(tUserModel));
      },
    );

    test(
      'status suspended limpia sesión y devuelve AccountSuspendedFailure',
      () async {
        when(
          () => mockLocalDataSource.getUserSession(),
        ).thenAnswer((_) async => tUserModel);
        when(() => mockRemoteDataSource.getMe()).thenAnswer(
          (_) async => const UserModel(
            id: '1',
            email: tEmail,
            name: 'John Doe',
            status: 'suspended',
          ),
        );
        when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

        final result = await repository.checkAuthStatus();

        expect(result, const Left(AccountSuspendedFailure()));
        verify(() => mockLocalDataSource.clearSession()).called(1);
        verifyNever(() => mockLocalDataSource.saveUserSession(any()));
      },
    );

    test('retorna NoSessionFailure si no hay sesión guardada', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => null);

      final result = await repository.checkAuthStatus();

      expect(result, const Left(NoSessionFailure()));
      verifyNever(() => mockRemoteDataSource.getMe());
    });

    test('retorna ServerFailure si falla la lectura local', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenThrow(Exception('storage corrupto'));

      final result = await repository.checkAuthStatus();

      expect(result, const Left(ServerFailure('Error leyendo sesión local')));
    });

    test('usa los tokens EN VIVO post-getMe (rotación transparente)', () async {
      // Simula: access token vencido → el interceptor refrescó y guardó
      // T2/RT2 durante getMe. getToken/getRefreshToken devuelven los nuevos.
      when(() => mockLocalDataSource.getUserSession()).thenAnswer(
        (_) async => tUserModel,
      ); // snapshot con 'token'/'refresh' viejos
      when(() => mockRemoteDataSource.getMe()).thenAnswer((_) async {
        when(
          () => mockLocalDataSource.getToken(),
        ).thenAnswer((_) async => 'token-ROTATED');
        when(
          () => mockLocalDataSource.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-ROTATED');
        return tFreshModel;
      });

      final result = await repository.checkAuthStatus();

      result.fold((_) => fail('debía ser Right'), (user) {
        expect(user.token, 'token-ROTATED');
        expect(user.refreshToken, 'refresh-ROTATED');
      });
      // saveUserSession persiste perfil + tokens: deben ser los rotados,
      // nunca el snapshot pre-refresh.
      final saved =
          verify(
                () => mockLocalDataSource.saveUserSession(captureAny()),
              ).captured.single
              as UserModel;
      expect(saved.refreshToken, 'refresh-ROTATED');
    });

    test('401 de /auth/me con sesión aún en storage = transitorio', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockRemoteDataSource.getMe(),
      ).thenThrow(UnauthorizedException());

      final result = await repository.checkAuthStatus();

      expect(result, const Right(tUserModel));
    });

    test('401 de /auth/me con storage ya limpio = sesión muerta', () async {
      var cleared = false;
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => cleared ? null : tUserModel);
      when(() => mockRemoteDataSource.getMe()).thenAnswer((_) async {
        cleared = true; // el interceptor limpió durante el 401
        throw UnauthorizedException();
      });

      final result = await repository.checkAuthStatus();

      expect(result, const Left(NoSessionFailure()));
    });

    test(
      'suspended devuelve AccountSuspendedFailure aunque clearSession falle',
      () async {
        when(
          () => mockLocalDataSource.getUserSession(),
        ).thenAnswer((_) async => tUserModel);
        when(() => mockRemoteDataSource.getMe()).thenAnswer(
          (_) async => const UserModel(
            id: '1',
            email: tEmail,
            name: 'John Doe',
            status: 'suspended',
          ),
        );
        when(
          () => mockLocalDataSource.clearSession(),
        ).thenThrow(Exception('storage roto'));

        final result = await repository.checkAuthStatus();

        expect(result, const Left(AccountSuspendedFailure()));
      },
    );
  });

  group('logout', () {
    test('revoca la sesión remota y limpia la local', () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'refresh');
      mockConnected(true);
      when(
        () => mockRemoteDataSource.logout('refresh'),
      ).thenAnswer((_) async {});
      when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right(null));
      // El orden es el contrato: leer el token, revocarlo en el servidor
      // y recién después borrarlo localmente — si clearSession fuera
      // primero, la revocación remota se omitiría silenciosamente.
      // (verifyInOrder verifica cada llamada y su orden — no mezclar con
      // verify(): una llamada verificada ya no entra al matching.)
      verifyInOrder([
        () => mockLocalDataSource.getRefreshToken(),
        () => mockRemoteDataSource.logout('refresh'),
        () => mockLocalDataSource.clearSession(),
      ]);
    });

    test(
      'si falla el logout remoto igual limpia local y retorna Right',
      () async {
        when(
          () => mockLocalDataSource.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh');
        mockConnected(true);
        when(
          () => mockRemoteDataSource.logout('refresh'),
        ).thenThrow(Exception('500 del servidor'));
        when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

        final result = await repository.logout();

        expect(result, const Right(null));
        verify(() => mockLocalDataSource.clearSession()).called(1);
      },
    );

    test('sin refresh token local omite la llamada remota', () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => null);
      when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right(null));
      verifyNever(() => mockRemoteDataSource.logout(any()));
      verify(() => mockLocalDataSource.clearSession()).called(1);
    });

    test('sin conexión omite la llamada remota pero cierra sesión', () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'refresh');
      mockConnected(false);
      when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, const Right(null));
      verifyNever(() => mockRemoteDataSource.logout(any()));
      verify(() => mockLocalDataSource.clearSession()).called(1);
    });

    test('retorna CacheFailure si falla el borrado de sesión', () async {
      when(
        () => mockLocalDataSource.getRefreshToken(),
      ).thenAnswer((_) async => null);
      when(
        () => mockLocalDataSource.clearSession(),
      ).thenThrow(Exception('storage bloqueado'));

      final result = await repository.logout();

      expect(result, const Left(CacheFailure('No se pudo cerrar la sesión.')));
    });

    test(
      'si getRefreshToken lanza igual limpia local y retorna Right',
      () async {
        when(
          () => mockLocalDataSource.getRefreshToken(),
        ).thenThrow(Exception('storage ilegible'));
        when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

        final result = await repository.logout();

        expect(result, const Right(null));
        verifyNever(() => mockRemoteDataSource.logout(any()));
        verify(() => mockLocalDataSource.clearSession()).called(1);
      },
    );
  });

  group('forgotPassword', () {
    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.forgotPassword(tEmail);

      expect(result, const Left(NetworkFailure()));
      verifyNever(() => mockRemoteDataSource.forgotPassword(any()));
    });

    test('retorna Right(null) en éxito', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.forgotPassword(tEmail),
      ).thenAnswer((_) async {});

      final result = await repository.forgotPassword(tEmail);

      expect(result, const Right(null));
    });

    test('retorna ServerFailure ante una excepción', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.forgotPassword(tEmail),
      ).thenThrow(Exception('falló el envío'));

      final result = await repository.forgotPassword(tEmail);

      expect(
        result,
        const Left(
          ServerFailure('No se pudo enviar el correo de recuperación'),
        ),
      );
    });
  });

  group('register', () {
    const tOrgName = 'Quesera Los Alpes';
    const tName = 'María Quesera';

    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.register(
        organizationName: tOrgName,
        name: tName,
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Left(NetworkFailure()));
      verifyNever(
        () => mockRemoteDataSource.register(
          organizationName: any(named: 'organizationName'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    test('retorna Right(user) y persiste la sesión en éxito', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.register(
          organizationName: tOrgName,
          name: tName,
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockLocalDataSource.saveUserSession(tUserModel),
      ).thenAnswer((_) async {});

      final result = await repository.register(
        organizationName: tOrgName,
        name: tName,
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Right(tUserModel));
      verify(() => mockLocalDataSource.saveUserSession(tUserModel)).called(1);
    });

    test(
      'retorna EmailAlreadyInUseFailure ante RestApiException 409',
      () async {
        mockConnected(true);
        when(
          () => mockRemoteDataSource.register(
            organizationName: tOrgName,
            name: tName,
            email: tEmail,
            password: tPassword,
          ),
        ).thenThrow(RestApiException(statusCode: 409, message: 'Conflict'));

        final result = await repository.register(
          organizationName: tOrgName,
          name: tName,
          email: tEmail,
          password: tPassword,
        );

        expect(result, const Left(EmailAlreadyInUseFailure()));
        verifyNever(() => mockLocalDataSource.saveUserSession(any()));
      },
    );
  });
}
