import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/use_cases/create_user_use_case.dart';
import 'package:quesivo/features/users/presentation/cubit/create_user_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/create_user_state.dart';

// Disfrazamos al UseCase completo (Inversión de Control local)
class MockCreateUserUseCase extends Mock implements CreateUserUseCase {}

void main() {
  late CreateUserCubit cubit;
  late MockCreateUserUseCase mockCreateUser;

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

  void stubSubmit(Future<Either<UsersFailure, OrgMember>> answer) {
    when(
      () => mockCreateUser(
        name: tName,
        email: tEmail,
        password: tPassword,
        role: tRole,
      ),
    ).thenAnswer((_) => answer);
  }

  Future<void> callSubmit(CreateUserCubit c) =>
      c.submit(name: tName, email: tEmail, password: tPassword, role: tRole);

  setUp(() {
    mockCreateUser = MockCreateUserUseCase();
    cubit = CreateUserCubit(mockCreateUser);
  });

  tearDown(() {
    cubit.close();
  });

  test('el estado inicial debe ser CreateUserState limpio', () {
    expect(cubit.state, const CreateUserState());
    expect(cubit.state.status, FormzSubmissionStatus.initial);
  });

  blocTest<CreateUserCubit, CreateUserState>(
    'submit exitoso emite [inProgress, success+member]',
    build: () {
      stubSubmit(Future.value(const Right(tMember)));
      return cubit;
    },
    act: callSubmit,
    expect: () => [
      isA<CreateUserState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<CreateUserState>()
          .having((s) => s.status, 'status', FormzSubmissionStatus.success)
          .having((s) => s.createdMember, 'createdMember', tMember),
    ],
  );

  blocTest<CreateUserCubit, CreateUserState>(
    'submit que falla emite [inProgress, failure+failure]',
    build: () {
      stubSubmit(Future.value(const Left(MembershipAlreadyExistsFailure())));
      return cubit;
    },
    act: callSubmit,
    expect: () => [
      isA<CreateUserState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<CreateUserState>()
          .having((s) => s.status, 'status', FormzSubmissionStatus.failure)
          .having(
            (s) => s.failure,
            'failure',
            const MembershipAlreadyExistsFailure(),
          ),
    ],
  );

  blocTest<CreateUserCubit, CreateUserState>(
    'un segundo submit en vuelo se ignora (anti doble-tap)',
    build: () {
      stubSubmit(Future.value(const Right(tMember)));
      return cubit;
    },
    act: (cubit) async {
      // El primer submit emite inProgress de forma síncrona (antes del
      // await del use case); el segundo ve isInProgress y retorna.
      await Future.wait([callSubmit(cubit), callSubmit(cubit)]);
    },
    expect: () => [
      isA<CreateUserState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<CreateUserState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.success,
      ),
    ],
    verify: (_) {
      verify(
        () => mockCreateUser(
          name: tName,
          email: tEmail,
          password: tPassword,
          role: tRole,
        ),
      ).called(1);
    },
  );

  test('resetStatus limpia el failure cuando el usuario edita', () async {
    stubSubmit(Future.value(const Left(MembershipAlreadyExistsFailure())));
    await callSubmit(cubit);
    expect(cubit.state.status, FormzSubmissionStatus.failure);

    cubit.resetStatus();

    expect(cubit.state, const CreateUserState());
  });

  test('submit completado tras cerrar el sheet no emite ni lanza', () async {
    // El BlocProvider cierra el cubit al desmontar el sheet — si el POST
    // estaba en vuelo, el guard `isClosed` evita el StateError del emit.
    stubSubmit(Future.value(const Right(tMember)));
    final pending = callSubmit(cubit);
    await cubit.close();

    await expectLater(pending, completes);
  });
}
