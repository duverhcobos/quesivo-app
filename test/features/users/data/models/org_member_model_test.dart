import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/data/models/org_member_model.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';

void main() {
  group('OrgMemberModel.fromJson — contrato POST /auth/users (doc 007)', () {
    test('parsea el shape completo del 201', () {
      final model = OrgMemberModel.fromJson({
        'id': 'uuid-123',
        'email': 'maria@quesera.com',
        'name': 'María Quesera',
        'role': 'OPERATOR',
        'status': 'active',
        'organizationId': 'org-9',
        'linked': true,
      });

      expect(model.id, 'uuid-123');
      expect(model.email, 'maria@quesera.com');
      expect(model.name, 'María Quesera');
      expect(model.role, UserRole.operator);
      expect(model.status, MemberStatus.active);
      expect(model.organizationId, 'org-9');
      expect(model.linked, isTrue);
    });

    test('linked ausente → false (miembro creado de cero)', () {
      final model = OrgMemberModel.fromJson({
        'id': 'uuid-1',
        'email': 'a@b.com',
        'name': 'A',
        'role': 'ADMIN',
        'status': 'suspended',
        'organizationId': 'org-1',
      });

      expect(model.linked, isFalse);
      expect(model.role, UserRole.admin);
      expect(model.status, MemberStatus.suspended);
    });

    test("status 'invited' → MemberStatus.invited (§69 — backend 072)", () {
      final model = OrgMemberModel.fromJson({
        'id': 'uuid-7',
        'email': 'link@mail.com',
        'name': 'Link',
        'role': 'OPERATOR',
        'status': 'invited', // membresía de vinculación sin aceptar
        'organizationId': 'org-1',
        'invitePending': true,
      });

      expect(model.status, MemberStatus.invited);
      expect(model.invitePending, true);
    });

    test('role/status desconocidos caen a operator/active (defensivo)', () {
      final model = OrgMemberModel.fromJson({
        'id': 'uuid-1',
        'email': 'a@b.com',
        'name': 'A',
        'role': 'SUPERUSER',
        'status': 'banned',
        'organizationId': 'org-1',
      });

      expect(model.role, UserRole.operator);
      expect(model.status, MemberStatus.active);
    });
  });

  group('OrgMemberModel.fromJson — invitePending (Email-C, backend 071)', () {
    test('invitePending true → habilita badge + reenvío', () {
      final model = OrgMemberModel.fromJson({
        'id': 'uuid-2',
        'email': 'invitado@mail.com',
        'name': 'Invitado',
        'role': 'OPERATOR',
        'status': 'active', // membresía activa
        'userStatus': 'pending_verification', // cuenta global pendiente
        'invitePending': true, // derivado del backend (pending + sin pass)
      });

      // Los dos estados son independientes: membresía activa, cuenta
      // global pendiente de aceptar el correo.
      expect(model.status, MemberStatus.active);
      expect(model.invitePending, true);
    });

    test('invitePending ausente (backend viejo) → false '
        '(fallback — sin badge ni reenvío)', () {
      final model = OrgMemberModel.fromJson({
        'id': 'uuid-1',
        'email': 'a@b.com',
        'name': 'A',
        'role': 'ADMIN',
        'status': 'suspended',
      });

      expect(model.status, MemberStatus.suspended);
      expect(model.invitePending, false);
    });

    test('pendiente CON password (auto-registrado vinculado por link) → '
        'invitePending false: userStatus pendiente no basta', () {
      final model = OrgMemberModel.fromJson({
        'id': 'uuid-5',
        'email': 'registrado@mail.com',
        'name': 'Auto-registrado',
        'role': 'OPERATOR',
        'status': 'active',
        'userStatus': 'pending_verification', // pendiente pero CON password
        'invitePending': false, // el backend deriva: tiene password
      });

      expect(model.invitePending, false);
    });
  });

  group('OrgMemberModel.fromCreatedJson — contrato create/link '
      '(doc 007 — Email-C)', () {
    test('invite mode: status pending_verification + invitePending true '
        '→ membresía nace active', () {
      final model = OrgMemberModel.fromCreatedJson({
        'id': 'uuid-3',
        'email': 'invitado@mail.com',
        'name': 'Invitado',
        'role': 'OPERATOR',
        'status': 'pending_verification', // global — invite mode
        'organizationId': 'org-9',
        'linked': false,
        'invitePending': true,
      });

      expect(model.status, MemberStatus.active); // membresía nueva
      expect(model.invitePending, true);
      expect(model.organizationId, 'org-9');
    });

    test('create manual (status active del 201) → ambos estados active', () {
      final model = OrgMemberModel.fromCreatedJson({
        'id': 'uuid-4',
        'email': 'operario@mail.com',
        'name': 'Operario',
        'role': 'OPERATOR',
        'status': 'active',
        'organizationId': 'org-9',
        'invitePending': false,
      });

      expect(model.status, MemberStatus.active);
      expect(model.invitePending, false);
    });
  });
}
