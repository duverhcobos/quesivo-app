import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/users/data/models/users_page_model.dart';
import 'package:quesivo/features/users/domain/entities/org_member.dart';
import 'package:quesivo/features/users/domain/entities/user_role.dart';

void main() {
  group('UsersPageModel.fromJson (GET /auth/users — doc 008)', () {
    test('parsea {items, meta} del contrato real', () {
      final model = UsersPageModel.fromJson({
        'items': [
          {
            'id': 'b2c3-uuid',
            'email': 'pedro@mail.com',
            'name': 'Pedro Ruiz',
            'role': 'OPERATOR',
            'status': 'active',
            'lastLoginAt': '2026-03-19T14:00:00.000Z',
            'isOwner': false,
          },
          {
            'id': 'a1b2-uuid',
            'email': 'admin@mail.com',
            'name': 'Admin Queso',
            'role': 'ADMIN',
            'status': 'active',
            'lastLoginAt': null,
            'isOwner': true,
          },
        ],
        'meta': {'page': 1, 'limit': 15, 'total': 34, 'totalPages': 3},
      });

      expect(model.items, hasLength(2));
      expect(model.page, 1);
      expect(model.limit, 15);
      expect(model.total, 34);
      expect(model.totalPages, 3);
      expect(model.hasMore, isTrue); // 1 < 3

      final first = model.items.first;
      expect(first.id, 'b2c3-uuid');
      expect(first.role, UserRole.operator);
      expect(first.status, MemberStatus.active);
      // Los ítems del GET no traen organizationId/linked → defaults.
      expect(first.organizationId, '');
      expect(first.linked, isFalse);
      expect(first.isOwner, isFalse);
      expect(model.items[1].isOwner, isTrue);
    });

    test('hasMore es false en la última página', () {
      final model = UsersPageModel.fromJson({
        'items': const [],
        'meta': {'page': 3, 'limit': 15, 'total': 34, 'totalPages': 3},
      });

      expect(model.hasMore, isFalse);
    });

    test('name null del profile cae a string vacío', () {
      final model = UsersPageModel.fromJson({
        'items': [
          {
            'id': 'x1',
            'email': 'sin@nombre.com',
            'name': null,
            'role': 'COLLECTOR',
            'status': 'suspended',
            'isOwner': false,
          },
        ],
        'meta': {'page': 1, 'limit': 15, 'total': 1, 'totalPages': 1},
      });

      expect(model.items.single.name, '');
      expect(model.items.single.role, UserRole.collector);
      expect(model.items.single.status, MemberStatus.suspended);
    });

    test('meta ausente/incompleto cae a defaults defensivos', () {
      final model = UsersPageModel.fromJson({'items': const []});

      expect(model.items, isEmpty);
      expect(model.page, 1);
      expect(model.totalPages, 1);
      expect(model.hasMore, isFalse);
    });
  });
}
