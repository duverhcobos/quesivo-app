import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/auth/data/models/user_model.dart';
import 'package:quesivo/features/auth/domain/entities/organization_summary.dart';

void main() {
  group('UserModel.fromJson — organizations (§55)', () {
    test('parsea organizations[] del payload de GET /auth/me', () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'ana@test.com',
        'name': 'Ana',
        'organizations': [
          {'id': 'org-1', 'name': 'Quesera Norte', 'role': 'ADMIN'},
          {'id': 'org-2', 'name': 'Quesera Sur', 'role': 'OPERATOR'},
        ],
      });

      expect(model.organizations, [
        const OrganizationSummary(
          id: 'org-1',
          name: 'Quesera Norte',
          role: 'ADMIN',
        ),
        const OrganizationSummary(
          id: 'org-2',
          name: 'Quesera Sur',
          role: 'OPERATOR',
        ),
      ]);
    });

    test('organizations ausente (login/register personal) → lista vacía', () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'ana@test.com',
        'name': 'Ana',
      });

      expect(model.organizations, isEmpty);
    });

    test('organizations null → lista vacía', () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'ana@test.com',
        'name': 'Ana',
        'organizations': null,
      });

      expect(model.organizations, isEmpty);
    });

    test('toJson serializa organizations para el cache del perfil', () {
      const model = UserModel(
        id: 'u1',
        email: 'ana@test.com',
        name: 'Ana',
        organizations: [
          OrganizationSummary(
            id: 'org-1',
            name: 'Quesera Norte',
            role: 'ADMIN',
          ),
        ],
      );

      final json = model.toJson();

      expect(json['organizations'], [
        {'id': 'org-1', 'name': 'Quesera Norte', 'role': 'ADMIN'},
      ]);
      // Round-trip: el perfil cacheado vuelve con sus queseras.
      expect(UserModel.fromJson(json).organizations, model.organizations);
    });
  });
}
