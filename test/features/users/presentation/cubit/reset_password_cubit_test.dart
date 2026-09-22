import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/use_cases/update_user_password_use_case.dart';
import 'package:quesivo/features/users/presentation/cubit/reset_password_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/reset_password_state.dart';

// Disfrazamos al UseCase completo (Inversión de Control local)
class MockUpdateUserPasswordUseCase extends Mock
    implements UpdateUserPasswordUseCase {}

void main() {
  late ResetPasswordCubit cubit;
  late MockUpdateUserPasswordUseCase mockUpdatePassword;

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

  void stubSubmit(Future<Either<UsersFailure, OrgMember>> answer) {
    when(
      () => mockUpdatePassword(userId: tUserId, password: tPassword),
    ).thenAnswer((_) => answer);
  }

  Future<void> callSubmit(ResetPasswordCubit c) =>
      c.submit(userId: tUserId, password: tPassword);

  setUp(() {
    mockUpdatePassword = MockUpdateUserPasswordUseCase();
    cubit = ResetPasswordCubit(mockUpdatePassword);
  });

  tearDown(() {
    cubit.close();
  });

  test('el estado inicial debe ser ResetPasswordState limpio', () {
    expect(cubit.state, const ResetPasswordState());
    expect(cubit.state.status, FormzSubmissionStatus.initial);
  });

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'submit exitoso emite [inProgress, success+member]',
    build: () {
      stubSubmit(Future.value(const Right(tMember)));
      return cubit;
    },
    act: callSubmit,
    expect: () => [
      isA<ResetPasswordState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<ResetPasswordState>()
          .having((s) => s.status, 'status', FormzSubmissionStatus.success)
          .having((s) => s.resetMember, 'resetMember', tMember),
    ],
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'submit que falla emite [inProgress, failure+failure]',
    build: () {
      stubSubmit(Future.value(const Left(OwnerPasswordResetFailure())));
      return cubit;
    },
    act: callSubmit,
    expect: () => [
      isA<ResetPasswordState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<ResetPasswordState>()
          .having((s) => s.status, 'status', FormzSubmissionStatus.failure)
          .having(
            (s) => s.failure,
            'failure',
            const OwnerPasswordResetFailure(),
          ),
    ],
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
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
      isA<ResetPasswordState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.inProgress,
      ),
      isA<ResetPasswordState>().having(
        (s) => s.status,
        'status',
        FormzSubmissionStatus.success,
      ),
    ],
    verify: (_) {
      verify(
        () => mockUpdatePassword(userId: tUserId, password: tPassword),
      ).called(1);
    },
  );

  test('resetStatus limpia el failure cuando el usuario edita', () async {
    stubSubmit(Future.value(const Left(OwnerPasswordResetFailure())));
    await callSubmit(cubit);
    expect(cubit.state.status, FormzSubmissionStatus.failure);

    cubit.resetStatus();

    expect(cubit.state, const ResetPasswordState());
  });

  test('resetStatus no hace nada si no hay failure', () async {
    cubit.resetStatus();

    expect(cubit.state, const ResetPasswordState());
  });

  test('submit completado tras cerrar el sheet no emite ni lanza', () async {
    // El BlocProvider cierra el cubit al desmontar el sheet — si el PATCH
    // estaba en vuelo, el guard `isClosed` evita el StateError del emit.
    stubSubmit(Future.value(const Right(tMember)));
    final pending = callSubmit(cubit);
    await cubit.close();

    await expectLater(pending, completes);
  });
}
