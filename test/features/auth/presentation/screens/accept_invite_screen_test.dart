import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/widgets/quesivo_primary_button.dart';
import 'package:quesivo/features/auth/domain/entities/user.dart';
import 'package:quesivo/features/auth/domain/use_cases/accept_invite_use_case.dart';
import 'package:quesivo/features/auth/domain/use_cases/resend_verification_use_case.dart';
import 'package:quesivo/features/auth/presentation/cubit/accept_invite_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/auth_state.dart';
import 'package:quesivo/features/auth/presentation/screens/accept_invite_screen.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockAcceptInviteUseCase extends Mock implements AcceptInviteUseCase {}

class MockResendVerificationUseCase extends Mock
    implements ResendVerificationUseCase {}

// La screen dispara refreshSession() en el listener del éxito — se
// provee un AuthCubit mockeado (mismo lugar que en producción).
class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late MockAcceptInviteUseCase mockAcceptInvite;
  late MockResendVerificationUseCase mockResend;
  late MockAuthCubit mockAuthCubit;

  const tToken = 'invite-token-abc';
  const tEmail = 'invitado@test.com';

  setUp(() {
    mockAcceptInvite = MockAcceptInviteUseCase();
    mockResend = MockResendVerificationUseCase();
    mockAuthCubit = MockAuthCubit();
    when(() => mockAuthCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockAuthCubit.state).thenReturn(const AuthInitial());
    when(() => mockAuthCubit.close()).thenAnswer((_) async {});
    when(() => mockAuthCubit.refreshSession()).thenAnswer((_) async {});
  });

  AcceptInviteCubit buildCubit({
    String token = tToken,
    String email = tEmail,
  }) => AcceptInviteCubit(
    mockAcceptInvite,
    mockResend,
    token: token,
    email: email,
  );

  Widget buildApp(AcceptInviteCubit cubit) => BlocProvider<AuthCubit>.value(
    value: mockAuthCubit,
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AcceptInviteScreen(cubit: cubit),
    ),
  );

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  testWidgets('renderiza el form: heading con email, campos password y '
      'confirmación, checklist y el CTA deshabilitado', (tester) async {
    await tester.pumpWidget(buildApp(buildCubit()));

    expect(find.text('Definí tu contraseña'), findsOneWidget);
    expect(
      find.text('Te invitaron a unirte. Creá tu contraseña para $tEmail.'),
      findsOneWidget,
    );
    expect(field('Nueva contraseña'), findsOneWidget);
    expect(field('Confirmar contraseña'), findsOneWidget);
    expect(find.text('La contraseña debe tener:'), findsOneWidget);
    expect(find.text('Crear contraseña y entrar'), findsOneWidget);

    // Form inválido → el primario arranca deshabilitado.
    final button = tester.widget<QuesivoPrimaryButton>(
      find.byType(QuesivoPrimaryButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('el CTA se habilita con form válido y el submit llama al '
      'use case con token+password (auto-login vía repo)', (tester) async {
    const tUser = User(
      id: '1',
      email: tEmail,
      name: 'Invitado',
      token: 'token',
    );
    when(
      () => mockAcceptInvite(
        token: any(named: 'token'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Right(tUser));
    final cubit = buildCubit();
    await tester.pumpWidget(buildApp(cubit));

    await tester.enterText(field('Nueva contraseña'), 'Queso123');
    await tester.enterText(field('Confirmar contraseña'), 'Queso123');
    await tester.pump();

    final button = tester.widget<QuesivoPrimaryButton>(
      find.byType(QuesivoPrimaryButton),
    );
    expect(button.onPressed, isNotNull);

    // El CTA vive al fondo del scroll — visible antes del tap.
    await tester.ensureVisible(find.byType(QuesivoPrimaryButton));
    await tester.pump();
    await tester.tap(find.byType(QuesivoPrimaryButton));
    await tester.pump();
    await tester.pump();

    verify(
      () => mockAcceptInvite(token: tToken, password: 'Queso123'),
    ).called(1);
    // Éxito → el listener pidió el refresh de sesión (AuthGuard → /home).
    verify(() => mockAuthCubit.refreshSession()).called(1);
  });

  testWidgets('deep link sin token muestra la vista de link inválido '
      'con "Pedir link nuevo"', (tester) async {
    await tester.pumpWidget(buildApp(buildCubit(token: '')));

    expect(find.text('Este enlace ya no es válido'), findsOneWidget);
    expect(
      find.text(
        'El enlace de invitación expiró o ya fue usado. Pedí uno nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pedir link nuevo'), findsOneWidget);
    // El form de password no se renderiza.
    expect(field('Nueva contraseña'), findsNothing);
  });

  testWidgets('"Pedir link nuevo" llama al resend y muestra la card de '
      'confirmación', (tester) async {
    when(() => mockResend(tEmail)).thenAnswer((_) async => const Right(null));
    await tester.pumpWidget(buildApp(buildCubit(token: '')));

    await tester.tap(find.text('Pedir link nuevo'));
    await tester.pump();
    await tester.pump();

    verify(() => mockResend(tEmail)).called(1);
    expect(find.text('Correo reenviado'), findsOneWidget);
    expect(
      find.text('Te enviamos un enlace nuevo. Revisá tu bandeja de entrada.'),
      findsOneWidget,
    );
  });

  testWidgets('link inválido sin email en el query no ofrece el reenvío', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(buildCubit(token: '', email: '')));

    expect(find.text('Este enlace ya no es válido'), findsOneWidget);
    expect(find.text('Pedir link nuevo'), findsNothing);
    // La salida manual a login sigue visible.
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
