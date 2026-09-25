import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/di/setup_di.dart';
import 'package:quesivo/features/auth/domain/entities/org_invite.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/queseras/presentation/cubit/org_invites_cubit.dart';
import 'package:quesivo/features/queseras/presentation/cubit/org_invites_state.dart';
import 'package:quesivo/features/queseras/presentation/widgets/org_invite_card.dart';
import 'package:quesivo/features/queseras/presentation/widgets/org_invites_section.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockOrgInvitesCubit extends MockCubit<OrgInvitesState>
    implements OrgInvitesCubit {}

// La sección lee `pendingInvites` del AuthCubit por context.select — sin
// proveerlo el árbol de test explota con ProviderNotFoundException.
class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late MockOrgInvitesCubit mockInvitesCubit;
  late StreamController<OrgInvitesState> invitesController;
  late OrgInvitesState currentInvitesState;
  late MockAuthCubit mockAuthCubit;

  const tInvite = OrgInvite(
    id: 'mem-1',
    organizationId: 'org-9',
    organizationName: 'Quesera Norte',
    role: 'ADMIN',
  );

  const tUserSinInvites = User(id: 'u1', email: 'ana@test.com', name: 'Ana');

  const tUserConInvite = User(
    id: 'u1',
    email: 'ana@test.com',
    name: 'Ana',
    pendingInvites: [tInvite],
  );

  setUpAll(() {
    registerFallbackValue(tInvite);
  });

  setUp(() {
    mockInvitesCubit = MockOrgInvitesCubit();
    // Broadcast: el BlocConsumer se suscribe dos veces a bloc.stream
    // (listener + builder) — un controller normal crashea con
    // "Stream has already been listened to".
    invitesController = StreamController<OrgInvitesState>.broadcast();
    currentInvitesState = const OrgInvitesState();
    when(
      () => mockInvitesCubit.stream,
    ).thenAnswer((_) => invitesController.stream);
    when(() => mockInvitesCubit.state).thenAnswer((_) => currentInvitesState);
    when(() => mockInvitesCubit.close()).thenAnswer((_) async {});
    when(() => mockInvitesCubit.accept(any())).thenAnswer((_) async => true);
    when(() => mockInvitesCubit.decline(any())).thenAnswer((_) async => true);
    locator.registerFactory<OrgInvitesCubit>(() => mockInvitesCubit);

    mockAuthCubit = MockAuthCubit();
    when(() => mockAuthCubit.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => mockAuthCubit.state,
    ).thenReturn(const AuthSuccess(tUserSinInvites));
    when(() => mockAuthCubit.close()).thenAnswer((_) async {});
  });

  tearDown(() {
    // Sin awaits: testWidgets corre en FakeAsync — el `done` del close
    // queda encolado sin flush y un await acá colgaría el test.
    invitesController.close();
    locator.reset();
  });

  Widget buildApp() => BlocProvider<AuthCubit>.value(
    value: mockAuthCubit,
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: OrgInvitesSection()),
    ),
  );

  testWidgets('sin pendingInvites → SizedBox.shrink: no renderiza nada '
      '(el /home sin invitaciones no cambia)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(OrgInviteCard), findsNothing);
    expect(find.text('Invitaciones'), findsNothing);
  });

  testWidgets('con invites → título "Invitaciones" + card con nombre de '
      'org, chip de rol y ambos CTAs', (tester) async {
    when(
      () => mockAuthCubit.state,
    ).thenReturn(const AuthSuccess(tUserConInvite));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Invitaciones'), findsOneWidget);
    expect(find.byType(OrgInviteCard), findsOneWidget);
    expect(find.text('Quesera Norte'), findsOneWidget);
    // Chip de rol navy — label l10n del rol ADMIN.
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });

  testWidgets('tap en Aceptar llama cubit.accept(invite)', (tester) async {
    when(
      () => mockAuthCubit.state,
    ).thenReturn(const AuthSuccess(tUserConInvite));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aceptar'));
    // El success muestra QuesivoToast (OverlayEntry + Timer de hold
    // 2600ms): hay que dejar correr el hold para que el Timer se
    // dispare, si no queda pendiente al terminar el test.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    verify(() => mockInvitesCubit.accept(tInvite)).called(1);
  });

  testWidgets('tap en Rechazar llama cubit.decline(invite)', (tester) async {
    when(
      () => mockAuthCubit.state,
    ).thenReturn(const AuthSuccess(tUserConInvite));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();

    verify(() => mockInvitesCubit.decline(tInvite)).called(1);
  });
}
