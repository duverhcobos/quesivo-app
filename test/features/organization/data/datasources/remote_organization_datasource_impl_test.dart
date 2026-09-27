import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/network/interfaces/i_network_service.dart';
import 'package:quesivo/features/auth/data/exceptions/auth_exceptions.dart';
import 'package:quesivo/features/organization/data/datasources/implementations/remote_organization_datasource_impl.dart';

class MockNetworkService extends Mock implements INetworkService {}

void main() {
  late RemoteOrganizationDataSourceImpl dataSource;
  late MockNetworkService mockNetworkService;

  setUp(() {
    mockNetworkService = MockNetworkService();
    dataSource = RemoteOrganizationDataSourceImpl(mockNetworkService);
  });

  group('updateCurrentName (§71 — PATCH /organizations/me, backend 087)', () {
    const tName = 'Quesera Los Alpes';

    test('PATCHea a /organizations/me con {name} y devuelve el nombre '
        'confirmado del response {id, name}', () async {
      when(
        () => mockNetworkService.patch<Map<String, dynamic>>(
          '/organizations/me',
          data: {'name': tName},
        ),
      ).thenAnswer((_) async => {'id': 'org-1', 'name': tName});

      final result = await dataSource.updateCurrentName(tName);

      expect(result, tName);
      verify(
        () => mockNetworkService.patch<Map<String, dynamic>>(
          '/organizations/me',
          data: {'name': tName},
        ),
      ).called(1);
    });

    test('propaga RestApiException del network service (401/403)', () {
      when(
        () => mockNetworkService.patch<Map<String, dynamic>>(
          '/organizations/me',
          data: any(named: 'data'),
        ),
      ).thenThrow(RestApiException(statusCode: 403, message: 'Forbidden'));

      expect(
        () => dataSource.updateCurrentName(tName),
        throwsA(isA<RestApiException>()),
      );
    });
  });
}
