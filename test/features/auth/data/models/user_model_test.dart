import 'package:flutter_test/flutter_test.dart';

import 'package:quesivo/features/auth/data/models/user_model.dart';
import 'package:quesivo/features/auth/domain/entities/org_invite.dart';
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

  group('UserModel.fromJson — pendingInvites (§69, backend 072)', () {
    test('parsea pendingInvites[] del payload de GET /auth/me', () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'ana@test.com',
        'name': 'Ana',
        'pendingInvites': [
          {
            'id': 'mem-1',
            'organizationId': 'org-9',
            'organizationName': 'Quesera Norte',
            'role': 'OPERATOR',
          },
        ],
      });

      expect(model.pendingInvites, [
        const OrgInvite(
          id: 'mem-1',
          organizationId: 'org-9',
          organizationName: 'Quesera Norte',
          role: 'OPERATOR',
        ),
      ]);
    });

    test('pendingInvites ausente (login/register, /me viejo) → '
        'lista vacía', () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'ana@test.com',
        'name': 'Ana',
      });

      expect(model.pendingInvites, isEmpty);
    });

    test('toJson serializa pendingInvites y el round-trip lo conserva', () {
      const model = UserModel(
        id: 'u1',
        email: 'ana@test.com',
        name: 'Ana',
        pendingInvites: [
          OrgInvite(
            id: 'mem-1',
            organizationId: 'org-9',
            organizationName: 'Quesera Norte',
            role: 'OPERATOR',
          ),
        ],
      );

      final json = model.toJson();

      expect(json['pendingInvites'], [
        {
          'id': 'mem-1',
          'organizationId': 'org-9',
          'organizationName': 'Quesera Norte',
          'role': 'OPERATOR',
        },
      ]);
      expect(UserModel.fromJson(json).pendingInvites, model.pendingInvites);
    });
  });

  group('UserModel — isNewSignup (§71, backend 087)', () {
    test('isNewSignup:true llega solo en la respuesta de /auth/google '
        'cuando fue signup → parsea true', () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'ana@test.com',
        'name': 'Ana',
        'isNewSignup': true,
      });

      expect(model.isNewSignup, isTrue);
    });

    test('isNewSignup ausente (login/me/linked, backend viejo) → false', () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'ana@test.com',
        'name': 'Ana',
      });

      expect(model.isNewSignup, isFalse);
    });

    test('isNewSignup:false explícito → false (no "truthy")', () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'ana@test.com',
        'name': 'Ana',
        'isNewSignup': false,
      });

      expect(model.isNewSignup, isFalse);
    });

    test('toJson persiste el flag y el round-trip lo conserva '
        '(sobrevive al restart entre signup y nombrado)', () {
      const model = UserModel(
        id: 'u1',
        email: 'ana@test.com',
        name: 'Ana',
        isNewSignup: true,
      );

      final json = model.toJson();

      expect(json['isNewSignup'], isTrue);
      expect(UserModel.fromJson(json).isNewSignup, isTrue);
    });

    test('copyWith preserva el flag si no se pasa (merge de /me no lo '
        'apaga) y lo cambia si se pasa explícito', () {
      const model = UserModel(
        id: 'u1',
        email: 'ana@test.com',
        name: 'Ana',
        isNewSignup: true,
      );

      expect(model.copyWith(name: 'Otra').isNewSignup, isTrue);
      expect(model.copyWith(isNewSignup: false).isNewSignup, isFalse);
    });
  });
}
