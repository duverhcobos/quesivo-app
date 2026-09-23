import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/auth/domain/entities/organization_session.dart';
import 'package:quesivo/features/auth/domain/failures/auth_failure.dart';
import 'package:quesivo/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:quesivo/features/auth/domain/use_cases/select_organization_use_case.dart';

/// SOLID (DIP): Como el UseCase exige una abstracción (IAuthRepository)
/// podemos inyectar un Mock en lugar de la implementación real.
class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late SelectOrganizationUseCase useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = SelectOrganizationUseCase(mockAuthRepository);
  });

  const tOrgId = 'org-1';
  const tSession = OrganizationSession(
    accessToken: 'access-org',
    refreshToken: 'refresh-org',
    organizationId: tOrgId,
    organizationName: 'Quesera Norte',
  );

  test(
    'debería retornar Right(session) cuando el repositorio responde '
    'exitosamente (§63 — la sesión viaja al cubit para armar el User)',
    () async {
      when(() => mockAuthRepository.selectOrganization(tOrgId)).thenAnswer(
        (_) async => const Right<AuthFailure, OrganizationSession>(tSession),
      );

      final result = await useCase(tOrgId);

      expect(result, const Right<AuthFailure, OrganizationSession>(tSession));
      verify(() => mockAuthRepository.selectOrganization(tOrgId)).called(1);
      verifyNoMoreInteractions(mockAuthRepository);
    },
  );

  test('debería retornar Left cuando el repositorio falla', () async {
    when(() => mockAuthRepository.selectOrganization(tOrgId)).thenAnswer(
      (_) async => const Left<AuthFailure, OrganizationSession>(
        InvalidCredentialsFailure(),
      ),
    );

    final result = await useCase(tOrgId);

    expect(result.isLeft(), true);
    verify(() => mockAuthRepository.selectOrganization(tOrgId)).called(1);
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
