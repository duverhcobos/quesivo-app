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

  group('loginWithGoogle (propuesta 70 — doc 022, backend 085)', () {
    const tIdToken = 'google-id-token.jwt.firmado';
    const tResponse = {
      'id': '1',
      'email': 'user@google.com',
      'name': 'Google User',
      'accessToken': 'token-personal',
      'refreshToken': 'refresh-personal',
    };

    test('POSTea a /auth/google con idToken + deviceId/deviceName (sesión '
        'etiquetada, como login) y devuelve el UserModel de sesión '
        'personal — mismo shape que /auth/login', () async {
      when(
        () => mockDeviceInfoService.getDeviceId(),
      ).thenAnswer((_) async => 'device-1');
      when(
        () => mockDeviceInfoService.getDeviceName(),
      ).thenAnswer((_) async => 'Pixel 8');
      when(
        () => mockNetworkService.post<Map<String, dynamic>>(
          '/auth/google',
          data: {
            'idToken': tIdToken,
            'deviceId': 'device-1',
            'deviceName': 'Pixel 8',
          },
        ),
      ).thenAnswer((_) async => tResponse);

      final user = await dataSource.loginWithGoogle(idToken: tIdToken);

      expect(user.id, '1');
      expect(user.email, 'user@google.com');
      expect(user.token, 'token-personal');
      expect(user.refreshToken, 'refresh-personal');
      verify(
        () => mockNetworkService.post<Map<String, dynamic>>(
          '/auth/google',
          data: {
            'idToken': tIdToken,
            'deviceId': 'device-1',
            'deviceName': 'Pixel 8',
          },
        ),
      ).called(1);
    });

    test('propaga la excepción del network service (401 token inválido)', () {
      when(
        () => mockDeviceInfoService.getDeviceId(),
      ).thenAnswer((_) async => 'device-1');
      when(
        () => mockDeviceInfoService.getDeviceName(),
      ).thenAnswer((_) async => 'Pixel 8');
      when(
        () => mockNetworkService.post<Map<String, dynamic>>(
          '/auth/google',
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('401'));

      expect(
        () => dataSource.loginWithGoogle(idToken: tIdToken),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('register (propuesta 67 — doc 001)', () {
    const tOrgName = 'Quesera Los Alpes';
    const tName = 'María Quesera';
    const tEmail = 'test@test.com';
    const tPassword = 'NuevaPass1';

    setUp(() {
      when(
        () => mockDeviceInfoService.getDeviceId(),
      ).thenAnswer((_) async => 'device-1');
      when(
        () => mockDeviceInfoService.getDeviceName(),
      ).thenAnswer((_) async => 'Pixel 8');
    });

    test('POSTea a /auth/register con deviceId/deviceName y NO parsea '
        'el body (201 vacío — backend 069: la cuenta queda '
        'pending_verification)', () async {
      when(
        () => mockNetworkService.post<void>(
          '/auth/register',
          data: {
            'organizationName': tOrgName,
            'name': tName,
            'email': tEmail,
            'password': tPassword,
            'deviceId': 'device-1',
            'deviceName': 'Pixel 8',
          },
        ),
      ).thenAnswer((_) async {});

      await dataSource.register(
        organizationName: tOrgName,
        name: tName,
        email: tEmail,
        password: tPassword,
      );

      verify(
        () => mockNetworkService.post<void>(
          '/auth/register',
          data: {
            'organizationName': tOrgName,
            'name': tName,
            'email': tEmail,
            'password': tPassword,
            'deviceId': 'device-1',
            'deviceName': 'Pixel 8',
          },
        ),
      ).called(1);
      // Contrato nuevo: nunca se llama a UserModel.fromJson sobre la
      // respuesta — el método devuelve void.
      verifyNever(
        () => mockNetworkService.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      );
    });

    test('propaga la excepción del network service (409 email en uso)', () {
      when(
        () => mockNetworkService.post<void>(
          '/auth/register',
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('409'));

      expect(
        () => dataSource.register(
          organizationName: tOrgName,
          name: tName,
          email: tEmail,
          password: tPassword,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('verifyEmail (propuesta 67 — doc 015)', () {
    const tToken = 'verify-token-abc';
    const tResponse = {
      'id': '1',
      'email': 'test@test.com',
      'name': 'John Doe',
      'accessToken': 'token-personal',
      'refreshToken': 'refresh-personal',
    };

    setUp(() {
      when(
        () => mockDeviceInfoService.getDeviceId(),
      ).thenAnswer((_) async => 'device-1');
      when(
        () => mockDeviceInfoService.getDeviceName(),
      ).thenAnswer((_) async => 'Pixel 8');
    });

    test(
      'POSTea a /auth/verify-email con {token, deviceId, deviceName} '
      'y devuelve el UserModel (auto-login — mismo shape que login)',
      () async {
        when(
          () => mockNetworkService.post<Map<String, dynamic>>(
            '/auth/verify-email',
            data: {
              'token': tToken,
              'deviceId': 'device-1',
              'deviceName': 'Pixel 8',
            },
          ),
        ).thenAnswer((_) async => tResponse);

        final user = await dataSource.verifyEmail(tToken);

        expect(user.id, '1');
        expect(user.email, 'test@test.com');
        expect(user.token, 'token-personal');
        expect(user.refreshToken, 'refresh-personal');
        verify(
          () => mockNetworkService.post<Map<String, dynamic>>(
            '/auth/verify-email',
            data: {
              'token': tToken,
              'deviceId': 'device-1',
              'deviceName': 'Pixel 8',
            },
          ),
        ).called(1);
      },
    );

    test('propaga la excepción del network service (400 token inválido)', () {
      when(
        () => mockNetworkService.post<Map<String, dynamic>>(
          '/auth/verify-email',
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('400'));

      expect(() => dataSource.verifyEmail(tToken), throwsA(isA<Exception>()));
    });
  });

  group('acceptInvite (propuesta 68 — doc 017, Email-C)', () {
    const tToken = 'invite-token-abc';
    const tPassword = 'NuevaPass123';
    const tResponse = {
      'id': '1',
      'email': 'invitado@test.com',
      'name': 'Invitado',
      'accessToken': 'token-personal',
      'refreshToken': 'refresh-personal',
    };

    setUp(() {
      when(
        () => mockDeviceInfoService.getDeviceId(),
      ).thenAnswer((_) async => 'device-1');
      when(
        () => mockDeviceInfoService.getDeviceName(),
      ).thenAnswer((_) async => 'Pixel 8');
    });

    test(
      'POSTea a /auth/accept-invite con {token, password, deviceId, deviceName} '
      'y devuelve el UserModel (auto-login — mismo shape que verify-email)',
      () async {
        when(
          () => mockNetworkService.post<Map<String, dynamic>>(
            '/auth/accept-invite',
            data: {
              'token': tToken,
              'password': tPassword,
              'deviceId': 'device-1',
              'deviceName': 'Pixel 8',
            },
          ),
        ).thenAnswer((_) async => tResponse);

        final user = await dataSource.acceptInvite(
          token: tToken,
          password: tPassword,
        );

        expect(user.id, '1');
        expect(user.email, 'invitado@test.com');
        expect(user.token, 'token-personal');
        expect(user.refreshToken, 'refresh-personal');
        verify(
          () => mockNetworkService.post<Map<String, dynamic>>(
            '/auth/accept-invite',
            data: {
              'token': tToken,
              'password': tPassword,
              'deviceId': 'device-1',
              'deviceName': 'Pixel 8',
            },
          ),
        ).called(1);
      },
    );

    test('propaga la excepción del network service (400 token inválido)', () {
      when(
        () => mockNetworkService.post<Map<String, dynamic>>(
          '/auth/accept-invite',
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('400'));

      expect(
        () => dataSource.acceptInvite(token: tToken, password: tPassword),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('resendVerification (propuesta 67 — doc 016)', () {
    const tEmail = 'test@test.com';

    test('POSTea a /auth/resend-verification con {email}', () async {
      when(
        () => mockNetworkService.post<void>(
          '/auth/resend-verification',
          data: {'email': tEmail},
        ),
      ).thenAnswer((_) async {});

      await dataSource.resendVerification(tEmail);

      verify(
        () => mockNetworkService.post<void>(
          '/auth/resend-verification',
          data: {'email': tEmail},
        ),
      ).called(1);
    });

    test('propaga la excepción del network service', () {
      when(
        () => mockNetworkService.post<void>(
          '/auth/resend-verification',
          data: {'email': tEmail},
        ),
      ).thenThrow(Exception('429'));

      expect(
        () => dataSource.resendVerification(tEmail),
        throwsA(isA<Exception>()),
      );
    });
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
