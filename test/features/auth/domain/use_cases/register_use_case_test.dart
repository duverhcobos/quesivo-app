import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:quesivo/features/auth/domain/use_cases/register_use_case.dart';
import 'package:quesivo/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late RegisterUseCase useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = RegisterUseCase(mockAuthRepository);
  });

  const tOrgName = 'Quesera Los Alpes';
  const tName = 'María Quesera';
  const tEmail = 'maria@quesera.com';
  const tPassword = 'Queso123';
  const tUser = User(id: '1', email: tEmail, name: tName, token: 'token');

  test(
    'debería retornar un Usuario cuando el repositorio responde exitosamente',
    () async {
      when(
        () => mockAuthRepository.register(
          organizationName: tOrgName,
          name: tName,
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      final result = await useCase(
        organizationName: tOrgName,
        name: tName,
        email: tEmail,
        password: tPassword,
      );

      expect(result, const Right(tUser));
      verify(
        () => mockAuthRepository.register(
          organizationName: tOrgName,
          name: tName,
          email: tEmail,
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
        organizationName: tOrgName,
        name: tName,
        email: tEmail,
        password: 'debil',
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si el email es inválido',
    () async {
      final result = await useCase(
        organizationName: tOrgName,
        name: tName,
        email: 'no-es-email',
        password: tPassword,
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si el nombre está vacío',
    () async {
      final result = await useCase(
        organizationName: tOrgName,
        name: '  ',
        email: tEmail,
        password: tPassword,
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );

  test(
    'debería retornar Failure y NO tocar el repositorio si el nombre de la quesera está vacío',
    () async {
      final result = await useCase(
        organizationName: ' ',
        name: tName,
        email: tEmail,
        password: tPassword,
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockAuthRepository);
    },
  );
}
