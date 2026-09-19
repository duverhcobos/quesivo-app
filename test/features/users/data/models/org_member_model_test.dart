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
}
