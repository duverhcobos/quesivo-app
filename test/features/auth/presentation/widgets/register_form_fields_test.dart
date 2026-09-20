import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/features/auth/presentation/cubit/register_cubit.dart';
import 'package:quesivo/features/auth/presentation/cubit/register_state.dart';
import 'package:quesivo/features/auth/presentation/widgets/register_form_fields.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockRegisterCubit extends MockCubit<RegisterState>
    implements RegisterCubit {}

void main() {
  // Los casos solo verifican el formatter de charset (§47 — alcance
  // extendido): no hace falta emitir estados, basta el RegisterState
  // inicial y un stream vacío para que los BlocBuilder pinten.
  late MockRegisterCubit mockCubit;

  setUp(() {
    mockCubit = MockRegisterCubit();
    when(
      () => mockCubit.stream,
    ).thenAnswer((_) => const Stream<RegisterState>.empty());
    when(() => mockCubit.state).thenReturn(const RegisterState());
    when(() => mockCubit.close()).thenAnswer((_) async {});
  });

  Widget buildApp() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<RegisterCubit>.value(
        value: mockCubit,
        child: const SingleChildScrollView(child: RegisterFormFields()),
      ),
    ),
  );

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  testWidgets('el formatter del nombre bloquea dígitos al tipear', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    // El charset de FullName solo deja pasar letras (con tildes/ñ/ü),
    // espacio, apóstrofe y guion — '123!!' ni entra.
    await tester.enterText(field('Nombre completo'), 'Juan123!!');
    await tester.pump();

    expect(find.text('Juan'), findsOneWidget);
    verify(() => mockCubit.fullNameChanged('Juan')).called(1);
  });

  testWidgets('el formatter del email bloquea espacios al tipear', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(field('Correo electrónico'), 'a b@c');
    await tester.pump();

    expect(find.text('ab@c'), findsOneWidget);
    verify(() => mockCubit.emailChanged('ab@c')).called(1);
  });

  testWidgets('el formatter de contraseña bloquea símbolos al tipear', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    // RegisterPassword solo admite lo que el requisito pide (a-zA-Z0-9)
    // — '!@#' queda filtrado a nivel tecla. El campo está obscure, así
    // que el valor se verifica en la llamada al cubit.
    await tester.enterText(field('Contraseña'), 'Abc1!@#x');
    await tester.pump();

    verify(() => mockCubit.passwordChanged('Abc1x')).called(1);
  });
}
