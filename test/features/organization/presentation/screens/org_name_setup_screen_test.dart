import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/widgets/quesivo_primary_button.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/organization/domain/failures/organization_failure.dart';
import 'package:quesivo/features/organization/presentation/cubit/org_name_setup_cubit.dart';
import 'package:quesivo/features/organization/presentation/cubit/org_name_setup_state.dart';
import 'package:quesivo/features/organization/presentation/screens/org_name_setup_screen.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockOrgNameSetupCubit extends MockCubit<OrgNameSetupState>
    implements OrgNameSetupCubit {}

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late MockOrgNameSetupCubit mockOrgCubit;
  late MockAuthCubit mockAuthCubit;

  // Sesión post-signup Google (§71): la org nació con el nombre de la
  // cuenta — el campo arranca pre-llenado con él.
  const tGeneratedName = 'Duver Cobos';
  const tUser = User(
    id: '1',
    email: 'duver@test.com',
    name: 'Duver Cobos',
    token: 'token-org',
    organizationId: 'org-1',
    organizationName: tGeneratedName,
    roles: ['ADMIN'],
    isNewSignup: true,
  );

  setUp(() {
    mockOrgCubit = MockOrgNameSetupCubit();
    mockAuthCubit = MockAuthCubit();

    when(() => mockOrgCubit.state).thenReturn(const OrgNameSetupState());
    when(() => mockOrgCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockOrgCubit.submit(any())).thenAnswer((_) async {});
    when(() => mockOrgCubit.skip()).thenAnswer((_) async {});
    when(() => mockOrgCubit.close()).thenAnswer((_) async {});

    when(
      () => mockAuthCubit.state,
    ).thenReturn(const AuthSuccess(tUser, enteredOrg: true));
    when(() => mockAuthCubit.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget buildApp() => MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>.value(value: mockAuthCubit),
      BlocProvider<OrgNameSetupCubit>.value(value: mockOrgCubit),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OrgNameSetupScreen(),
    ),
  );

  QuesivoPrimaryButton saveButton(WidgetTester tester) =>
      tester.widget<QuesivoPrimaryButton>(find.byType(QuesivoPrimaryButton));

  testWidgets('renderiza título, campo PRE-LLENADO con el nombre '
      'generado, Guardar deshabilitado (sin cambios) y el skip', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('¿Cómo se llama tu quesera?'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, tGeneratedName), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Por ahora no'), findsOneWidget);

    // El nombre es el generado → no hay nada que guardar todavía.
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('Guardar se habilita al cambiar el nombre y el submit '
      'sale trimmeado', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), '  Quesera Los Alpes  ');
    await tester.pump();

    expect(saveButton(tester).onPressed, isNotNull);

    await tester.ensureVisible(find.byType(QuesivoPrimaryButton));
    await tester.pump();
    await tester.tap(find.byType(QuesivoPrimaryButton));
    await tester.pump();

    verify(() => mockOrgCubit.submit('Quesera Los Alpes')).called(1);
  });

  testWidgets('Guardar queda deshabilitado si el campo queda vacío', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.pump();

    expect(saveButton(tester).onPressed, isNull);
    verifyNever(() => mockOrgCubit.submit(any()));
  });

  testWidgets('"Por ahora no" llama skip() del cubit (limpia el flag '
      'sin PATCH)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    // El link vive al pie del form — en el viewport de 800x600 del
    // test queda bajo el fold del SingleChildScrollView.
    await tester.ensureVisible(find.text('Por ahora no'));
    await tester.pump();
    await tester.tap(find.text('Por ahora no'));
    await tester.pump();

    verify(() => mockOrgCubit.skip()).called(1);
    verifyNever(() => mockOrgCubit.submit(any()));
  });

  testWidgets('un failure del cubit muestra el toast de error '
      '(offline → mensaje de conexión)', (tester) async {
    when(() => mockOrgCubit.state).thenReturn(const OrgNameSetupState());
    when(() => mockOrgCubit.stream).thenAnswer(
      (_) => Stream.fromIterable([
        const OrgNameSetupState(failure: OrganizationNetworkFailure()),
      ]),
    );

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('No se pudo conectar al servidor — revisa tu conexión'),
      findsOneWidget,
    );

    // El hold del toast (~2.6s) + salida — si no corre, queda un Timer
    // pendiente al disponer el árbol y el test falla.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('durante el submit el campo queda congelado y las '
      'acciones ceden al loader', (tester) async {
    when(
      () => mockOrgCubit.state,
    ).thenReturn(const OrgNameSetupState(isSubmitting: true));

    await tester.pumpWidget(buildApp());
    await tester.pump();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, isFalse);
    expect(find.byType(QuesivoPrimaryButton), findsNothing);
    expect(find.text('Por ahora no'), findsNothing);
  });
}
