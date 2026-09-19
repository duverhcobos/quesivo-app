import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/presentation/screens/users_screen.dart';
import 'package:quesivo/features/users/presentation/widgets/new_user_sheet.dart';
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

  testWidgets('el botón de acción abre el sheet de creación', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Crear usuario'), findsOneWidget);
  });

  testWidgets('crear desde el sheet agrega el miembro al tope del listado', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Usuario Nuevo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'nuevo@mail.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña temporal'),
      'Temporal1',
    );
    // "Operario" también aparece en RoleFilterChips y en los
    // MemberRoleChip de las cards — se acota al árbol del sheet.
    await tester.tap(
      find.descendant(
        of: find.byType(NewUserSheet),
        matching: find.text('Operario'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Crear usuario'));
    await tester.pumpAndSettle();

    // Sheet cerrado + snackbar de feedback (§44).
    expect(find.text('Crear usuario'), findsNothing);
    expect(
      find.text('Usuario creado — compartile la contraseña temporal'),
      findsOneWidget,
    );
    // El insert al tope sube el total y la primera card es la del nuevo.
    expect(find.text('55 miembros'), findsOneWidget);
    expect(
      tester
          .widget<OrgMemberCard>(find.byType(OrgMemberCard).first)
          .member
          .name,
      'Usuario Nuevo',
    );
  });

  testWidgets('suspender desde el menú cambia el chip de la card', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp());

    // La primera card del dataset (Ana Pérez, índice 0) ya viene
    // suspendida — se usa la segunda (Ana Gómez, activa), la primera
    // cuyo ⋮ ofrece "Suspender usuario".
    final card = find.byType(OrgMemberCard).at(1);
    final menuButton = find.descendant(
      of: card,
      matching: find.byIcon(Icons.more_vert),
    );
    await tester.ensureVisible(menuButton);
    await tester.pumpAndSettle();
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Ítem del menú → abre la confirmación (AlertDialog §45).
    await tester.tap(find.text('Suspender usuario'));
    await tester.pumpAndSettle();
    expect(find.text('¿Suspender a Ana Gómez?'), findsOneWidget);

    // CTA del diálogo → confirma, flippea el status en el dataset local.
    await tester.tap(find.text('Suspender usuario'));
    await tester.pumpAndSettle();

    expect(find.text('Membresía suspendida'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Suspendido')),
      findsOneWidget,
    );
    expect(
      tester.widget<OrgMemberCard>(card).member.status,
      MemberStatus.suspended,
    );
  });
}
