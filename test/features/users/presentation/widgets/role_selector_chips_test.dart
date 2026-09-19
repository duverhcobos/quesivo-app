import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/theme/app_colors.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/widgets/role_selector_chips.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  Widget buildApp({
    required UserRole? selected,
    required ValueChanged<UserRole> onChanged,
  }) => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RoleSelectorChips(selected: selected, onChanged: onChanged),
    ),
  );

  testWidgets('renderiza los 4 roles del catálogo (sin "Todos")', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(selected: null, onChanged: (_) {}));

    expect(find.text('Todos'), findsNothing);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Operario'), findsOneWidget);
    expect(find.text('Recolector'), findsOneWidget);
    expect(find.text('Productor'), findsOneWidget);
  });

  testWidgets('tocar un chip invoca onChanged con ese rol', (tester) async {
    UserRole? selectedRole;
    var wasCalled = false;

    await tester.pumpWidget(
      buildApp(
        selected: null,
        onChanged: (role) {
          wasCalled = true;
          selectedRole = role;
        },
      ),
    );

    await tester.tap(find.text('Productor'));
    await tester.pump();

    expect(wasCalled, isTrue);
    expect(selectedRole, UserRole.producer);
  });

  testWidgets('el chip seleccionado pinta navy', (tester) async {
    await tester.pumpWidget(
      buildApp(selected: UserRole.operator, onChanged: (_) {}),
    );

    // El Material más cercano al label del chip es el del propio chip.
    final chipMaterial = tester.widget<Material>(
      find
          .ancestor(of: find.text('Operario'), matching: find.byType(Material))
          .first,
    );
    expect(chipMaterial.color, AppColors.quesivoNavy);
  });
}
