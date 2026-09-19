import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/presentation/screens/users_screen.dart';
import 'package:quesivo/features/users/presentation/widgets/org_member_card.dart';
import 'package:quesivo/features/users/presentation/widgets/role_filter_chips.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  Widget buildApp() => const MaterialApp(
    locale: Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: UsersScreen(),
  );

  // El viewport por defecto de flutter_test (800x600) solo alcanza para
  // renderizar ~3 cards del ListView.separated (lazy build). Se agranda
  // el alto del surface para que las 15 cards de la página inicial
  // entren en pantalla y `findsNWidgets` las cuente todas.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('muestra título, tooltip de acción y stats sobre el total (54)', (
    tester,
  ) async {
    // §41: sin back arrow ni context.pop() — la pantalla ya no necesita
    // un GoRouter vivo; MaterialApp plano alcanza.
    await tester.pumpWidget(buildApp());

    expect(find.text('Usuarios'), findsOneWidget);
    // Acción icon-only: círculo amarillo con person_add (§41) — el label
    // vive en el tooltip, no como texto visible.
    expect(find.byTooltip('Nuevo usuario'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    // §43: dataset sintético de 54 miembros — stats siempre sobre el
    // total, no sobre lo visible/filtrado.
    expect(find.text('54 miembros'), findsOneWidget);
    expect(find.text('46 activos'), findsOneWidget);
  });

  testWidgets('la carga inicial muestra 15 cards, no las 54 del dataset', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    expect(find.byType(OrgMemberCard), findsNWidgets(15));
  });

  testWidgets('escribir en el buscador filtra por nombre/correo', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField), 'ana.perez');
    await tester.pump();

    expect(find.byType(OrgMemberCard), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
  });

  testWidgets('búsqueda sin coincidencias muestra el estado "Sin resultados"', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField), 'zzzzz-no-existe');
    await tester.pump();

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.byType(OrgMemberCard), findsNothing);
  });

  testWidgets('tocar un chip de rol filtra el listado por ese rol', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    expect(find.byType(OrgMemberCard), findsNWidgets(15));

    // "Productor" también aparece en el MemberRoleChip de cada card —
    // se acota la búsqueda al chip de filtro (dentro de RoleFilterChips).
    // El chip está al final de la fila horizontal scrolleable: hay que
    // asegurarlo visible antes de tocarlo.
    final producerFilterChip = find.descendant(
      of: find.byType(RoleFilterChips),
      matching: find.text('Productor'),
    );
    await tester.ensureVisible(producerFilterChip);
    await tester.pumpAndSettle();
    await tester.tap(producerFilterChip);
    await tester.pump();

    // 54 miembros / 4 roles asignados round-robin (índice % 4 == 3):
    // 13 miembros son Productor, menos que la página inicial de 15 —
    // la cuenta visible baja.
    expect(find.byType(OrgMemberCard), findsNWidgets(13));
  });
}
