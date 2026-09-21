import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/entities/users_page.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/repositories/i_users_repository.dart';
import 'package:quesivo/features/users/domain/use_cases/list_users_use_case.dart';

// Disfrazamos al repositorio completo (Inversión de Control local)
class MockUsersRepository extends Mock implements IUsersRepository {}

void main() {
  late ListUsersUseCase useCase;
  late MockUsersRepository mockRepository;

  const tMember = OrgMember(
    id: 'uuid-1',
    email: 'maria@quesera.com',
    name: 'María Quesera',
    role: UserRole.operator,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );
  const tPage = UsersPage(
    items: [tMember],
    page: 1,
    limit: 15,
    total: 1,
    totalPages: 1,
  );

  setUp(() {
    mockRepository = MockUsersRepository();
    useCase = ListUsersUseCase(mockRepository);
  });

  void stubGetUsers(Either<UsersFailure, UsersPage> result) {
    when(
      () => mockRepository.getUsers(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        search: any(named: 'search'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('ListUsersUseCase — thin pass-through (§49)', () {
    test('passthrough de page/limit/search/role al repositorio', () async {
      stubGetUsers(const Right(tPage));

      final result = await useCase(
        page: 2,
        limit: 15,
        search: 'ana',
        role: UserRole.operator,
      );

      expect(result, const Right(tPage));
      verify(
        () => mockRepository.getUsers(
          page: 2,
          limit: 15,
          search: 'ana',
          role: UserRole.operator,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('sin filtros pasa search/role en null', () async {
      stubGetUsers(const Right(tPage));

      await useCase(page: 1, limit: 15);

      verify(
        () => mockRepository.getUsers(
          page: 1,
          limit: 15,
          search: null,
          role: null,
        ),
      ).called(1);
    });

    test('propaga el Left(failure) del repositorio', () async {
      stubGetUsers(const Left(UsersNetworkFailure()));

      final result = await useCase(page: 1, limit: 15);

      expect(result, const Left(UsersNetworkFailure()));
    });

    test('propaga el Right(UsersPage) con el meta del backend', () async {
      const multiPage = UsersPage(
        items: [tMember],
        page: 1,
        limit: 15,
        total: 34,
        totalPages: 3,
      );
      stubGetUsers(const Right(multiPage));

      final result = await useCase(page: 1, limit: 15);

      result.fold((_) => fail('esperaba Right'), (page) {
        expect(page.total, 34);
        expect(page.totalPages, 3);
        expect(page.hasMore, isTrue);
      });
    });
  });
}
