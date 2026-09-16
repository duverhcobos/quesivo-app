import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/logging/interfaces/i_logger_service.dart';
import 'package:quesivo/core/routes/auth_guard.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/onboarding/data/datasources/interfaces/i_onboarding_status_store.dart';

class MockLoggerService extends Mock implements ILoggerService {}

class MockOnboardingStatusStore extends Mock
    implements IOnboardingStatusStore {}

void main() {
  late MockLoggerService mockLogger;
  late MockOnboardingStatusStore mockOnboardingStatus;
  late AuthGuard authGuard;

  const tUser = User(id: '1', email: 'ana@test.com', name: 'Ana');

  setUp(() {
    mockLogger = MockLoggerService();
    mockOnboardingStatus = MockOnboardingStatusStore();

    // AuthGuard solo llama a logger.debug/info/warning con un único
    // argumento posicional (el mensaje), sin named args.
    when(() => mockLogger.debug(any())).thenReturn(null);
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.warning(any())).thenReturn(null);

    // Por defecto el onboarding ya fue visto (los tests históricos
    // esperan redirect a /login); los casos first-run lo sobrescriben.
    when(() => mockOnboardingStatus.isSeen).thenReturn(true);

    // Ahora AuthGuard recibe sus dependencias por constructor (DIP real),
    // sin pasar por el Service Locator ni por tipos de go_router.
    authGuard = AuthGuard(mockLogger, mockOnboardingStatus);
  });

  group('AuthGuard.evaluate', () {
    test(
      'mientras el AuthCubit está cargando, no redirige (deja el splash)',
      () {
        final result = authGuard.evaluate(
          AuthGuard.splashRoute,
          const AuthLoading(),
        );

        expect(result, isNull);
      },
    );

    test('sin sesión (AuthInitial) intentando entrar a una ruta protegida, '
        'redirige a /welcome', () {
      final result = authGuard.evaluate(
        AuthGuard.homeRoute,
        const AuthInitial(),
      );

      expect(result, AuthGuard.welcomeRoute);
    });

    test('sin sesión (AuthInitial) en una ruta pública, no redirige', () {
      final result = authGuard.evaluate(
        AuthGuard.loginRoute,
        const AuthInitial(),
      );

      expect(result, isNull);
    });

    test('con error de auth (AuthError) intentando entrar a ruta protegida, '
        'redirige a /welcome', () {
      final result = authGuard.evaluate(
        AuthGuard.homeRoute,
        const AuthError('credenciales inválidas'),
      );

      expect(result, AuthGuard.welcomeRoute);
    });

    test(
      'con sesión válida (AuthSuccess) parado en /login, redirige a /home',
      () {
        final result = authGuard.evaluate(
          AuthGuard.loginRoute,
          const AuthSuccess(tUser),
        );

        expect(result, AuthGuard.homeRoute);
      },
    );

    test('redirige a /home si está autenticado e intenta ir a /welcome', () {
      final result = authGuard.evaluate(
        AuthGuard.welcomeRoute,
        const AuthSuccess(tUser),
      );
      expect(result, AuthGuard.homeRoute);
    });

    test(
      'con sesión válida (AuthSuccess) parado en /splash, redirige a /home',
      () {
        final result = authGuard.evaluate(
          AuthGuard.splashRoute,
          const AuthSuccess(tUser),
        );

        expect(result, AuthGuard.homeRoute);
      },
    );

    test(
      'con sesión válida (AuthSuccess) en /forgot-password, redirige a /home',
      () {
        final result = authGuard.evaluate(
          '/forgot-password',
          const AuthSuccess(tUser),
        );

        expect(result, AuthGuard.homeRoute);
      },
    );

    test(
      'con sesión válida (AuthSuccess) ya en /home, no redirige (deja pasar)',
      () {
        final result = authGuard.evaluate(
          AuthGuard.homeRoute,
          const AuthSuccess(tUser),
        );

        expect(result, isNull);
      },
    );

    test('primera vez (!isSeen) sin sesión en ruta protegida, '
        'redirige a /onboarding', () {
      when(() => mockOnboardingStatus.isSeen).thenReturn(false);

      final result = authGuard.evaluate(
        AuthGuard.homeRoute,
        const AuthInitial(),
      );

      expect(result, AuthGuard.onboardingRoute);
    });

    test('primera vez (!isSeen) sin sesión en /splash, '
        'redirige a /onboarding', () {
      when(() => mockOnboardingStatus.isSeen).thenReturn(false);

      final result = authGuard.evaluate(
        AuthGuard.splashRoute,
        const AuthInitial(),
      );

      expect(result, AuthGuard.onboardingRoute);
    });

    test('sin sesión ya en /onboarding (ruta pública), no redirige', () {
      when(() => mockOnboardingStatus.isSeen).thenReturn(false);

      final result = authGuard.evaluate(
        AuthGuard.onboardingRoute,
        const AuthInitial(),
      );

      expect(result, isNull);
    });

    test(
      'sin sesión (AuthInitial) en /register (ruta pública), no redirige',
      () {
        final result = authGuard.evaluate(
          AuthGuard.registerRoute,
          const AuthInitial(),
        );

        expect(result, isNull);
      },
    );

    test(
      'con sesión válida (AuthSuccess) parado en /register, redirige a /home',
      () {
        final result = authGuard.evaluate(
          AuthGuard.registerRoute,
          const AuthSuccess(tUser),
        );

        expect(result, AuthGuard.homeRoute);
      },
    );
  });
}
