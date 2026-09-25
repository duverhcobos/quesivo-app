import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/deeplink/app_links_deep_link_service_impl.dart';
import 'package:quesivo/core/logging/interfaces/i_logger_service.dart';

class MockAppLinks extends Mock implements AppLinks {}

class MockLoggerService extends Mock implements ILoggerService {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  late AppLinksDeepLinkServiceImpl service;
  late MockAppLinks mockAppLinks;
  late MockLoggerService mockLogger;
  late MockGoRouter mockRouter;
  late StreamController<Uri> linkStream;
  int orgInvitesCallbacks = 0;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    mockAppLinks = MockAppLinks();
    mockLogger = MockLoggerService();
    mockRouter = MockGoRouter();
    linkStream = StreamController<Uri>();
    orgInvitesCallbacks = 0;

    // Sin link inicial por defecto — cada test que lo necesite lo re-mockea.
    when(() => mockAppLinks.getInitialLink()).thenAnswer((_) async => null);
    when(() => mockAppLinks.uriLinkStream).thenAnswer((_) => linkStream.stream);

    service = AppLinksDeepLinkServiceImpl(
      mockLogger,
      appLinks: mockAppLinks,
      onOrgInvites: () async => orgInvitesCallbacks++,
    );
    service.initialize(mockRouter);
  });

  tearDown(() async {
    await service.dispose();
    await linkStream.close();
  });

  group('links entrantes (app ya corriendo)', () {
    test(
      'quesivo://reset-password?token=x navega a /reset-password?token=x',
      () async {
        linkStream.add(Uri.parse('quesivo://reset-password?token=abc123'));
        await pumpEventQueue();

        verify(() => mockRouter.go('/reset-password?token=abc123')).called(1);
      },
    );

    test('quesivo:/reset-password (una sola barra) normaliza igual', () async {
      linkStream.add(Uri.parse('quesivo:/reset-password?token=abc123'));
      await pumpEventQueue();

      verify(() => mockRouter.go('/reset-password?token=abc123')).called(1);
    });

    test('quesivo:reset-password (sin barras) normaliza igual', () async {
      linkStream.add(Uri.parse('quesivo:reset-password?token=abc123'));
      await pumpEventQueue();

      verify(() => mockRouter.go('/reset-password?token=abc123')).called(1);
    });

    test(
      'quesivo://reset-password/ (trailing slash) normaliza igual',
      () async {
        linkStream.add(Uri.parse('quesivo://reset-password/?token=abc123'));
        await pumpEventQueue();

        verify(() => mockRouter.go('/reset-password?token=abc123')).called(1);
      },
    );

    test('sin query navega a la ruta pelada (el token vacío lo '
        'maneja el cubit)', () async {
      linkStream.add(Uri.parse('quesivo://reset-password'));
      await pumpEventQueue();

      verify(() => mockRouter.go('/reset-password')).called(1);
    });

    test('quesivo://verify-email?token=x&email=y navega a '
        '/verify-email?token=x&email=y (propuesta 67)', () async {
      linkStream.add(
        Uri.parse('quesivo://verify-email?token=abc123&email=a%40b.com'),
      );
      await pumpEventQueue();

      verify(
        () => mockRouter.go('/verify-email?token=abc123&email=a%40b.com'),
      ).called(1);
    });

    test('quesivo:/verify-email (una sola barra) normaliza igual', () async {
      linkStream.add(
        Uri.parse('quesivo:/verify-email?token=abc123&email=a%40b.com'),
      );
      await pumpEventQueue();

      verify(
        () => mockRouter.go('/verify-email?token=abc123&email=a%40b.com'),
      ).called(1);
    });

    test('quesivo:verify-email (sin barras) normaliza igual', () async {
      linkStream.add(
        Uri.parse('quesivo:verify-email?token=abc123&email=a%40b.com'),
      );
      await pumpEventQueue();

      verify(
        () => mockRouter.go('/verify-email?token=abc123&email=a%40b.com'),
      ).called(1);
    });

    test('quesivo://verify-email/ (trailing slash) normaliza igual', () async {
      linkStream.add(
        Uri.parse('quesivo://verify-email/?token=abc123&email=a%40b.com'),
      );
      await pumpEventQueue();

      verify(
        () => mockRouter.go('/verify-email?token=abc123&email=a%40b.com'),
      ).called(1);
    });

    test('quesivo://accept-invite?token=x&email=y navega a '
        '/accept-invite?token=x&email=y (propuesta 68 — Email-C)', () async {
      linkStream.add(
        Uri.parse('quesivo://accept-invite?token=abc123&email=a%40b.com'),
      );
      await pumpEventQueue();

      verify(
        () => mockRouter.go('/accept-invite?token=abc123&email=a%40b.com'),
      ).called(1);
    });

    test('quesivo:/accept-invite (una sola barra) normaliza igual', () async {
      linkStream.add(
        Uri.parse('quesivo:/accept-invite?token=abc123&email=a%40b.com'),
      );
      await pumpEventQueue();

      verify(
        () => mockRouter.go('/accept-invite?token=abc123&email=a%40b.com'),
      ).called(1);
    });

    test('quesivo://accept-invite/ (trailing slash) normaliza igual', () async {
      linkStream.add(
        Uri.parse('quesivo://accept-invite/?token=abc123&email=a%40b.com'),
      );
      await pumpEventQueue();

      verify(
        () => mockRouter.go('/accept-invite?token=abc123&email=a%40b.com'),
      ).called(1);
    });

    test('quesivo://org-invites navega a /home (alias §69 — la sección '
        'de invitaciones vive en la capa personal, backend 072)', () async {
      linkStream.add(Uri.parse('quesivo://org-invites'));
      await pumpEventQueue();

      verify(() => mockRouter.go('/home')).called(1);
    });

    test(
      'quesivo://org-invites dispara el callback de refresh '
      '(§69 — el invitado con sesión viva ve la card sin re-login)',
      () async {
        linkStream.add(Uri.parse('quesivo://org-invites'));
        await pumpEventQueue();

        expect(orgInvitesCallbacks, 1);
      },
    );

    test('esquema distinto a quesivo se ignora por completo', () async {
      linkStream.add(Uri.parse('https://reset-password?token=abc123'));
      await pumpEventQueue();

      verifyNever(() => mockRouter.go(any()));
      verifyNever(() => mockLogger.warning(any()));
    });

    test('ruta desconocida no navega y el warning NO incluye el '
        'token (secreto — los logs de release van a Crashlytics)', () async {
      linkStream.add(Uri.parse('quesivo://otra-ruta?token=secreto123'));
      await pumpEventQueue();

      verifyNever(() => mockRouter.go(any()));
      final logged =
          verify(() => mockLogger.warning(captureAny())).captured.single
              as String;
      expect(logged, isNot(contains('secreto123')));
      expect(logged, contains('/otra-ruta'));
    });
  });

  group('link inicial (cold start)', () {
    // El handle del link inicial se difiere a post-frame (endOfFrame) para
    // no competir con el initialLocation /splash del router. Sin binding de
    // widgets produciendo frames ese future queda pendiente — lo que este
    // test aprovecha para verificar justamente la deferral: el link NO se
    // navega ni siquiera tras drenar los microtasks (la navegación real
    // post-frame se verificó en device — cold start por adb intent).
    test('con link inicial no navega antes del primer frame '
        '(diferido a post-frame)', () async {
      await service.dispose();

      final coldAppLinks = MockAppLinks();
      final coldStream = StreamController<Uri>();
      when(() => coldAppLinks.getInitialLink()).thenAnswer(
        (_) async => Uri.parse('quesivo://reset-password?token=cold99'),
      );
      when(
        () => coldAppLinks.uriLinkStream,
      ).thenAnswer((_) => coldStream.stream);

      final coldService = AppLinksDeepLinkServiceImpl(
        mockLogger,
        appLinks: coldAppLinks,
      );
      coldService.initialize(mockRouter);
      await pumpEventQueue();

      verifyNever(() => mockRouter.go(any()));

      await coldService.dispose();
      await coldStream.close();
    });

    test('sin link inicial no navega ni loguea', () async {
      await pumpEventQueue();

      verifyNever(() => mockRouter.go(any()));
      verifyNever(() => mockLogger.warning(any()));
    });
  });
}
