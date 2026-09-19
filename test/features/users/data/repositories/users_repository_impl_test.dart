import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/logging/interfaces/i_logger_service.dart';
import 'package:quesivo/core/network/interfaces/i_network_info.dart';
import 'package:quesivo/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:quesivo/features/users/data/datasources/interfaces/i_remote_users_datasource.dart';
import 'package:quesivo/features/users/data/models/org_member_model.dart';
import 'package:quesivo/features/users/data/repositories/users_repository_impl.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';

class MockRemoteUsersDataSource extends Mock
    implements IRemoteUsersDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

class MockLoggerService extends Mock implements ILoggerService {}

void main() {
  late UsersRepositoryImpl repository;
  late MockRemoteUsersDataSource mockRemoteDataSource;
  late MockNetworkInfo mockNetworkInfo;
  late MockLoggerService mockLogger;

  const tName = 'María Quesera';
  const tEmail = 'maria@quesera.com';
  const tPassword = 'Queso123';
  const tRole = UserRole.operator;
  const tMemberModel = OrgMemberModel(
    id: 'uuid-1',
    email: tEmail,
    name: tName,
    role: tRole,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );

  setUpAll(() {
    registerFallbackValue(UserRole.operator);
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    mockRemoteDataSource = MockRemoteUsersDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockLogger = MockLoggerService();

    // El logger nunca debe romper un test: cualquier llamada retorna null.
    when(
      () => mockLogger.error(
        any(),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    repository = UsersRepositoryImpl(
      mockRemoteDataSource,
      mockNetworkInfo,
      mockLogger,
    );
  });

  void mockConnected(bool isConnected) {
    when(
      () => mockNetworkInfo.isConnected,
    ).thenAnswer((_) async => isConnected);
  }

  void stubThrow(Object error) {
    when(
      () => mockRemoteDataSource.createUser(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        role: any(named: 'role'),
      ),
    ).thenThrow(error);
  }

  Future<Either<UsersFailure, OrgMember>> callCreateUser() => repository
      .createUser(name: tName, email: tEmail, password: tPassword, role: tRole);

  group('createUser', () {
    test('retorna UsersNetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await callCreateUser();

      expect(result, const Left(UsersNetworkFailure()));
      verifyNever(
        () => mockRemoteDataSource.createUser(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          role: any(named: 'role'),
        ),
      );
    });

    test('retorna Right(member) en éxito', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.createUser(
          name: tName,
          email: tEmail,
          password: tPassword,
          role: tRole,
        ),
      ).thenAnswer((_) async => tMemberModel);

      final result = await callCreateUser();

      expect(result, const Right(tMemberModel));
    });

    test('403 → UsersForbiddenFailure', () async {
      mockConnected(true);
      stubThrow(RestApiException(statusCode: 403, message: 'Forbidden'));

      final result = await callCreateUser();

      expect(result, const Left(UsersForbiddenFailure()));
    });

    test(
      '409 + MEMBERSHIP_ALREADY_EXISTS → MembershipAlreadyExistsFailure',
      () async {
        mockConnected(true);
        stubThrow(
          RestApiException(
            statusCode: 409,
            message: 'Membership exists',
            errorCode: 'MEMBERSHIP_ALREADY_EXISTS',
          ),
        );

        final result = await callCreateUser();

        expect(result, const Left(MembershipAlreadyExistsFailure()));
      },
    );

    test('409 + USER_SUSPENDED → LinkedUserSuspendedFailure', () async {
      mockConnected(true);
      stubThrow(
        RestApiException(
          statusCode: 409,
          message: 'User suspended',
          errorCode: 'USER_SUSPENDED',
        ),
      );

      final result = await callCreateUser();

      expect(result, const Left(LinkedUserSuspendedFailure()));
    });

    test(
      '409 sin errorCode conocido → UsersServerFailure con el mensaje',
      () async {
        mockConnected(true);
        stubThrow(RestApiException(statusCode: 409, message: 'Otro choque'));

        final result = await callCreateUser();

        expect(result, const Left(UsersServerFailure('Otro choque')));
      },
    );

    test('429 → UsersRateLimitFailure', () async {
      mockConnected(true);
      stubThrow(RestApiException(statusCode: 429, message: 'Throttled'));

      final result = await callCreateUser();

      expect(result, const Left(UsersRateLimitFailure()));
    });

    test('500 → UsersServerFailure con el mensaje', () async {
      mockConnected(true);
      stubThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await callCreateUser();

      expect(result, const Left(UsersServerFailure('Boom')));
    });

    test('excepción no-RestApi → UsersServerFailure genérico', () async {
      mockConnected(true);
      stubThrow(Exception('cualquier cosa'));

      final result = await callCreateUser();

      expect(result, const Left(UsersServerFailure()));
    });
  });
}
