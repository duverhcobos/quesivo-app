import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/di/setup_di.dart';
import 'package:quesivo/features/auth/domain/entities/organization_summary.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/home/presentation/screens/home_tab.dart';
import 'package:quesivo/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:quesivo/features/home/presentation/widgets/home_recent_activity.dart';
import 'package:quesivo/features/queseras/presentation/cubit/quesera_selection_cubit.dart';
import 'package:quesivo/features/queseras/presentation/cubit/quesera_selection_state.dart';
import 'package:quesivo/features/queseras/presentation/widgets/quesera_card.dart';
import 'package:quesivo/features/queseras/presentation/widgets/quesera_hero_card.dart';
import 'package:quesivo/features/queseras/presentation/widgets/quesera_hero_carousel.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockQueseraSelectionCubit extends MockCubit<QueseraSelectionState>
    implements QueseraSelectionCubit {}

// El carousel lee `AuthCubit` por context.select (lista de queseras +
// org activa) — sin proveerlo el árbol de test explota con
// ProviderNotFoundException.
class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late MockQueseraSelectionCubit mockSelectionCubit;
  late StreamController<QueseraSelectionState> selectionController;
  late QueseraSelectionState currentSelectionState;
  late MockAuthCubit mockAuthCubit;

  const tOrgs = [
    OrganizationSummary(id: 'org-1', name: 'Quesera Norte', role: 'ADMIN'),
    OrganizationSummary(id: 'org-2', name: 'Quesera Sur', role: 'OPERATOR'),
  ];

  // Usuario org-scoped (JWT con organizationId) — la org-1 es la activa
  // SOLO cuando el AuthSuccess trae enteredOrg=true (§57).
  const tUser = User(
    id: 'u1',
    email: 'ana@test.com',
    name: 'Ana',
    organizationId: 'org-1',
    organizationName: 'Quesera Norte',
    organizations: tOrgs,
  );

  // Usuario con token personal: autenticado pero sin org — todas las
  // cards son "Entrar" (selector limpio, §57).
  const tPersonalUser = User(
    id: 'u1',
    email: 'ana@test.com',
    name: 'Ana',
    organizations: tOrgs,
  );

  setUp(() {
    mockSelectionCubit = MockQueseraSelectionCubit();
    // Broadcast: el BlocConsumer se suscribe dos veces a bloc.stream
    // (listener + builder) — un controller normal crashea con
    // "Stream has already been listened to".
    selectionController = StreamController<QueseraSelectionState>.broadcast();
    currentSelectionState = const QueseraSelectionState();
    when(
      () => mockSelectionCubit.stream,
    ).thenAnswer((_) => selectionController.stream);
    when(
      () => mockSelectionCubit.state,
    ).thenAnswer((_) => currentSelectionState);
    when(() => mockSelectionCubit.close()).thenAnswer((_) async {});
    when(() => mockSelectionCubit.select(any())).thenAnswer((_) async => true);
    locator.registerFactory<QueseraSelectionCubit>(() => mockSelectionCubit);

    mockAuthCubit = MockAuthCubit();
    when(() => mockAuthCubit.stream).thenAnswer((_) => const Stream.empty());
    // Default: usuario que YA entró a org-1 en esta sesión (§57).
    when(
      () => mockAuthCubit.state,
    ).thenReturn(const AuthSuccess(tUser, enteredOrg: true));
    when(() => mockAuthCubit.close()).thenAnswer((_) async {});
  });

  tearDown(() {
    // Sin awaits: testWidgets corre en FakeAsync — el `done` del close
    // queda encolado sin flush y un await acá colgaría el test.
    selectionController.close();
    locator.reset();
  });

  Widget buildApp(Widget child) => BlocProvider<AuthCubit>.value(
    value: mockAuthCubit,
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('1 org activa → solo la hero card, sin PageView ni dots', (
    tester,
  ) async {
    when(() => mockAuthCubit.state).thenReturn(
      const AuthSuccess(
        User(
          id: 'u1',
          email: 'ana@test.com',
          name: 'Ana',
          organizationId: 'org-1',
          organizationName: 'Quesera Norte',
          organizations: [
            OrganizationSummary(
              id: 'org-1',
              name: 'Quesera Norte',
              role: 'ADMIN',
            ),
          ],
        ),
        enteredOrg: true,
      ),
    );

    await tester.pumpWidget(buildApp(const QueseraHeroCarousel()));
    await tester.pumpAndSettle();

    expect(find.byType(QueseraHeroCard), findsOneWidget);
    expect(find.byType(QueseraCard), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
    // La hero lleva nombre, badge "Actual" y la fila de KPIs.
    expect(find.text('Quesera Norte'), findsOneWidget);
    expect(find.text('Actual'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
  });

  testWidgets('§64 — con org activa y N queseras: SOLO la hero, sin '
      'PageView ni cards "Entrar" al lado', (tester) async {
    // Default: tUser enteredOrg=true con 2 orgs — la activa no se
    // acompaña de otras cards ni va en slide.
    await tester.pumpWidget(buildApp(const QueseraHeroCarousel()));
    await tester.pumpAndSettle();

    expect(find.byType(QueseraHeroCard), findsOneWidget);
    expect(find.byType(QueseraCard), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('selector con N orgs → PageView con dots, todas "Entrar"', (
    tester,
  ) async {
    when(
      () => mockAuthCubit.state,
    ).thenReturn(const AuthSuccess(tPersonalUser));

    await tester.pumpWidget(buildApp(const QueseraHeroCarousel()));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    // Sin activa: todas son cards "Entrar" — no hay hero navy.
    expect(find.byType(QueseraHeroCard), findsNothing);
    expect(find.byType(QueseraCard), findsNWidgets(2));
    // §61 — el CTA es el círculo-flecha (el label "Entrar" va en
    // Semantics, no pinta texto).
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(2));
    // Un dot por página (2 orgs).
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
  });

  testWidgets('tap en una card del selector llama select(orgId) del cubit', (
    tester,
  ) async {
    when(
      () => mockAuthCubit.state,
    ).thenReturn(const AuthSuccess(tPersonalUser));

    await tester.pumpWidget(buildApp(const QueseraHeroCarousel()));
    await tester.pumpAndSettle();

    // Swipe: la segunda card asoma a la derecha pero su centro está
    // fuera del viewport — se navega a la página 1 antes del tap.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quesera Sur'));
    await tester.pumpAndSettle();

    verify(() => mockSelectionCubit.select('org-2')).called(1);
  });

  testWidgets('tap en la card activa (hero) NO llama al cubit — el swipe solo '
      'navega el carousel', (tester) async {
    await tester.pumpWidget(buildApp(const QueseraHeroCarousel()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quesera Norte'));
    await tester.pumpAndSettle();

    verifyNever(() => mockSelectionCubit.select(any()));
  });

  testWidgets('§57 — sin entrar + exactamente 1 quesera → NO hay auto-select: '
      'espera el tap como todas', (tester) async {
    when(() => mockAuthCubit.state).thenReturn(
      const AuthSuccess(
        User(
          id: 'u1',
          email: 'ana@test.com',
          name: 'Ana',
          organizations: [
            OrganizationSummary(
              id: 'org-1',
              name: 'Quesera Norte',
              role: 'ADMIN',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(buildApp(const QueseraHeroCarousel()));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    verifyNever(() => mockSelectionCubit.select(any()));
    // Card única "Entrar" a ancho completo — no hay hero navy.
    expect(find.byType(QueseraHeroCard), findsNothing);
    expect(find.byType(QueseraCard), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('§57 — org en el JWT pero enteredOrg=false (sesión restaurada): '
      'todas las cards son "Entrar", sin hero navy ni badge Actual', (
    tester,
  ) async {
    // tUser trae organizationId=org-1 pero el AuthSuccess default
    // tiene enteredOrg=false → el selector arranca limpio.
    when(() => mockAuthCubit.state).thenReturn(const AuthSuccess(tUser));

    await tester.pumpWidget(buildApp(const QueseraHeroCarousel()));
    await tester.pumpAndSettle();

    expect(find.byType(QueseraHeroCard), findsNothing);
    expect(find.byType(QueseraCard), findsWidgets);
    expect(find.text('Actual'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(2));
  });

  testWidgets(
    'token personal + N queseras → NO hay auto-select (esperan el tap)',
    (tester) async {
      when(
        () => mockAuthCubit.state,
      ).thenReturn(const AuthSuccess(tPersonalUser));

      await tester.pumpWidget(buildApp(const QueseraHeroCarousel()));
      await tester.pumpAndSettle();

      verifyNever(() => mockSelectionCubit.select(any()));
      // Sin org activa todas son cards "Entrar" — no hay hero navy.
      expect(find.byType(QueseraHeroCard), findsNothing);
      expect(find.byType(QueseraCard), findsWidgets);
    },
  );

  // Cobertura de HomeTab (§58/§59 — no existe home_tab_test.dart): el
  // tab es UN solo layout siempre; sin entrar el selector abre con
  // saludo personal + hint como subtítulo (§59), sin TabPageTitle.
  group('HomeTab — layout único (§58) / selector con marca (§59)', () {
    testWidgets('sin entrar a una quesera: saludo personal + hint + quick '
        'actions y actividad — sin título Inicio', (tester) async {
      when(
        () => mockAuthCubit.state,
      ).thenReturn(const AuthSuccess(tPersonalUser));

      await tester.pumpWidget(buildApp(const HomeTab()));
      await tester.pumpAndSettle();

      // §59 — el saludo reemplaza al TabPageTitle (primer nombre del
      // tPersonalUser: "Ana").
      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(find.text('Inicio'), findsNothing);
      expect(find.text('Tus queseras'), findsNothing);
      expect(find.text('Elegí tu quesera para entrar'), findsOneWidget);
      expect(find.byType(HomeQuickActions), findsOneWidget);
      expect(find.byType(HomeRecentActivity), findsOneWidget);
      expect(find.byType(QueseraHeroCarousel), findsOneWidget);
    });

    testWidgets('con org entrada: título Inicio, sin saludo ni hint', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(const HomeTab()));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Hola, Ana'), findsNothing);
      expect(find.text('Elegí tu quesera para entrar'), findsNothing);
      expect(find.byType(HomeQuickActions), findsOneWidget);
      expect(find.byType(HomeRecentActivity), findsOneWidget);
      expect(find.byType(QueseraHeroCarousel), findsOneWidget);
    });
  });
}
