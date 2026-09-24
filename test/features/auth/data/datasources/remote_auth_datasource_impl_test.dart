import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/device/i_device_info_service.dart';
import 'package:quesivo/core/network/interfaces/i_network_service.dart';
import 'package:quesivo/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart';

class MockNetworkService extends Mock implements INetworkService {}

class MockDeviceInfoService extends Mock implements IDeviceInfoService {}

void main() {
  late RemoteAuthDataSourceImpl dataSource;
  late MockNetworkService mockNetworkService;
  late MockDeviceInfoService mockDeviceInfoService;

  setUp(() {
    mockNetworkService = MockNetworkService();
    mockDeviceInfoService = MockDeviceInfoService();
    dataSource = RemoteAuthDataSourceImpl(
      mockNetworkService,
      mockDeviceInfoService,
    );
  });

  group('selectOrganization (§55 — doc 006)', () {
    const tOrgId = 'org-1';
    const tResponse = {
      'accessToken': 'access-org',
      'refreshToken': 'refresh-org',
      'organizationId': tOrgId,
      'organizationName': 'Quesera Norte',
    };

    test(
      'POSTea a /auth/select-organization con {organizationId} y parsea la respuesta',
      () async {
        when(
          () => mockNetworkService.post<Map<String, dynamic>>(
            '/auth/select-organization',
            data: {'organizationId': tOrgId},
          ),
        ).thenAnswer((_) async => tResponse);

        final session = await dataSource.selectOrganization(tOrgId);

        expect(session.accessToken, 'access-org');
        expect(session.refreshToken, 'refresh-org');
        expect(session.organizationId, tOrgId);
        expect(session.organizationName, 'Quesera Norte');
        verify(
          () => mockNetworkService.post<Map<String, dynamic>>(
            '/auth/select-organization',
            data: {'organizationId': tOrgId},
          ),
        ).called(1);
      },
    );

    test('propaga la excepción del network service (401 de membresía)', () {
      when(
        () => mockNetworkService.post<Map<String, dynamic>>(
          '/auth/select-organization',
          data: {'organizationId': tOrgId},
        ),
      ).thenThrow(Exception('401'));

      expect(
        () => dataSource.selectOrganization(tOrgId),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('forgotPassword (propuesta 66 — doc 013)', () {
    const tEmail = 'test@test.com';

    test('POSTea a /auth/forgot-password con {email}', () async {
      when(
        () => mockNetworkService.post<void>(
          '/auth/forgot-password',
          data: {'email': tEmail},
        ),
      ).thenAnswer((_) async {});

      await dataSource.forgotPassword(tEmail);

      verify(
        () => mockNetworkService.post<void>(
          '/auth/forgot-password',
          data: {'email': tEmail},
        ),
      ).called(1);
    });

    test('propaga la excepción del network service', () {
      when(
        () => mockNetworkService.post<void>(
          '/auth/forgot-password',
          data: {'email': tEmail},
        ),
      ).thenThrow(Exception('500'));

      expect(
        () => dataSource.forgotPassword(tEmail),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('resetPassword (propuesta 66 — doc 014)', () {
    const tToken = 'reset-token-abc';
    const tPassword = 'NuevaPass1';

    test('POSTea a /auth/reset-password con {token, password}', () async {
      when(
        () => mockNetworkService.post<void>(
          '/auth/reset-password',
          data: {'token': tToken, 'password': tPassword},
        ),
      ).thenAnswer((_) async {});

      await dataSource.resetPassword(token: tToken, password: tPassword);

      verify(
        () => mockNetworkService.post<void>(
          '/auth/reset-password',
          data: {'token': tToken, 'password': tPassword},
        ),
      ).called(1);
    });

    test('propaga la excepción del network service', () {
      when(
        () => mockNetworkService.post<void>(
          '/auth/reset-password',
          data: {'token': tToken, 'password': tPassword},
        ),
      ).thenThrow(Exception('400'));

      expect(
        () => dataSource.resetPassword(token: tToken, password: tPassword),
        throwsA(isA<Exception>()),
      );
    });
  });
}
