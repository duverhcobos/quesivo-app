import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/repositories/i_users_repository.dart';
import 'package:quesivo/features/users/domain/use_cases/update_user_role_use_case.dart';

class MockUsersRepository extends Mock implements IUsersRepository {}

void main() {
  late UpdateUserRoleUseCase useCase;
  late MockUsersRepository mockRepository;

  const tUserId = 'uuid-1';
  const tMember = OrgMember(
    id: tUserId,
    email: 'maria@quesera.com',
    name: 'María Quesera',
    role: UserRole.collector,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );

  setUpAll(() {
    registerFallbackValue(UserRole.operator);
  });

  setUp(() {
    mockRepository = MockUsersRepository();
    useCase = UpdateUserRoleUseCase(mockRepository);
  });

  group(
    'updateUserRole — passthrough (las reglas SELF/OWNER/LAST_ADMIN son del backend)',
    () {
      test('delega al repo con el userId y role pedidos', () async {
        when(
          () => mockRepository.updateUserRole(
            userId: any(named: 'userId'),
            role: any(named: 'role'),
          ),
        ).thenAnswer((_) async => const Right(tMember));

        final result = await useCase(userId: tUserId, role: UserRole.collector);

        expect(result, const Right(tMember));
        verify(
          () => mockRepository.updateUserRole(
            userId: tUserId,
            role: UserRole.collector,
          ),
        ).called(1);
      });

      test('propaga el failure del repo sin traducirlo', () async {
        when(
          () => mockRepository.updateUserRole(
            userId: any(named: 'userId'),
            role: any(named: 'role'),
          ),
        ).thenAnswer((_) async => const Left(SelfRoleChangeFailure()));

        final result = await useCase(userId: tUserId, role: UserRole.admin);

        expect(result, const Left(SelfRoleChangeFailure()));
      });
    },
  );
}
