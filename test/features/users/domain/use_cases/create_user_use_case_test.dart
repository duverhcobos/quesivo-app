import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/repositories/i_users_repository.dart';
import 'package:quesivo/features/users/domain/use_cases/create_user_use_case.dart';

class MockUsersRepository extends Mock implements IUsersRepository {}

void main() {
  late CreateUserUseCase useCase;
  late MockUsersRepository mockRepository;

  const tName = 'María Quesera';
  const tEmail = 'maria@quesera.com';
  const tPassword = 'Queso123';
  const tRole = UserRole.operator;
  const tMember = OrgMember(
    id: 'uuid-1',
    email: tEmail,
    name: tName,
    role: tRole,
    status: MemberStatus.active,
    organizationId: 'org-1',
  );

  setUpAll(() {
    registerFallbackValue(UserRole.operator);
  });

  setUp(() {
    mockRepository = MockUsersRepository();
    useCase = CreateUserUseCase(mockRepository);
  });

  void stubCreateUser(Either<UsersFailure, OrgMember> result) {
    when(
      () => mockRepository.createUser(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('validación con VOs — segunda línea defensiva del dominio', () {
    test('nombre vacío → InvalidMemberDataFailure sin tocar el repo', () async {
      final result = await useCase(
        name: '   ',
        email: tEmail,
        password: tPassword,
        role: tRole,
      );

      expect(result, const Left(InvalidMemberDataFailure()));
      verifyZeroInteractions(mockRepository);
    });

    test('email vacío → InvalidMemberDataFailure sin tocar el repo', () async {
      final result = await useCase(
        name: tName,
        email: '  ',
        password: tPassword,
        role: tRole,
      );

      expect(result, const Left(InvalidMemberDataFailure()));
      verifyZeroInteractions(mockRepository);
    });

    test(
      'email inválido → InvalidMemberDataFailure sin tocar el repo',
      () async {
        final result = await useCase(
          name: tName,
          email: 'no-es-email',
          password: tPassword,
          role: tRole,
        );

        expect(result, const Left(InvalidMemberDataFailure()));
        verifyZeroInteractions(mockRepository);
      },
    );

    test(
      'password débil → InvalidMemberDataFailure sin tocar el repo',
      () async {
        final result = await useCase(
          name: tName,
          email: tEmail,
          password: 'debil',
          role: tRole,
        );

        expect(result, const Left(InvalidMemberDataFailure()));
        verifyZeroInteractions(mockRepository);
      },
    );
  });

  group('datos válidos', () {
    test('passthrough del Right(member) del repositorio', () async {
      stubCreateUser(const Right(tMember));

      final result = await useCase(
        name: tName,
        email: tEmail,
        password: tPassword,
        role: tRole,
      );

      expect(result, const Right(tMember));
      verify(
        () => mockRepository.createUser(
          name: tName,
          email: tEmail,
          password: tPassword,
          role: tRole,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('passthrough del Left(failure) del repositorio', () async {
      stubCreateUser(const Left(MembershipAlreadyExistsFailure()));

      final result = await useCase(
        name: tName,
        email: tEmail,
        password: tPassword,
        role: tRole,
      );

      expect(result, const Left(MembershipAlreadyExistsFailure()));
    });

    test(
      'normaliza email (trim+lowercase) y name (trim) antes del repo',
      () async {
        stubCreateUser(const Right(tMember));

        await useCase(
          name: '  María Quesera  ',
          email: '  MARIA@Quesera.COM ',
          password: tPassword,
          role: tRole,
        );

        verify(
          () => mockRepository.createUser(
            name: 'María Quesera',
            email: 'maria@quesera.com',
            password: tPassword,
            role: tRole,
          ),
        ).called(1);
      },
    );

    test('el password viaja tal cual (sin trim ni transformación)', () async {
      stubCreateUser(const Right(tMember));

      await useCase(
        name: tName,
        email: tEmail,
        password: '  Queso123  ',
        role: tRole,
      );

      verify(
        () => mockRepository.createUser(
          name: tName,
          email: tEmail,
          password: '  Queso123  ',
          role: tRole,
        ),
      ).called(1);
    });
  });
}
