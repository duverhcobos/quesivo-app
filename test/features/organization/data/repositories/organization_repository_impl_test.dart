import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/logging/interfaces/i_logger_service.dart';
import 'package:quesivo/core/network/interfaces/i_network_info.dart';
import 'package:quesivo/features/auth/data/datasources/interfaces/i_local_auth_datasource.dart';
import 'package:quesivo/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:quesivo/features/auth/data/models/user_model.dart';
import 'package:quesivo/features/auth/domain/entities/organization_summary.dart';
import 'package:quesivo/features/organization/data/datasources/interfaces/i_remote_organization_datasource.dart';
import 'package:quesivo/features/organization/data/repositories/organization_repository_impl.dart';
import 'package:quesivo/features/organization/domain/failures/organization_failure.dart';

class MockRemoteOrganizationDataSource extends Mock
    implements IRemoteOrganizationDataSource {}

class MockLocalAuthDataSource extends Mock implements ILocalAuthDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

class MockLoggerService extends Mock implements ILoggerService {}

void main() {
  late OrganizationRepositoryImpl repository;
  late MockRemoteOrganizationDataSource mockRemote;
  late MockLocalAuthDataSource mockLocal;
  late MockNetworkInfo mockNetworkInfo;
  late MockLoggerService mockLogger;

  // Sesión post-signup Google (§71): org recién creada con el nombre de
  // la cuenta + flag prendido + una segunda org para probar que el
  // rename solo toca la entrada del JWT activo.
  const tSession = UserModel(
    id: 'u1',
    email: 'ana@test.com',
    name: 'Ana',
    token: 'token-org',
    refreshToken: 'refresh-org',
    organizationId: 'org-1',
    organizationName: 'Duver Cobos',
    roles: ['ADMIN'],
    status: 'active',
    organizations: [
      OrganizationSummary(id: 'org-1', name: 'Duver Cobos', role: 'ADMIN'),
      OrganizationSummary(id: 'org-2', name: 'Otra Quesera', role: 'OPERATOR'),
    ],
    isNewSignup: true,
  );

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(tSession);
  });

  setUp(() {
    mockRemote = MockRemoteOrganizationDataSource();
    mockLocal = MockLocalAuthDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockLogger = MockLoggerService();

    // El logger nunca debe romper un test.
    when(
      () => mockLogger.error(
        any(),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.warning(
        any(),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    repository = OrganizationRepositoryImpl(
      mockRemote,
      mockLocal,
      mockNetworkInfo,
      mockLogger,
    );
  });

  void mockConnected(bool isConnected) {
    when(
      () => mockNetworkInfo.isConnected,
    ).thenAnswer((_) async => isConnected);
  }

  group('updateCurrentName', () {
    const tNewName = 'Quesera Los Alpes';

    test('sin conectividad → OrganizationNetworkFailure, sin PATCH ni '
        'escritura local', () async {
      mockConnected(false);

      final result = await repository.updateCurrentName(tNewName);

      expect(result, const Left(OrganizationNetworkFailure()));
      verifyNever(() => mockRemote.updateCurrentName(any()));
      verifyNever(() => mockLocal.saveUserSession(any()));
    });

    test('PATCH ok → Right(nombre confirmado) y la sesión cacheada queda '
        'actualizada: organizationName + la entrada del JWT en '
        'organizations + isNewSignup:false', () async {
      mockConnected(true);
      when(
        () => mockRemote.updateCurrentName(tNewName),
      ).thenAnswer((_) async => tNewName);
      when(() => mockLocal.getUserSession()).thenAnswer((_) async => tSession);
      when(() => mockLocal.saveUserSession(any())).thenAnswer((_) async {});

      final result = await repository.updateCurrentName(tNewName);

      expect(result, const Right<OrganizationFailure, String>(tNewName));

      final saved =
          verify(() => mockLocal.saveUserSession(captureAny())).captured.single
              as UserModel;
      expect(saved.organizationName, tNewName);
      expect(saved.isNewSignup, isFalse);
      // La org del JWT cambia de nombre; la otra queda intacta.
      expect(saved.organizations, [
        const OrganizationSummary(id: 'org-1', name: tNewName, role: 'ADMIN'),
        const OrganizationSummary(
          id: 'org-2',
          name: 'Otra Quesera',
          role: 'OPERATOR',
        ),
      ]);
      // El resto del perfil se conserva (id, tokens, roles, status).
      expect(saved.id, tSession.id);
      expect(saved.roles, tSession.roles);
      expect(saved.status, tSession.status);
    });

    test('PATCH ok pero sin sesión cacheada → Right igual (no revienta '
        'por un storage vacío)', () async {
      mockConnected(true);
      when(
        () => mockRemote.updateCurrentName(tNewName),
      ).thenAnswer((_) async => tNewName);
      when(() => mockLocal.getUserSession()).thenAnswer((_) async => null);

      final result = await repository.updateCurrentName(tNewName);

      expect(result, const Right<OrganizationFailure, String>(tNewName));
      verifyNever(() => mockLocal.saveUserSession(any()));
    });

    test('el nombre sale trimmeado al datasource', () async {
      mockConnected(true);
      when(
        () => mockRemote.updateCurrentName(tNewName),
      ).thenAnswer((_) async => tNewName);
      when(() => mockLocal.getUserSession()).thenAnswer((_) async => tSession);
      when(() => mockLocal.saveUserSession(any())).thenAnswer((_) async {});

      await repository.updateCurrentName('  $tNewName  ');

      verify(() => mockRemote.updateCurrentName(tNewName)).called(1);
    });

    test('401 → OrganizationForbiddenFailure, sin tocar la sesión', () async {
      mockConnected(true);
      when(
        () => mockRemote.updateCurrentName(any()),
      ).thenThrow(UnauthorizedException());

      final result = await repository.updateCurrentName(tNewName);

      expect(result, const Left(OrganizationForbiddenFailure()));
      verifyNever(() => mockLocal.saveUserSession(any()));
    });

    test('403 → OrganizationForbiddenFailure (el JWT no trae ADMIN)', () async {
      mockConnected(true);
      when(
        () => mockRemote.updateCurrentName(any()),
      ).thenThrow(RestApiException(statusCode: 403, message: 'Forbidden'));

      final result = await repository.updateCurrentName(tNewName);

      expect(result, const Left(OrganizationForbiddenFailure()));
      verifyNever(() => mockLocal.saveUserSession(any()));
    });

    test('ServerException (request sin respuesta) → '
        'OrganizationNetworkFailure', () async {
      mockConnected(true);
      when(
        () => mockRemote.updateCurrentName(any()),
      ).thenThrow(ServerException());

      final result = await repository.updateCurrentName(tNewName);

      expect(result, const Left(OrganizationNetworkFailure()));
      verifyNever(() => mockLocal.saveUserSession(any()));
    });

    test('RestApiException no mapeada (400/429/5xx) → '
        'OrganizationUpdateFailure', () async {
      mockConnected(true);
      when(
        () => mockRemote.updateCurrentName(any()),
      ).thenThrow(RestApiException(statusCode: 400, message: 'Name too short'));

      final result = await repository.updateCurrentName(tNewName);

      expect(result, const Left(OrganizationUpdateFailure()));
      verifyNever(() => mockLocal.saveUserSession(any()));
    });

    test('excepción inesperada → OrganizationUpdateFailure', () async {
      mockConnected(true);
      when(
        () => mockRemote.updateCurrentName(any()),
      ).thenThrow(Exception('cualquier cosa'));

      final result = await repository.updateCurrentName(tNewName);

      expect(result, const Left(OrganizationUpdateFailure()));
    });
  });
}
