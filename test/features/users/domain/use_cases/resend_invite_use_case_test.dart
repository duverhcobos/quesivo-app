import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/domain/repositories/i_users_repository.dart';
import 'package:quesivo/features/users/domain/use_cases/resend_invite_use_case.dart';

class MockUsersRepository extends Mock implements IUsersRepository {}

void main() {
  late ResendInviteUseCase useCase;
  late MockUsersRepository mockRepository;

  setUp(() {
    mockRepository = MockUsersRepository();
    useCase = ResendInviteUseCase(mockRepository);
  });

  group('resendInvite (§68 — Email-C, doc 018)', () {
    test('passthrough del Right(null) del repositorio', () async {
      when(
        () => mockRepository.resendInvite(userId: 'uuid-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(userId: 'uuid-1');

      expect(result, const Right(null));
      verify(() => mockRepository.resendInvite(userId: 'uuid-1')).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('passthrough del Left(InviteNotPendingFailure) del repo '
        '(el invitado ya aceptó — data stale)', () async {
      when(
        () => mockRepository.resendInvite(userId: 'uuid-1'),
      ).thenAnswer((_) async => const Left(InviteNotPendingFailure()));

      final result = await useCase(userId: 'uuid-1');

      expect(result, const Left(InviteNotPendingFailure()));
    });
  });
}
