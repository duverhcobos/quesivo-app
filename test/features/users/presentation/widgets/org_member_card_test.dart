import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/core/widgets/quesivo_loader.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';
import 'package:quesivo/features/users/presentation/widgets/org_member_card.dart';
import 'package:quesivo/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  const member = OrgMember(
    id: '1',
    email: 'ana@mail.com',
    name: 'Ana Pérez',
    role: UserRole.admin,
    status: MemberStatus.active,
    organizationId: 'org',
  );

  testWidgets('renderiza nombre, email y chips de rol/estado', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OrgMemberCard(
          member: member,
          onStatusToggle: (_) {},
          onPasswordReset: (_) {},
        ),
      ),
    );
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@mail.com'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
  });

  testWidgets('miembro suspendido muestra chip Suspendido', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OrgMemberCard(
          member: const OrgMember(
            id: '2',
            email: 'p@mail.com',
            name: 'Pedro',
            role: UserRole.collector,
            status: MemberStatus.suspended,
            organizationId: 'org',
          ),
          onStatusToggle: (_) {},
          onPasswordReset: (_) {},
        ),
      ),
    );
    expect(find.text('Suspendido'), findsOneWidget);
    expect(find.text('Recolector'), findsOneWidget);
  });

  testWidgets('miembro común muestra el menú ⋮', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OrgMemberCard(
          member: member,
          onStatusToggle: (_) {},
          onPasswordReset: (_) {},
        ),
      ),
    );
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets(
    'isSelf: la card propia no muestra ⋮ (§52 — SELF_SUSPENSION garantizado)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrgMemberCard(
            member: member,
            isSelf: true,
            onStatusToggle: (_) {},
            onPasswordReset: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.more_vert), findsNothing);
    },
  );

  testWidgets(
    'isBusy: el ⋮ cede al QuesivoLoader mientras el PATCH vuela (§52)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrgMemberCard(
            member: member,
            isBusy: true,
            onStatusToggle: (_) {},
            onPasswordReset: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.more_vert), findsNothing);
      // El loader de marca ocupa su lugar — segunda acción imposible.
      expect(find.byType(QuesivoLoader), findsOneWidget);
    },
  );

  testWidgets('dueño no muestra ⋮ (regla OWNER_* del backend)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OrgMemberCard(
          member: const OrgMember(
            id: '9',
            email: 'dueno@mail.com',
            name: 'Dueño',
            role: UserRole.admin,
            status: MemberStatus.active,
            organizationId: 'org',
            isOwner: true,
          ),
          onStatusToggle: (_) {},
          onPasswordReset: (_) {},
        ),
      ),
    );
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
