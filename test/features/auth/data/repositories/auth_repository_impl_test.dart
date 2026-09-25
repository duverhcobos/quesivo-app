import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/logging/interfaces/i_logger_service.dart';
import 'package:quesivo/core/network/interfaces/i_network_info.dart';
import 'package:quesivo/features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';
import 'package:quesivo/features/auth/data/datasources/interfaces/i_remote_auth_datasource.dart';
import 'package:quesivo/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:quesivo/features/auth/data/models/organization_session_model.dart';
import 'package:quesivo/features/auth/data/models/user_model.dart';
import 'package:quesivo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:quesivo/features/auth/domain/entities/org_invite.dart';
import 'package:quesivo/features/auth/domain/entities/organization_summary.dart';
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

    test('retorna EmailNotVerifiedFailure ante 403 con errorCode '
        'EMAIL_NOT_VERIFIED (backend 069 — la pantalla navega a '
        '/check-email con este flag)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenThrow(
        RestApiException(
          statusCode: 403,
          message: 'Email not verified',
          errorCode: 'EMAIL_NOT_VERIFIED',
        ),
      );

      final result = await repository.loginWithEmailPassword(
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Left(EmailNotVerifiedFailure()));
    });

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

    test('RestApiException no mapeada → ServerFailure genérico (el '
        'mensaje crudo del backend no llega a la UI)', () async {
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

      expect(result, const Left(ServerFailure()));
    });

    test('ServerException (request sin respuesta, server caído) → '
        'NetworkFailure', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenThrow(ServerException());

      final result = await repository.loginWithEmailPassword(
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Left(NetworkFailure()));
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

    test('conserva pendingInvites del /me en el merge y al persistir '
        '(regresión §69 — el merge manual los tiraba y las cards de '
        'invitación nunca aparecían)', () async {
      const tFreshConInvite = UserModel(
        id: '1',
        email: tEmail,
        name: 'John Doe',
        status: 'active',
        pendingInvites: [
          OrgInvite(
            id: 'mem-1',
            organizationId: 'org-9',
            organizationName: 'Quesera Norte',
            role: 'ADMIN',
          ),
        ],
      );
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockRemoteDataSource.getMe(),
      ).thenAnswer((_) async => tFreshConInvite);

      final result = await repository.checkAuthStatus();

      result.fold((_) => fail('debía ser Right'), (user) {
        expect(user.pendingInvites, hasLength(1));
        expect(user.pendingInvites.single.organizationId, 'org-9');
      });
      final saved =
          verify(
                () => mockLocalDataSource.saveUserSession(captureAny()),
              ).captured.single
              as UserModel;
      expect(saved.pendingInvites, hasLength(1));
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

    test('retorna TooManyAttemptsFailure ante RestApiException 429', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.forgotPassword(tEmail),
      ).thenThrow(RestApiException(statusCode: 429, message: 'Too Many'));

      final result = await repository.forgotPassword(tEmail);

      expect(result, const Left(TooManyAttemptsFailure()));
    });

    test('RestApiException no mapeada → ServerFailure genérico', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.forgotPassword(tEmail),
      ).thenThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await repository.forgotPassword(tEmail);

      expect(result, const Left(ServerFailure()));
    });

    test('retorna ServerFailure ante una excepción', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.forgotPassword(tEmail),
      ).thenThrow(Exception('falló el envío'));

      final result = await repository.forgotPassword(tEmail);

      expect(result, const Left(ServerFailure('Error inesperado de red')));
    });
  });

  group('resetPassword', () {
    const tToken = 'reset-token-abc';

    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.resetPassword(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(NetworkFailure()));
      verifyNever(
        () => mockRemoteDataSource.resetPassword(
          token: any(named: 'token'),
          password: any(named: 'password'),
        ),
      );
    });

    test('retorna Right(null) en éxito', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.resetPassword(
          token: tToken,
          password: tPassword,
        ),
      ).thenAnswer((_) async {});

      final result = await repository.resetPassword(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Right(null));
    });

    test('400 + INVALID_OR_EXPIRED_TOKEN → InvalidOrExpiredTokenFailure '
        '(link usado/vencido → pedir uno nuevo)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.resetPassword(
          token: tToken,
          password: tPassword,
        ),
      ).thenThrow(
        RestApiException(
          statusCode: 400,
          message: 'Invalid token',
          errorCode: 'INVALID_OR_EXPIRED_TOKEN',
        ),
      );

      final result = await repository.resetPassword(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(InvalidOrExpiredTokenFailure()));
    });

    test('400 + INVALID_PASSWORD → WeakPasswordFailure', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.resetPassword(
          token: tToken,
          password: tPassword,
        ),
      ).thenThrow(
        RestApiException(
          statusCode: 400,
          message: 'Weak password',
          errorCode: 'INVALID_PASSWORD',
        ),
      );

      final result = await repository.resetPassword(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(WeakPasswordFailure()));
    });

    test('RestApiException no mapeada → ServerFailure genérico', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.resetPassword(
          token: tToken,
          password: tPassword,
        ),
      ).thenThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await repository.resetPassword(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(ServerFailure()));
    });

    test('retorna ServerFailure ante una excepción inesperada', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.resetPassword(
          token: tToken,
          password: tPassword,
        ),
      ).thenThrow(Exception('cualquier cosa'));

      final result = await repository.resetPassword(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(ServerFailure('Error inesperado de red')));
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

    test('retorna Right(null) y NO guarda sesión en éxito (backend 069: '
        'la cuenta queda pending_verification)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.register(
          organizationName: tOrgName,
          name: tName,
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async {});

      final result = await repository.register(
        organizationName: tOrgName,
        name: tName,
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Right(null));
      verifyNever(() => mockLocalDataSource.saveUserSession(any()));
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

  group('verifyEmail', () {
    const tToken = 'verify-token-abc';

    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.verifyEmail(token: tToken);

      expect(result, const Left(NetworkFailure()));
      verifyNever(() => mockRemoteDataSource.verifyEmail(any()));
    });

    test('retorna Right(user) y persiste la sesión en éxito '
        '(auto-login — backend 069)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.verifyEmail(tToken),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockLocalDataSource.saveUserSession(tUserModel),
      ).thenAnswer((_) async {});

      final result = await repository.verifyEmail(token: tToken);

      expect(result, const Right(tUserModel));
      verify(() => mockLocalDataSource.saveUserSession(tUserModel)).called(1);
    });

    test('400 + INVALID_OR_EXPIRED_TOKEN → InvalidOrExpiredTokenFailure '
        '(link usado/vencido → pedir uno nuevo)', () async {
      mockConnected(true);
      when(() => mockRemoteDataSource.verifyEmail(tToken)).thenThrow(
        RestApiException(
          statusCode: 400,
          message: 'Invalid token',
          errorCode: 'INVALID_OR_EXPIRED_TOKEN',
        ),
      );

      final result = await repository.verifyEmail(token: tToken);

      expect(result, const Left(InvalidOrExpiredTokenFailure()));
      verifyNever(() => mockLocalDataSource.saveUserSession(any()));
    });

    test('RestApiException no mapeada → ServerFailure genérico', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.verifyEmail(tToken),
      ).thenThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await repository.verifyEmail(token: tToken);

      expect(result, const Left(ServerFailure()));
    });

    test('retorna ServerFailure ante una excepción inesperada', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.verifyEmail(tToken),
      ).thenThrow(Exception('cualquier cosa'));

      final result = await repository.verifyEmail(token: tToken);

      expect(result, const Left(ServerFailure('Error inesperado de red')));
    });
  });

  group('acceptInvite (propuesta 68 — doc 017, Email-C)', () {
    const tToken = 'invite-token-abc';
    const tPassword = 'NuevaPass123';

    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.acceptInvite(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(NetworkFailure()));
      verifyNever(
        () => mockRemoteDataSource.acceptInvite(
          token: any(named: 'token'),
          password: any(named: 'password'),
        ),
      );
    });

    test('retorna Right(user) y persiste la sesión en éxito '
        '(auto-login — backend 070, mismo patrón que verifyEmail)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.acceptInvite(
          token: tToken,
          password: tPassword,
        ),
      ).thenAnswer((_) async => tUserModel);
      when(
        () => mockLocalDataSource.saveUserSession(tUserModel),
      ).thenAnswer((_) async {});

      final result = await repository.acceptInvite(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Right(tUserModel));
      verify(() => mockLocalDataSource.saveUserSession(tUserModel)).called(1);
    });

    test('400 + INVALID_OR_EXPIRED_TOKEN → InvalidOrExpiredTokenFailure '
        '(link usado/vencido → vista de link inválido)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.acceptInvite(
          token: tToken,
          password: tPassword,
        ),
      ).thenThrow(
        RestApiException(
          statusCode: 400,
          message: 'Invalid token',
          errorCode: 'INVALID_OR_EXPIRED_TOKEN',
        ),
      );

      final result = await repository.acceptInvite(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(InvalidOrExpiredTokenFailure()));
      verifyNever(() => mockLocalDataSource.saveUserSession(any()));
    });

    test('400 + INVALID_PASSWORD → WeakPasswordFailure '
        '(segunda línea del VO — la pantalla ya validó)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.acceptInvite(
          token: tToken,
          password: tPassword,
        ),
      ).thenThrow(
        RestApiException(
          statusCode: 400,
          message: 'Weak password',
          errorCode: 'INVALID_PASSWORD',
        ),
      );

      final result = await repository.acceptInvite(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(WeakPasswordFailure()));
      verifyNever(() => mockLocalDataSource.saveUserSession(any()));
    });

    test('RestApiException no mapeada → ServerFailure genérico', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.acceptInvite(
          token: tToken,
          password: tPassword,
        ),
      ).thenThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await repository.acceptInvite(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(ServerFailure()));
    });

    test('retorna ServerFailure ante una excepción inesperada', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.acceptInvite(
          token: tToken,
          password: tPassword,
        ),
      ).thenThrow(Exception('cualquier cosa'));

      final result = await repository.acceptInvite(
        token: tToken,
        password: tPassword,
      );

      expect(result, const Left(ServerFailure('Error inesperado de red')));
    });
  });

  group('resendVerification', () {
    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.resendVerification(tEmail);

      expect(result, const Left(NetworkFailure()));
      verifyNever(() => mockRemoteDataSource.resendVerification(any()));
    });

    test(
      'retorna Right(null) en éxito (siempre 200 — anti-enumeración)',
      () async {
        mockConnected(true);
        when(
          () => mockRemoteDataSource.resendVerification(tEmail),
        ).thenAnswer((_) async {});

        final result = await repository.resendVerification(tEmail);

        expect(result, const Right(null));
      },
    );

    test('retorna TooManyAttemptsFailure ante RestApiException 429', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.resendVerification(tEmail),
      ).thenThrow(RestApiException(statusCode: 429, message: 'Too Many'));

      final result = await repository.resendVerification(tEmail);

      expect(result, const Left(TooManyAttemptsFailure()));
    });

    test('RestApiException no mapeada → ServerFailure genérico', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.resendVerification(tEmail),
      ).thenThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await repository.resendVerification(tEmail);

      expect(result, const Left(ServerFailure()));
    });

    test('retorna ServerFailure ante una excepción inesperada', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.resendVerification(tEmail),
      ).thenThrow(Exception('falló el reenvío'));

      final result = await repository.resendVerification(tEmail);

      expect(result, const Left(ServerFailure('Error inesperado de red')));
    });
  });

  group('selectOrganization (§55 — doc 006)', () {
    const tOrgId = 'org-1';
    const tSession = OrganizationSessionModel(
      accessToken: 'access-org',
      refreshToken: 'refresh-org',
      organizationId: tOrgId,
      organizationName: 'Quesera Norte',
    );

    test('retorna NetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await repository.selectOrganization(tOrgId);

      expect(result, const Left(NetworkFailure()));
      verifyNever(() => mockRemoteDataSource.selectOrganization(any()));
    });

    test('en éxito persiste el par de tokens org-scoped vía saveTokens '
        'y devuelve la sesión emitida (§63) — sin perfil cacheado no '
        'guarda perfil', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.selectOrganization(tOrgId),
      ).thenAnswer((_) async => tSession);
      when(
        () => mockLocalDataSource.saveTokens(
          token: any(named: 'token'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => null);

      final result = await repository.selectOrganization(tOrgId);

      expect(result, const Right(tSession));
      verify(
        () => mockLocalDataSource.saveTokens(
          token: 'access-org',
          refreshToken: 'refresh-org',
        ),
      ).called(1);
      verifyNever(() => mockLocalDataSource.saveUserSession(any()));
    });

    test('en éxito con perfil cacheado lo re-guarda con la org de la '
        'sesión nueva (§63 auditoría: un restart offline no debe '
        'degradar al orgId viejo)', () async {
      mockConnected(true);
      const tCached = UserModel(
        id: '1',
        email: tEmail,
        name: 'John Doe',
        token: 'token-personal',
        refreshToken: 'refresh-personal',
        roles: ['PERSONAL'],
        organizations: [
          OrganizationSummary(
            id: 'org-1',
            name: 'Quesera Norte',
            role: 'ADMIN',
          ),
          OrganizationSummary(
            id: 'org-2',
            name: 'Quesera Sur',
            role: 'OPERATOR',
          ),
        ],
        pendingInvites: [
          OrgInvite(
            id: 'mem-1',
            organizationId: 'org-9',
            organizationName: 'Quesera Este',
            role: 'ADMIN',
          ),
        ],
      );
      when(
        () => mockRemoteDataSource.selectOrganization(tOrgId),
      ).thenAnswer((_) async => tSession);
      when(
        () => mockLocalDataSource.saveTokens(
          token: any(named: 'token'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tCached);
      when(
        () => mockLocalDataSource.saveUserSession(any()),
      ).thenAnswer((_) async {});

      final result = await repository.selectOrganization(tOrgId);

      expect(result, const Right(tSession));
      final saved =
          verify(
                () => mockLocalDataSource.saveUserSession(captureAny()),
              ).captured.single
              as UserModel;
      expect(saved.token, 'access-org');
      expect(saved.refreshToken, 'refresh-org');
      expect(saved.organizationId, tOrgId);
      expect(saved.organizationName, 'Quesera Norte');
      expect(saved.roles, ['ADMIN']);
      expect(saved.organizations, tCached.organizations);
      // §69 — el merge manual no debe perder las invitaciones pendientes.
      expect(saved.pendingInvites, tCached.pendingInvites);
    });

    test('retorna InvalidCredentialsFailure ante UnauthorizedException (401: '
        'membresía inexistente/suspendida)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.selectOrganization(tOrgId),
      ).thenThrow(UnauthorizedException());

      final result = await repository.selectOrganization(tOrgId);

      expect(result, const Left(InvalidCredentialsFailure()));
      verifyNever(
        () => mockLocalDataSource.saveTokens(
          token: any(named: 'token'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });

    test('RestApiException no mapeada → ServerFailure genérico (el '
        'mensaje crudo del backend no llega a la UI)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.selectOrganization(tOrgId),
      ).thenThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await repository.selectOrganization(tOrgId);

      expect(result, const Left(ServerFailure()));
    });

    test('ServerException (request sin respuesta, server caído) → '
        'NetworkFailure', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.selectOrganization(tOrgId),
      ).thenThrow(ServerException());

      final result = await repository.selectOrganization(tOrgId);

      expect(result, const Left(NetworkFailure()));
    });

    test('retorna ServerFailure genérico ante un error inesperado', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.selectOrganization(tOrgId),
      ).thenThrow(Exception('cualquier cosa'));

      final result = await repository.selectOrganization(tOrgId);

      expect(result, const Left(ServerFailure('Error inesperado de red')));
    });
  });

  group('acceptOrgInvite / declineOrgInvite (§69 — docs 019/020)', () {
    for (final (name, call) in [
      ('acceptOrgInvite', () => repository.acceptOrgInvite('org-9')),
      ('declineOrgInvite', () => repository.declineOrgInvite('org-9')),
    ]) {
      group(name, () {
        test('retorna NetworkFailure si no hay conexión', () async {
          mockConnected(false);

          final result = await call();

          expect(result, const Left(NetworkFailure()));
        });

        test('éxito → Right(null) y pega al datasource con el orgId', () async {
          mockConnected(true);
          if (name == 'acceptOrgInvite') {
            when(
              () => mockRemoteDataSource.acceptOrgInvite('org-9'),
            ).thenAnswer((_) async {});
          } else {
            when(
              () => mockRemoteDataSource.declineOrgInvite('org-9'),
            ).thenAnswer((_) async {});
          }

          final result = await call();

          expect(result, const Right(null));
          if (name == 'acceptOrgInvite') {
            verify(
              () => mockRemoteDataSource.acceptOrgInvite('org-9'),
            ).called(1);
          } else {
            verify(
              () => mockRemoteDataSource.declineOrgInvite('org-9'),
            ).called(1);
          }
        });

        test('404 → OrgInviteNotFoundFailure (invitación stale)', () async {
          mockConnected(true);
          if (name == 'acceptOrgInvite') {
            when(() => mockRemoteDataSource.acceptOrgInvite(any())).thenThrow(
              RestApiException(statusCode: 404, message: 'not found'),
            );
          } else {
            when(() => mockRemoteDataSource.declineOrgInvite(any())).thenThrow(
              RestApiException(statusCode: 404, message: 'not found'),
            );
          }

          final result = await call();

          expect(result, const Left(OrgInviteNotFoundFailure()));
        });

        test('429 → TooManyAttemptsFailure', () async {
          mockConnected(true);
          if (name == 'acceptOrgInvite') {
            when(() => mockRemoteDataSource.acceptOrgInvite(any())).thenThrow(
              RestApiException(statusCode: 429, message: 'rate limit'),
            );
          } else {
            when(() => mockRemoteDataSource.declineOrgInvite(any())).thenThrow(
              RestApiException(statusCode: 429, message: 'rate limit'),
            );
          }

          final result = await call();

          expect(result, const Left(TooManyAttemptsFailure()));
        });

        test('error inesperado → ServerFailure genérico', () async {
          mockConnected(true);
          if (name == 'acceptOrgInvite') {
            when(
              () => mockRemoteDataSource.acceptOrgInvite(any()),
            ).thenThrow(Exception('cualquier cosa'));
          } else {
            when(
              () => mockRemoteDataSource.declineOrgInvite(any()),
            ).thenThrow(Exception('cualquier cosa'));
          }

          final result = await call();

          expect(result, const Left(ServerFailure('Error inesperado de red')));
        });
      });
    }
  });
}
