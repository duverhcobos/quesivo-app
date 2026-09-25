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
    invitePending: false,
    organizationId: 'org',
  );

  testWidgets('renderiza nombre, email y chips de rol/estado', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OrgMemberCard(
          member: member,
          onStatusToggle: (_) {},
          onPasswordReset: (_) {},
          onRoleChange: (_) {},
          onResendInvite: () {},
          onCancelInvite: () {},
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
            invitePending: false,
            organizationId: 'org',
          ),
          onStatusToggle: (_) {},
          onPasswordReset: (_) {},
          onRoleChange: (_) {},
          onResendInvite: () {},
          onCancelInvite: () {},
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
          onRoleChange: (_) {},
          onResendInvite: () {},
          onCancelInvite: () {},
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
            onRoleChange: (_) {},
            onResendInvite: () {},
            onCancelInvite: () {},
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
            onRoleChange: (_) {},
            onResendInvite: () {},
            onCancelInvite: () {},
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
            invitePending: false,
            organizationId: 'org',
            isOwner: true,
          ),
          onStatusToggle: (_) {},
          onPasswordReset: (_) {},
          onRoleChange: (_) {},
          onResendInvite: () {},
          onCancelInvite: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  group('Email-C (§68) — invitación pendiente', () {
    const pendingMember = OrgMember(
      id: '5',
      email: 'invitado@mail.com',
      name: 'Invitado',
      role: UserRole.operator,
      status: MemberStatus.active,
      invitePending: true,
      organizationId: 'org',
    );

    testWidgets('cuenta pendingVerification muestra el badge ámbar '
        '"Invitación pendiente"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrgMemberCard(
            member: pendingMember,
            onStatusToggle: (_) {},
            onPasswordReset: (_) {},
            onRoleChange: (_) {},
            onResendInvite: () {},
            onCancelInvite: () {},
          ),
        ),
      );
      expect(find.text('Invitación pendiente'), findsOneWidget);
    });

    testWidgets('cuenta activa NO muestra el badge de invitación pendiente', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OrgMemberCard(
            member: member,
            onStatusToggle: (_) {},
            onPasswordReset: (_) {},
            onRoleChange: (_) {},
            onResendInvite: () {},
            onCancelInvite: () {},
          ),
        ),
      );
      expect(find.text('Invitación pendiente'), findsNothing);
    });

    testWidgets(
      'el ⋮ del pendiente ofrece "Reenviar invitación" y el tap dispara '
      'onResendInvite',
      (tester) async {
        var resent = false;
        await tester.pumpWidget(
          _wrap(
            OrgMemberCard(
              member: pendingMember,
              onStatusToggle: (_) {},
              onPasswordReset: (_) {},
              onRoleChange: (_) {},
              onResendInvite: () => resent = true,
              onCancelInvite: () {},
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Reenviar invitación'), findsOneWidget);
        await tester.tap(find.text('Reenviar invitación'));
        await tester.pumpAndSettle();
        expect(resent, isTrue);
      },
    );

    testWidgets('el ⋮ de un activo NO ofrece "Reenviar invitación"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OrgMemberCard(
            member: member,
            onStatusToggle: (_) {},
            onPasswordReset: (_) {},
            onRoleChange: (_) {},
            onResendInvite: () {},
            onCancelInvite: () {},
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Reenviar invitación'), findsNothing);
    });
  });

  group('§69 — backend 072: membresía invited + cancelar invitación', () {
    const invitedMember = OrgMember(
      id: '7',
      email: 'link@mail.com',
      name: 'Link Invitado',
      role: UserRole.operator,
      status: MemberStatus.invited,
      invitePending: true,
      organizationId: 'org',
    );

    testWidgets('membresía invited muestra chip "Invitado" y NO el badge ámbar '
        '(un solo marcador por fila)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrgMemberCard(
            member: invitedMember,
            onStatusToggle: (_) {},
            onPasswordReset: (_) {},
            onRoleChange: (_) {},
            onResendInvite: () {},
            onCancelInvite: () {},
          ),
        ),
      );
      expect(find.text('Invitado'), findsOneWidget);
      expect(find.text('Invitación pendiente'), findsNothing);
    });

    testWidgets(
      'el ⋮ del invitePending solo ofrece reenviar/cancelar (suspend, rol '
      'y password quedan ocultos — errores garantizados en backend)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            OrgMemberCard(
              member: invitedMember,
              onStatusToggle: (_) {},
              onPasswordReset: (_) {},
              onRoleChange: (_) {},
              onResendInvite: () {},
              onCancelInvite: () {},
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Reenviar invitación'), findsOneWidget);
        expect(find.text('Cancelar invitación'), findsOneWidget);
        expect(find.text('Suspender usuario'), findsNothing);
        expect(find.text('Cambiar rol'), findsNothing);
        expect(find.text('Restablecer contraseña'), findsNothing);
      },
    );

    testWidgets(
      '"Cancelar invitación" pide confirmación: cancelar el diálogo NO '
      'notifica, confirmar dispara onCancelInvite',
      (tester) async {
        var cancelled = false;
        await tester.pumpWidget(
          _wrap(
            OrgMemberCard(
              member: invitedMember,
              onStatusToggle: (_) {},
              onPasswordReset: (_) {},
              onRoleChange: (_) {},
              onResendInvite: () {},
              onCancelInvite: () => cancelled = true,
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar invitación'));
        await tester.pumpAndSettle();

        // Diálogo de confirmación visible; el callback aún no se disparó.
        expect(find.text('¿Cancelar la invitación?'), findsOneWidget);
        expect(cancelled, isFalse);

        // El botón "Cancelar" del diálogo cierra sin notificar.
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(cancelled, isFalse);

        // Reabrir y confirmar → onCancelInvite se dispara.
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar invitación'));
        await tester.pumpAndSettle();
        // Hay dos textos iguales: el ítem del menú quedó atrás — el del
        // diálogo es el TextButton. Se toca el último en pantalla.
        await tester.tap(find.text('Cancelar invitación').last);
        await tester.pumpAndSettle();
        expect(cancelled, isTrue);
      },
    );
  });
}
