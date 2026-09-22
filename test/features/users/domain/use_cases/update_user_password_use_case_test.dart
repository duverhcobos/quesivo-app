import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/repositories/i_users_repository.dart';
import 'package:quesivo/features/users/domain/use_cases/update_user_password_use_case.dart';

class MockUsersRepository extends Mock implements IUsersRepository {}

void main() {
  late UpdateUserPasswordUseCase useCase;
  late MockUsersRepository mockRepository;

  const tUserId = 'uuid-1';
  const tPassword = 'Nueva123';
  const tMember = OrgMember(
    id: tUserId,
    email: 'maria@quesera.com',
    name: 'María Quesera',
    role: UserRole.operator,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );

  setUp(() {
    mockRepository = MockUsersRepository();
    useCase = UpdateUserPasswordUseCase(mockRepository);
  });

  group('validación con VO — segunda línea defensiva del dominio', () {
    test(
      'password débil → InvalidMemberDataFailure sin tocar el repo',
      () async {
        final result = await useCase(userId: tUserId, password: 'abc');

        expect(result, const Left(InvalidMemberDataFailure()));
        verifyZeroInteractions(mockRepository);
      },
    );

    test(
      'password sin mayúscula → InvalidMemberDataFailure sin tocar el repo',
      () async {
        final result = await useCase(userId: tUserId, password: 'nueva123');

        expect(result, const Left(InvalidMemberDataFailure()));
        verifyZeroInteractions(mockRepository);
      },
    );
  });

  group('delegación al repo', () {
    test('password válido → llama al repo con userId + password', () async {
      when(
        () => mockRepository.updateUserPassword(
          userId: any(named: 'userId'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Right(tMember));

      final result = await useCase(userId: tUserId, password: tPassword);

      expect(result, const Right(tMember));
      verify(
        () => mockRepository.updateUserPassword(
          userId: tUserId,
          password: tPassword,
        ),
      ).called(1);
    });

    test('propaga el failure del repo sin traducirlo', () async {
      when(
        () => mockRepository.updateUserPassword(
          userId: any(named: 'userId'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(OwnerPasswordResetFailure()));

      final result = await useCase(userId: tUserId, password: tPassword);

      expect(result, const Left(OwnerPasswordResetFailure()));
    });
  });
}
