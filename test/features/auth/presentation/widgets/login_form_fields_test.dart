import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/auth/presentation/cubit/login_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/login_state.dart';
import 'package:quesivo/features/auth/presentation/widgets/login_form_fields.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockLoginCubit extends MockCubit<LoginState> implements LoginCubit {}

void main() {
  // Formatters de charset de email y password (§47 — alcance
  // extendido + feedback: el password de login también bloquea
  // símbolos, todas las contraseñas del sistema nacen alfanuméricas).
  late MockLoginCubit mockCubit;

  setUp(() {
    mockCubit = MockLoginCubit();
    when(
      () => mockCubit.stream,
    ).thenAnswer((_) => const Stream<LoginState>.empty());
    when(() => mockCubit.state).thenReturn(const LoginState());
    when(() => mockCubit.close()).thenAnswer((_) async {});
  });

  Widget buildApp() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<LoginCubit>.value(
        value: mockCubit,
        child: const SingleChildScrollView(child: LoginFormFields()),
      ),
    ),
  );

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  testWidgets('el formatter del email bloquea espacios al tipear', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(field('Correo electrónico'), 'a b@c');
    await tester.pump();

    expect(find.text('ab@c'), findsOneWidget);
    verify(() => mockCubit.emailChanged('ab@c')).called(1);
  });

  testWidgets('el formatter del password bloquea símbolos al tipear', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(field('Contraseña'), 'Abc1!@#x');
    await tester.pump();

    // El texto obscure no se renderiza como Text — el verify prueba
    // que el formatter filtró antes del onChanged.
    verify(() => mockCubit.passwordChanged('Abc1x')).called(1);
  });
}
