import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/logging/interfaces/i_logger_service.dart';
import 'package:quesivo/core/network/interfaces/i_network_info.dart';
import 'package:quesivo/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:quesivo/features/users/data/datasources/interfaces/i_remote_users_datasource.dart';
import 'package:quesivo/features/users/data/models/org_member_model.dart';
import 'package:quesivo/features/users/data/models/users_page_model.dart';
import 'package:quesivo/features/users/data/repositories/users_repository_impl.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/entities/users_page.dart';
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
    registerFallbackValue(MemberStatus.suspended);
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

    test('409 + EMAIL_ALREADY_EXISTS → EmailAlreadyExistsFailure', () async {
      mockConnected(true);
      stubThrow(
        RestApiException(
          statusCode: 409,
          message: 'Email exists',
          errorCode: 'EMAIL_ALREADY_EXISTS',
        ),
      );

      final result = await callCreateUser();

      expect(result, const Left(EmailAlreadyExistsFailure()));
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

  group('linkUser (POST /auth/users/link — backend 058)', () {
    void stubLinkThrow(Object error) {
      when(
        () => mockRemoteDataSource.linkUser(
          email: any(named: 'email'),
          role: any(named: 'role'),
        ),
      ).thenThrow(error);
    }

    Future<Either<UsersFailure, OrgMember>> callLinkUser() =>
        repository.linkUser(email: tEmail, role: tRole);

    test('retorna UsersNetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await callLinkUser();

      expect(result, const Left(UsersNetworkFailure()));
      verifyNever(
        () => mockRemoteDataSource.linkUser(
          email: any(named: 'email'),
          role: any(named: 'role'),
        ),
      );
    });

    test('retorna Right(member) en éxito (linked:true)', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.linkUser(email: tEmail, role: tRole),
      ).thenAnswer((_) async => tMemberModel);

      final result = await callLinkUser();

      expect(result, const Right(tMemberModel));
    });

    test('404 + USER_NOT_FOUND → UserNotFoundFailure', () async {
      mockConnected(true);
      stubLinkThrow(
        RestApiException(
          statusCode: 404,
          message: 'User not found',
          errorCode: 'USER_NOT_FOUND',
        ),
      );

      final result = await callLinkUser();

      expect(result, const Left(UserNotFoundFailure()));
    });

    test('409 + USER_SUSPENDED → LinkedUserSuspendedFailure', () async {
      mockConnected(true);
      stubLinkThrow(
        RestApiException(
          statusCode: 409,
          message: 'User suspended',
          errorCode: 'USER_SUSPENDED',
        ),
      );

      final result = await callLinkUser();

      expect(result, const Left(LinkedUserSuspendedFailure()));
    });

    test(
      '409 + MEMBERSHIP_ALREADY_EXISTS → MembershipAlreadyExistsFailure',
      () async {
        mockConnected(true);
        stubLinkThrow(
          RestApiException(
            statusCode: 409,
            message: 'Membership exists',
            errorCode: 'MEMBERSHIP_ALREADY_EXISTS',
          ),
        );

        final result = await callLinkUser();

        expect(result, const Left(MembershipAlreadyExistsFailure()));
      },
    );

    test('409 + USER_IS_OWNER → UserIsOwnerFailure', () async {
      mockConnected(true);
      stubLinkThrow(
        RestApiException(
          statusCode: 409,
          message: 'User is owner',
          errorCode: 'USER_IS_OWNER',
        ),
      );

      final result = await callLinkUser();

      expect(result, const Left(UserIsOwnerFailure()));
    });

    test('403 → UsersForbiddenFailure', () async {
      mockConnected(true);
      stubLinkThrow(RestApiException(statusCode: 403, message: 'Forbidden'));

      final result = await callLinkUser();

      expect(result, const Left(UsersForbiddenFailure()));
    });

    test('429 → UsersRateLimitFailure', () async {
      mockConnected(true);
      stubLinkThrow(RestApiException(statusCode: 429, message: 'Throttled'));

      final result = await callLinkUser();

      expect(result, const Left(UsersRateLimitFailure()));
    });
  });

  group('getUsers (GET /auth/users — §49, doc 008)', () {
    const tPageModel = UsersPageModel(
      items: [tMemberModel],
      page: 2,
      limit: 15,
      total: 34,
      totalPages: 3,
    );

    void stubGetUsersThrow(Object error) {
      when(
        () => mockRemoteDataSource.getUsers(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          role: any(named: 'role'),
        ),
      ).thenThrow(error);
    }

    Future<Either<UsersFailure, UsersPage>> callGetUsers({
      String? search,
      UserRole? role,
    }) => repository.getUsers(page: 2, limit: 15, search: search, role: role);

    test('retorna UsersNetworkFailure si no hay conexión a internet', () async {
      mockConnected(false);

      final result = await callGetUsers(search: 'ana', role: tRole);

      expect(result, const Left(UsersNetworkFailure()));
      verifyNever(
        () => mockRemoteDataSource.getUsers(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
          role: any(named: 'role'),
        ),
      );
    });

    test(
      'manda page/limit/search/role al datasource tal cual (los query params los arma él)',
      () async {
        mockConnected(true);
        when(
          () => mockRemoteDataSource.getUsers(
            page: 2,
            limit: 15,
            search: 'ana',
            role: tRole,
          ),
        ).thenAnswer((_) async => tPageModel);

        final result = await callGetUsers(search: 'ana', role: tRole);

        expect(result, const Right(tPageModel));
        verify(
          () => mockRemoteDataSource.getUsers(
            page: 2,
            limit: 15,
            search: 'ana',
            role: tRole,
          ),
        ).called(1);
      },
    );

    test('sin filtros manda search/role en null', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.getUsers(
          page: 2,
          limit: 15,
          search: null,
          role: null,
        ),
      ).thenAnswer((_) async => tPageModel);

      final result = await callGetUsers();

      expect(result, const Right(tPageModel));
      verify(
        () => mockRemoteDataSource.getUsers(
          page: 2,
          limit: 15,
          search: null,
          role: null,
        ),
      ).called(1);
    });

    test(
      'el meta parseado llega en el Right (total/totalPages/hasMore)',
      () async {
        mockConnected(true);
        when(
          () => mockRemoteDataSource.getUsers(
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            search: any(named: 'search'),
            role: any(named: 'role'),
          ),
        ).thenAnswer((_) async => tPageModel);

        final result = await callGetUsers();

        result.fold((_) => fail('esperaba Right'), (page) {
          expect(page.page, 2);
          expect(page.total, 34);
          expect(page.totalPages, 3);
          // page 2 de 3 → queda una página por pedir.
          expect(page.hasMore, isTrue);
        });
      },
    );

    test('403 → UsersForbiddenFailure', () async {
      mockConnected(true);
      stubGetUsersThrow(
        RestApiException(statusCode: 403, message: 'Forbidden'),
      );

      final result = await callGetUsers();

      expect(result, const Left(UsersForbiddenFailure()));
    });

    test('429 → UsersRateLimitFailure', () async {
      mockConnected(true);
      stubGetUsersThrow(
        RestApiException(statusCode: 429, message: 'Throttled'),
      );

      final result = await callGetUsers();

      expect(result, const Left(UsersRateLimitFailure()));
    });

    test('500 → UsersServerFailure con el mensaje', () async {
      mockConnected(true);
      stubGetUsersThrow(RestApiException(statusCode: 500, message: 'Boom'));

      final result = await callGetUsers();

      expect(result, const Left(UsersServerFailure('Boom')));
    });

    test('excepción no-RestApi → UsersServerFailure genérico', () async {
      mockConnected(true);
      stubGetUsersThrow(Exception('cualquier cosa'));

      final result = await callGetUsers();

      expect(result, const Left(UsersServerFailure()));
    });
  });

  group('updateUserStatus (PATCH /auth/users/:id/status — §52, doc 009)', () {
    void stubStatusThrow(Object error) {
      when(
        () => mockRemoteDataSource.updateUserStatus(
          userId: any(named: 'userId'),
          status: any(named: 'status'),
        ),
      ).thenThrow(error);
    }

    Future<Either<UsersFailure, OrgMember>> callUpdateStatus() => repository
        .updateUserStatus(userId: 'uuid-1', status: MemberStatus.suspended);

    test('retorna UsersNetworkFailure si no hay conexión', () async {
      mockConnected(false);

      final result = await callUpdateStatus();

      expect(result, const Left(UsersNetworkFailure()));
      verifyNever(
        () => mockRemoteDataSource.updateUserStatus(
          userId: any(named: 'userId'),
          status: any(named: 'status'),
        ),
      );
    });

    test('retorna Right(member) con el ítem fresco del 200', () async {
      mockConnected(true);
      when(
        () => mockRemoteDataSource.updateUserStatus(
          userId: any(named: 'userId'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async => tMemberModel);

      final result = await callUpdateStatus();

      expect(result, const Right(tMemberModel));
    });

    // Las reglas de dominio del PATCH viajan como 400 + errorCode —
    // cada una tiene failure propio para el toast de la screen.
    for (final (code, expected) in [
      ('SELF_SUSPENSION', const SelfSuspensionFailure()),
      ('OWNER_SUSPENSION', const OwnerSuspensionFailure()),
      ('LAST_ADMIN', const LastAdminFailure()),
      ('INVALID_PASSWORD', const InvalidMemberDataFailure()),
    ]) {
      test('400 + $code → ${expected.runtimeType}', () async {
        mockConnected(true);
        stubStatusThrow(
          RestApiException(statusCode: 400, message: 'x', errorCode: code),
        );

        final result = await callUpdateStatus();

        expect(result, Left(expected));
      });
    }

    test(
      '400 sin errorCode conocido → UsersServerFailure con el mensaje',
      () async {
        mockConnected(true);
        stubStatusThrow(
          RestApiException(statusCode: 400, message: 'Validación rara'),
        );

        final result = await callUpdateStatus();

        expect(result, const Left(UsersServerFailure('Validación rara')));
      },
    );

    test(
      '404 + MEMBERSHIP_NOT_FOUND → MemberNotFoundFailure (card stale)',
      () async {
        mockConnected(true);
        stubStatusThrow(
          RestApiException(
            statusCode: 404,
            message: 'x',
            errorCode: 'MEMBERSHIP_NOT_FOUND',
          ),
        );

        final result = await callUpdateStatus();

        expect(result, const Left(MemberNotFoundFailure()));
      },
    );

    test('403 → UsersForbiddenFailure', () async {
      mockConnected(true);
      stubStatusThrow(RestApiException(statusCode: 403, message: 'x'));

      final result = await callUpdateStatus();

      expect(result, const Left(UsersForbiddenFailure()));
    });

    test('429 → UsersRateLimitFailure', () async {
      mockConnected(true);
      stubStatusThrow(RestApiException(statusCode: 429, message: 'x'));

      final result = await callUpdateStatus();

      expect(result, const Left(UsersRateLimitFailure()));
    });
  });

  group(
    'updateUserPassword (PATCH /auth/users/:id/password — §52, doc 010)',
    () {
      void stubPasswordThrow(Object error) {
        when(
          () => mockRemoteDataSource.updateUserPassword(
            userId: any(named: 'userId'),
            password: any(named: 'password'),
          ),
        ).thenThrow(error);
      }

      Future<Either<UsersFailure, OrgMember>> callUpdatePassword() =>
          repository.updateUserPassword(userId: 'uuid-1', password: 'Nueva123');

      test('retorna UsersNetworkFailure si no hay conexión', () async {
        mockConnected(false);

        final result = await callUpdatePassword();

        expect(result, const Left(UsersNetworkFailure()));
        verifyNever(
          () => mockRemoteDataSource.updateUserPassword(
            userId: any(named: 'userId'),
            password: any(named: 'password'),
          ),
        );
      });

      test('retorna Right(member) en éxito', () async {
        mockConnected(true);
        when(
          () => mockRemoteDataSource.updateUserPassword(
            userId: any(named: 'userId'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => tMemberModel);

        final result = await callUpdatePassword();

        expect(result, const Right(tMemberModel));
      });

      test('400 + OWNER_PASSWORD_RESET → OwnerPasswordResetFailure', () async {
        mockConnected(true);
        stubPasswordThrow(
          RestApiException(
            statusCode: 400,
            message: 'x',
            errorCode: 'OWNER_PASSWORD_RESET',
          ),
        );

        final result = await callUpdatePassword();

        expect(result, const Left(OwnerPasswordResetFailure()));
      });

      test('400 + INVALID_PASSWORD → InvalidMemberDataFailure', () async {
        mockConnected(true);
        stubPasswordThrow(
          RestApiException(
            statusCode: 400,
            message: 'x',
            errorCode: 'INVALID_PASSWORD',
          ),
        );

        final result = await callUpdatePassword();

        expect(result, const Left(InvalidMemberDataFailure()));
      });

      test('404 + MEMBERSHIP_NOT_FOUND → MemberNotFoundFailure', () async {
        mockConnected(true);
        stubPasswordThrow(
          RestApiException(
            statusCode: 404,
            message: 'x',
            errorCode: 'MEMBERSHIP_NOT_FOUND',
          ),
        );

        final result = await callUpdatePassword();

        expect(result, const Left(MemberNotFoundFailure()));
      });

      test(
        '400 sin errorCode conocido → UsersServerFailure con el mensaje',
        () async {
          mockConnected(true);
          stubPasswordThrow(
            RestApiException(statusCode: 400, message: 'Validación rara'),
          );

          final result = await callUpdatePassword();

          expect(result, const Left(UsersServerFailure('Validación rara')));
        },
      );

      test('403 → UsersForbiddenFailure', () async {
        mockConnected(true);
        stubPasswordThrow(RestApiException(statusCode: 403, message: 'x'));

        final result = await callUpdatePassword();

        expect(result, const Left(UsersForbiddenFailure()));
      });

      test('429 → UsersRateLimitFailure', () async {
        mockConnected(true);
        stubPasswordThrow(RestApiException(statusCode: 429, message: 'x'));

        final result = await callUpdatePassword();

        expect(result, const Left(UsersRateLimitFailure()));
      });
    },
  );
}
