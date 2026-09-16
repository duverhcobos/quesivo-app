import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:quesivo/features/auth/domain/use_cases/login_use_case.dart';
import 'package:quesivo/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';

/// Clase Falsa (Mock) que se disfraza del Repositorio Real.
/// SOLID (DIP): Como el UseCase exige una abstracción (IAuthRepository)
/// no le importa si le pasamos esta clase de mentiras.
class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late LoginUseCase useCase;
  late MockAuthRepository mockAuthRepository;

  // Se ejecuta antes de cada Test para darnos instancias limpias
  setUp(() {
    mockAuthRepository = MockAuthRepository();
    // Inyección manual de dependencias
    useCase = LoginUseCase(mockAuthRepository);
  });

  const tEmail = 'test@test.com';
  const tPassword = 'password123';
  const tUser = User(id: '1', email: tEmail, name: 'John Doe', token: 'token');

  test(
    'debería retornar un Usuario cuando el repositorio responde exitosamente',
    () async {
      // 1. Arrange (Preparar):
      // Le decimos al Mock qué responder mágicamente cuando llamen a su método
      when(
        () => mockAuthRepository.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      // 2. Act (Actuar): Ejecutamos la clase a probar
      final result = await useCase(email: tEmail, password: tPassword);

      // 3. Assert (Afirmar): El resultado debe ser un Right(User)
      expect(result, const Right(tUser));

      // Y verificamos que el UseCase haya llamado al repositorio exactamente 1 vez
      verify(
        () => mockAuthRepository.loginWithEmailPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).called(1);
      // Y que no haya hecho ninguna otra locura por debajo
      verifyNoMoreInteractions(mockAuthRepository);
    },
  );

  test(
    'debería filtrar y retornar un Failure si el password tiene menos de 6 caracteres',
    () async {
      // Act
      final result = await useCase(
        email: tEmail,
        password: '123',
      ); // Falla de lógica de negocio

      // Assert
      expect(result.isLeft(), true);
      // Verificamos matemáticamente que el repositorio JAMAS fue llamado, ahorrando peticiones al servidor
      verifyZeroInteractions(mockAuthRepository);
    },
  );
}
