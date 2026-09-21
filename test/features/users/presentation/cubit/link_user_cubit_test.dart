import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/use_cases/link_user_use_case.dart';
import 'package:quesivo/features/users/presentation/cubit/link_user_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/link_user_state.dart';

// Disfrazamos al UseCase completo (Inversión de Control local)
class MockLinkUserUseCase extends Mock implements LinkUserUseCase {}

void main() {
  late LinkUserCubit cubit;
  late MockLinkUserUseCase mockLinkUser;

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

  void stubSubmit(Future<Either<UsersFailure, OrgMember>> answer) {
    when(
      () => mockLinkUser(email: tEmail, role: tRole),
    ).thenAnswer((_) => answer);
  }

  Future<void> callSubmit(LinkUserCubit c) =>
      c.submit(email: tEmail, role: tRole);

  setUp(() {
    mockLinkUser = MockLinkUserUseCase();
    cubit = LinkUserCubit(mockLinkUser);
  });

  tearDown(() {
    cubit.close();
  });

  test('el estado inicial debe ser LinkUserState limpio', () {
    expect(cubit.state, const LinkUserState());
    expect(cubit.state.status, FormzSubmissionStatus.initial);
  });

  blocTest<LinkUserCubit, LinkUserState>(
    'submit exitoso emite [inProgress, success+member]',
    build: () {
      stubSubmit(Future.value(const Right(tMember)));
      return cubit;
    },
    act: callSubmit,
    expect: () => [
      isA<LinkUserState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<LinkUserState>()
          .having((s) => s.status, 'status', FormzSubmissionStatus.success)
          .having((s) => s.linkedMember, 'linkedMember', tMember),
    ],
  );

  blocTest<LinkUserCubit, LinkUserState>(
    'submit que falla emite [inProgress, failure+failure]',
    build: () {
      stubSubmit(Future.value(const Left(UserNotFoundFailure())));
      return cubit;
    },
    act: callSubmit,
    expect: () => [
      isA<LinkUserState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<LinkUserState>()
          .having((s) => s.status, 'status', FormzSubmissionStatus.failure)
          .having(
            (s) => s.failure,
            'failure',
            const UserNotFoundFailure(),
          ),
    ],
  );

  blocTest<LinkUserCubit, LinkUserState>(
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
      isA<LinkUserState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<LinkUserState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.success,
      ),
    ],
    verify: (_) {
      verify(() => mockLinkUser(email: tEmail, role: tRole)).called(1);
    },
  );

  test('resetStatus limpia el failure cuando el usuario edita', () async {
    stubSubmit(Future.value(const Left(UserNotFoundFailure())));
    await callSubmit(cubit);
    expect(cubit.state.status, FormzSubmissionStatus.failure);

    cubit.resetStatus();

    expect(cubit.state, const LinkUserState());
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
