import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:quesivo/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:quesivo/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late ResetPasswordUseCase useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = ResetPasswordUseCase(mockAuthRepository);
  });

  const tToken = 'token-del-correo';
  const tPassword = 'Queso123';

  test(
    'debería retornar Right(null) cuando el repositorio responde exitosamente',
    () async {
      when(
        () => mockAuthRepository.resetPassword(
          token: tToken,
          password: tPassword,
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(
        token: tToken,
        password: tPassword,
        confirmPassword: tPassword,
      );

      expect(result, const Right(null));
      verify(
        () => mockAuthRepository.resetPassword(
          token: tToken,
          password: tPassword,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si el password es débil',
    () async {
      final result = await useCase(
        token: tToken,
        password: 'debil',
        confirmPassword: 'debil',
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si la confirmación no coincide',
    () async {
      final result = await useCase(
        token: tToken,
        password: tPassword,
        confirmPassword: 'Otro123',
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );

  test('debería retornar Left cuando el repositorio falla', () async {
    when(
      () =>
          mockAuthRepository.resetPassword(token: tToken, password: tPassword),
    ).thenAnswer(
      (_) async => const Left(ServerFailure('Token inválido o expirado')),
    );

    final result = await useCase(
      token: tToken,
      password: tPassword,
      confirmPassword: tPassword,
    );

    expect(result.isLeft(), true);
    verify(
      () =>
          mockAuthRepository.resetPassword(token: tToken, password: tPassword),
    ).called(1);
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
