import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/repositories/i_users_repository.dart';
import 'package:quesivo/features/users/domain/use_cases/update_user_status_use_case.dart';

class MockUsersRepository extends Mock implements IUsersRepository {}

void main() {
  late UpdateUserStatusUseCase useCase;
  late MockUsersRepository mockRepository;

  const tUserId = 'uuid-1';
  const tMember = OrgMember(
    id: tUserId,
    email: 'maria@quesera.com',
    name: 'María Quesera',
    role: UserRole.operator,
    status: MemberStatus.suspended,
    organizationId: 'org-1',
  );

  setUpAll(() {
    registerFallbackValue(MemberStatus.suspended);
  });

  setUp(() {
    mockRepository = MockUsersRepository();
    useCase = UpdateUserStatusUseCase(mockRepository);
  });

  group(
    'updateUserStatus — passthrough (las reglas SELF/OWNER/LAST_ADMIN son del backend)',
    () {
      test('delega al repo con el userId y status pedidos', () async {
        when(
          () => mockRepository.updateUserStatus(
            userId: any(named: 'userId'),
            status: any(named: 'status'),
          ),
        ).thenAnswer((_) async => const Right(tMember));

        final result = await useCase(
          userId: tUserId,
          status: MemberStatus.suspended,
        );

        expect(result, const Right(tMember));
        verify(
          () => mockRepository.updateUserStatus(
            userId: tUserId,
            status: MemberStatus.suspended,
          ),
        ).called(1);
      });

      test('propaga el failure del repo sin traducirlo', () async {
        when(
          () => mockRepository.updateUserStatus(
            userId: any(named: 'userId'),
            status: any(named: 'status'),
          ),
        ).thenAnswer((_) async => const Left(LastAdminFailure()));

        final result = await useCase(
          userId: tUserId,
          status: MemberStatus.suspended,
        );

        expect(result, const Left(LastAdminFailure()));
      });
    },
  );
}
