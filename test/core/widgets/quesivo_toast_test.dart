import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/theme/app_colors.dart';
import 'package:quesivo/core/widgets/quesivo_toast.dart';

void main() {
  Widget buildApp() => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => QuesivoToast.success(
              context,
              message: 'Usuario creado con éxito',
            ),
            child: const Text('toast'),
          ),
        ),
      ),
    ),
  );

  testWidgets('muestra el mensaje con el icono y auto-dismiss ~2.6s', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('toast'));
    await tester.pump();
    // Termina la entrada (~280ms).
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Usuario creado con éxito'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    // Vence el hold + la salida — el entry se retira del overlay.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Usuario creado con éxito'), findsNothing);
  });

  testWidgets('warning usa icono y color semánticos propios', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => QuesivoToast.warning(
                context,
                message: 'Membresía suspendida',
              ),
              child: const Text('warn'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('warn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Membresía suspendida'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    // Texto navy — el ámbar pide contraste oscuro.
    final text = tester.widget<Text>(find.text('Membresía suspendida'));
    expect(text.style?.color, AppColors.quesivoNavy);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('un toast nuevo reemplaza al anterior — nunca se apilan', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () =>
                      QuesivoToast.error(context, message: 'error uno'),
                  child: const Text('t1'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      QuesivoToast.error(context, message: 'error dos'),
                  child: const Text('t2'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('t1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('error uno'), findsOneWidget);

    // Segundo toast dentro del hold: el primero se retira — solo queda
    // el nuevo (antes se apilaban dos pills encimadas).
    await tester.tap(find.text('t2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('error uno'), findsNothing);
    expect(find.text('error dos'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
