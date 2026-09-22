import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:quesivo/core/widgets/quesivo_loader.dart';
import 'package:quesivo/core/widgets/quesivo_primary_button.dart';
import 'package:quesivo/core/widgets/quesivo_text_field.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/domain/failures/users_failure.dart';
import 'package:quesivo/features/users/presentation/cubit/reset_password_cubit.dart';
import 'package:quesivo/features/users/presentation/cubit/reset_password_state.dart';
import 'package:quesivo/features/users/presentation/widgets/reset_password_sheet.dart';
import 'package:quesivo/l10n/app_localizations.dart';

class MockResetPasswordCubit extends MockCubit<ResetPasswordState>
    implements ResetPasswordCubit {}

void main() {
  // Mismo harness que link_user_sheet_test: un botón que dispara
  // `ResetPasswordSheet.show(context, member, cubit: mock)` (seam de
  // tests) y captura el Future<OrgMember?> que el sheet resuelve al
  // hacer pop (el `OrgMember` del 200 tras la pausa de éxito, o null
  // al cancelar).
  late MockResetPasswordCubit mockCubit;
  late StreamController<ResetPasswordState> stateController;
  late Future<OrgMember?> result;

  const member = OrgMember(
    id: '1',
    email: 'ana@mail.com',
    name: 'Ana Pérez',
    role: UserRole.admin,
    status: MemberStatus.active,
    organizationId: 'org',
  );

  const tResetMember = OrgMember(
    id: '1',
    email: 'ana@mail.com',
    name: 'Ana Pérez',
    role: UserRole.admin,
    status: MemberStatus.active,
    organizationId: 'org',
  );

  setUp(() {
    mockCubit = MockResetPasswordCubit();
    // Broadcast: el BlocConsumer se suscribe dos veces a bloc.stream
    // (listener + builder) — un controller normal crashea con
    // "Stream has already been listened to".
    stateController = StreamController<ResetPasswordState>.broadcast();
    when(() => mockCubit.stream).thenAnswer((_) => stateController.stream);
    when(() => mockCubit.state).thenReturn(const ResetPasswordState());
    when(() => mockCubit.close()).thenAnswer((_) async {});
    when(
      () => mockCubit.submit(
        userId: any(named: 'userId'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockCubit.resetStatus()).thenReturn(null);
  });

  tearDown(() {
    stateController.close();
  });

  Widget buildApp() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => result = ResetPasswordSheet.show(
              context,
              member,
              cubit: mockCubit,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  // Superficie alta para que el sheet completo quede visible (mismo
  // criterio que new_user_sheet_test).
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  testWidgets('renderiza título, hint con el nombre y el campo', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    expect(find.text('Restablecer contraseña'), findsOneWidget);
    expect(
      find.text(
        'Nueva contraseña temporal para Ana Pérez — ingresará con ella.',
      ),
      findsOneWidget,
    );
    expect(field('Nueva contraseña'), findsOneWidget);
    expect(find.text('Actualizar contraseña'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets(
    'submit con password débil muestra el error y no llama al cubit',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);

      await tester.enterText(field('Nueva contraseña'), 'debil');
      await tester.tap(find.text('Actualizar contraseña'));
      await tester.pump();

      expect(
        find.text(
          'Mínimo 8 caracteres, una mayúscula, una minúscula y un número',
        ),
        findsOneWidget,
      );
      // No hubo submit ni pop — el sheet sigue abierto.
      expect(find.text('Actualizar contraseña'), findsOneWidget);
      verifyNever(
        () => mockCubit.submit(
          userId: any(named: 'userId'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  testWidgets('submit válido llama al cubit con el userId y password', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Nueva contraseña'), 'Temporal1');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pump();

    verify(
      () => mockCubit.submit(userId: '1', password: 'Temporal1'),
    ).called(1);
  });

  testWidgets(
    'estado inProgress muestra spinner y deshabilita campo y acciones',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);

      when(() => mockCubit.state).thenReturn(
        const ResetPasswordState(status: FormzSubmissionStatus.inProgress),
      );
      stateController.add(
        const ResetPasswordState(status: FormzSubmissionStatus.inProgress),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(QuesivoLoader), findsWidgets);
      expect(
        tester
            .widget<QuesivoPrimaryButton>(find.byType(QuesivoPrimaryButton))
            .isLoading,
        isTrue,
      );
      expect(
        tester.widget<QuesivoTextField>(find.byType(QuesivoTextField)).enabled,
        isFalse,
      );
      final cancelButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Cancelar'),
      );
      expect(cancelButton.onPressed, isNull);
    },
  );

  testWidgets(
    'estado success muestra check ~500ms y luego popea el OrgMember real',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await openSheet(tester);

      await tester.enterText(field('Nueva contraseña'), 'Temporal1');
      await tester.tap(find.text('Actualizar contraseña'));
      await tester.pump();

      when(() => mockCubit.state).thenReturn(
        const ResetPasswordState(
          status: FormzSubmissionStatus.success,
          resetMember: tResetMember,
        ),
      );
      stateController.add(
        const ResetPasswordState(
          status: FormzSubmissionStatus.success,
          resetMember: tResetMember,
        ),
      );
      await tester.pump();
      await tester.pump();

      // Durante la pausa: sheet abierto con el check reemplazando el
      // label del botón — el pop llega recién tras el delay.
      expect(find.text('Restablecer contraseña'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(await result, tResetMember);
      expect(find.text('Restablecer contraseña'), findsNothing);
    },
  );

  testWidgets('estado failure muestra toast y el sheet queda abierto', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.enterText(field('Nueva contraseña'), 'Temporal1');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pump();

    when(() => mockCubit.state).thenReturn(
      const ResetPasswordState(
        status: FormzSubmissionStatus.failure,
        failure: OwnerPasswordResetFailure(),
      ),
    );
    stateController.add(
      const ResetPasswordState(
        status: FormzSubmissionStatus.failure,
        failure: OwnerPasswordResetFailure(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('No se puede restablecer la contraseña del dueño'),
      findsOneWidget,
    );
    // Sin pop — el sheet sigue abierto para reintentar.
    expect(find.text('Restablecer contraseña'), findsOneWidget);

    // Drena el auto-dismiss del toast (~2.6s) — sin el pump el Timer
    // queda pendiente al teardown ("A Timer is still pending").
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('Cancelar cierra el sheet sin resultado', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
  });
}
