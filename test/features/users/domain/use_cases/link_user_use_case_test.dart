import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/repositories/i_users_repository.dart';
import 'package:quesivo/features/users/domain/use_cases/link_user_use_case.dart';

class MockUsersRepository extends Mock implements IUsersRepository {}

void main() {
  late LinkUserUseCase useCase;
  late MockUsersRepository mockRepository;

  const tEmail = 'maria@quesera.com';
  const tRole = UserRole.operator;
  const tMember = OrgMember(
    id: 'uuid-1',
    email: tEmail,
    name: 'María Quesera',
    role: tRole,
    status: MemberStatus.active,
    organizationId: 'org-1',
    linked: true,
  );

  setUpAll(() {
    registerFallbackValue(UserRole.operator);
  });

  setUp(() {
    mockRepository = MockUsersRepository();
    useCase = LinkUserUseCase(mockRepository);
  });

  void stubLinkUser(Either<UsersFailure, OrgMember> result) {
    when(
      () => mockRepository.linkUser(
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('validación con VOs — segunda línea defensiva del dominio', () {
    test('email vacío → InvalidMemberDataFailure sin tocar el repo', () async {
      final result = await useCase(email: '  ', role: tRole);

      expect(result, const Left(InvalidMemberDataFailure()));
      verifyZeroInteractions(mockRepository);
    });

    test(
      'email inválido → InvalidMemberDataFailure sin tocar el repo',
      () async {
        final result = await useCase(email: 'no-es-email', role: tRole);

        expect(result, const Left(InvalidMemberDataFailure()));
        verifyZeroInteractions(mockRepository);
      },
    );
  });

  group('datos válidos', () {
    test('passthrough del Right(member) del repositorio', () async {
      stubLinkUser(const Right(tMember));

      final result = await useCase(email: tEmail, role: tRole);

      expect(result, const Right(tMember));
      verify(
        () => mockRepository.linkUser(email: tEmail, role: tRole),
      ).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('passthrough del Left(failure) del repositorio', () async {
      stubLinkUser(const Left(UserNotFoundFailure()));

      final result = await useCase(email: tEmail, role: tRole);

      expect(result, const Left(UserNotFoundFailure()));
    });

    test('normaliza email (trim+lowercase) antes del repo', () async {
      stubLinkUser(const Right(tMember));

      await useCase(email: '  MARIA@Quesera.COM ', role: tRole);

      verify(
        () => mockRepository.linkUser(email: 'maria@quesera.com', role: tRole),
      ).called(1);
    });
  });
}
