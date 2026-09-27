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

  // Usuario org-scoped (JWT con organizationId) — §57: que el token
  // traiga org ya NO alcanza para entrar a los módulos; hace falta
  // `enteredOrg: true` en el AuthSuccess (tap en una card del selector).
  const tUser = User(
    id: '1',
    email: 'ana@test.com',
    name: 'Ana',
    organizationId: 'org-1',
  );

  // Usuario con token PERSONAL: autenticado pero sin org — la única
  // ruta alcanzable es /home (el selector de quesera vive ahí).
  const tPersonalUser = User(id: '1', email: 'ana@test.com', name: 'Ana');

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

    test('sin sesión (AuthInitial) en /accept-invite (ruta pública §68 — '
        'Email-C), no redirige', () {
      final result = authGuard.evaluate(
        AuthGuard.acceptInviteRoute,
        const AuthInitial(),
      );

      expect(result, isNull);
    });

    group('sin entrar a quesera (§57) — enteredOrg=false', () {
      test('AuthSuccess con org en el JWT pero sin entrar intentando '
          'entrar a un módulo redirige a /home — el selector vive ahí', () {
        final result = authGuard.evaluate(
          AuthGuard.receptionsRoute,
          const AuthSuccess(tUser),
        );

        expect(result, AuthGuard.homeRoute);
      });

      test('AuthSuccess sin entrar en una ruta pública (/login) redirige '
          'a /home — la regla de entrada corre antes que la de públicas', () {
        final result = authGuard.evaluate(
          AuthGuard.loginRoute,
          const AuthSuccess(tUser),
        );

        expect(result, AuthGuard.homeRoute);
      });

      test('AuthSuccess sin entrar en /splash redirige a /home', () {
        final result = authGuard.evaluate(
          AuthGuard.splashRoute,
          const AuthSuccess(tUser),
        );

        expect(result, AuthGuard.homeRoute);
      });

      test('AuthSuccess sin entrar ya en /home no redirige', () {
        final result = authGuard.evaluate(
          AuthGuard.homeRoute,
          const AuthSuccess(tUser),
        );

        expect(result, isNull);
      });

      test('AuthSuccess con token personal (sin org) en un módulo '
          'redirige a /home igual', () {
        final result = authGuard.evaluate(
          AuthGuard.receptionsRoute,
          const AuthSuccess(tPersonalUser),
        );

        expect(result, AuthGuard.homeRoute);
      });
    });

    group('con quesera entrada (§57) — enteredOrg=true', () {
      test('org en user + enteredOrg=true → los módulos quedan '
          'permitidos (no redirige)', () {
        final result = authGuard.evaluate(
          AuthGuard.receptionsRoute,
          const AuthSuccess(tUser, enteredOrg: true),
        );

        expect(result, isNull);
      });

      test('org en user + enteredOrg=true en ruta pública redirige a '
          '/home — comportamiento normal de usuario logueado', () {
        final result = authGuard.evaluate(
          AuthGuard.loginRoute,
          const AuthSuccess(tUser, enteredOrg: true),
        );

        expect(result, AuthGuard.homeRoute);
      });
    });

    group('nombrado post-signup Google (§71 — backend 087)', () {
      // Signup por Google: la org nació con el nombre de la cuenta —
      // la pantalla de nombrado se impone tras entrar a la org y
      // reaparece tras restart hasta completar u omitir.
      const tNewSignupUser = User(
        id: '1',
        email: 'ana@test.com',
        name: 'Ana',
        organizationId: 'org-1',
        isNewSignup: true,
      );

      test('enteredOrg + isNewSignup en /home → redirige a '
          '/organizacion/nombrar', () {
        final result = authGuard.evaluate(
          AuthGuard.homeRoute,
          const AuthSuccess(tNewSignupUser, enteredOrg: true),
        );

        expect(result, AuthGuard.orgNameSetupRoute);
      });

      test('enteredOrg + isNewSignup intentando ir a un módulo → '
          'redirige a /organizacion/nombrar (cubre cualquier ruta '
          'protegida)', () {
        final result = authGuard.evaluate(
          AuthGuard.receptionsRoute,
          const AuthSuccess(tNewSignupUser, enteredOrg: true),
        );

        expect(result, AuthGuard.orgNameSetupRoute);
      });

      test('enteredOrg + isNewSignup ya parado en '
          '/organizacion/nombrar → no redirige (evita loop)', () {
        final result = authGuard.evaluate(
          AuthGuard.orgNameSetupRoute,
          const AuthSuccess(tNewSignupUser, enteredOrg: true),
        );

        expect(result, isNull);
      });

      test('enteredOrg + isNewSignup en ruta pública → redirige al '
          'nombrado (el flag corre ANTES que el barrido de públicas)', () {
        final result = authGuard.evaluate(
          AuthGuard.loginRoute,
          const AuthSuccess(tNewSignupUser, enteredOrg: true),
        );

        expect(result, AuthGuard.orgNameSetupRoute);
      });

      test('isNewSignup SIN enteredOrg (todavía eligiendo quesera) → '
          'cae al /home del selector, no al nombrado — la pantalla '
          'aparece recién tras entrar a la org', () {
        final result = authGuard.evaluate(
          AuthGuard.receptionsRoute,
          const AuthSuccess(tNewSignupUser),
        );

        expect(result, AuthGuard.homeRoute);
      });

      test('isNewSignup:false + enteredOrg → comportamiento normal '
          '(en /home no redirige)', () {
        final result = authGuard.evaluate(
          AuthGuard.homeRoute,
          const AuthSuccess(tUser, enteredOrg: true),
        );

        expect(result, isNull);
      });

      test('flag limpio + enteredOrg parado en /organizacion/nombrar → '
          'sale a /home (regla de salida — tras Guardar o "Por ahora no" '
          'la pantalla suelta; sin esto el usuario quedaba atrapado)', () {
        final result = authGuard.evaluate(
          AuthGuard.orgNameSetupRoute,
          const AuthSuccess(tUser, enteredOrg: true),
        );

        expect(result, AuthGuard.homeRoute);
      });

      test('sin sesión (AuthInitial) en /organizacion/nombrar → '
          'redirige a /welcome — la ruta es protegida, no pública', () {
        final result = authGuard.evaluate(
          AuthGuard.orgNameSetupRoute,
          const AuthInitial(),
        );

        expect(result, AuthGuard.welcomeRoute);
      });
    });
  });
}
