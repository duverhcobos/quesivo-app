import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/widgets/role_filter_chips.dart';
import 'package:quesivo/l10n/app_localizations.dart';

void main() {
  Widget buildApp({
    required UserRole? selected,
    required ValueChanged<UserRole?> onChanged,
  }) => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RoleFilterChips(selected: selected, onChanged: onChanged),
    ),
  );

  testWidgets('renderiza "Todos" + los 4 roles del catálogo', (tester) async {
    await tester.pumpWidget(buildApp(selected: null, onChanged: (_) {}));

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Operario'), findsOneWidget);
    expect(find.text('Recolector'), findsOneWidget);
    expect(find.text('Productor'), findsOneWidget);
  });

  testWidgets('tocar un chip invoca onChanged con el rol correspondiente', (
    tester,
  ) async {
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

    await tester.tap(find.text('Recolector'));
    await tester.pump();

    expect(wasCalled, isTrue);
    expect(selectedRole, UserRole.collector);
  });
}
