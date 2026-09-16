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
    test('retorna Right(user) si hay una sesión local guardada', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => tUserModel);

      final result = await repository.checkAuthStatus();

      expect(result, const Right(tUserModel));
    });

    test('retorna NoSessionFailure si no hay sesión guardada', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenAnswer((_) async => null);

      final result = await repository.checkAuthStatus();

      expect(result, const Left(NoSessionFailure()));
    });

    test('retorna ServerFailure si falla la lectura local', () async {
      when(
        () => mockLocalDataSource.getUserSession(),
      ).thenThrow(Exception('storage corrupto'));

      final result = await repository.checkAuthStatus();

      expect(result, const Left(ServerFailure('Error leyendo sesión local')));
    });
  });

  group('logout', () {
    test(
      'retorna Right(null) y delega en clearSession del datasource local',
      () async {
        when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

        final result = await repository.logout();

        expect(result, const Right(null));
        verify(() => mockLocalDataSource.clearSession()).called(1);
      },
    );

    test('retorna CacheFailure si falla el borrado de sesión', () async {
      when(
        () => mockLocalDataSource.clearSession(),
      ).thenThrow(Exception('storage bloqueado'));

      final result = await repository.logout();

      expect(result, const Left(CacheFailure('No se pudo cerrar la sesión.')));
    });
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
