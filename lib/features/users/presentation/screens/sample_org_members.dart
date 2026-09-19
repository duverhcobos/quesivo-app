import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';

/// Genera 54 miembros sintéticos (9 nombres × 6 apellidos, combinación
/// única cada uno) para validar el listado con volumen real antes de
/// integrar `GET /auth/users` — reemplaza a este generador por el
/// repositorio real en esa propuesta. Cubre los 4 roles del catálogo
/// (incluye Productor, ausente en la muestra original de §37) y un ~15%
/// de suspendidos para que los filtros y el chip de estado tengan algo
/// que mostrar.
///
/// Distribución de roles **no uniforme** (4 admin / 22 operario /
/// 15 recolector / 13 productor): a propósito Operario supera
/// `_pageSize` (15) para que el scroll paginado se pueda validar
/// también filtrando por un rol puntual, no solo en "Todos" — con un
/// reparto parejo (13-14 por rol) ningún filtro individual alcanzaba a
/// disparar una segunda tanda.
List<OrgMember> generateSampleOrgMembers() {
  const firstNames = [
    'Ana',
    'Juan',
    'Pedro',
    'María',
    'Carlos',
    'Lucía',
    'Diego',
    'Valentina',
    'Martín',
  ];
  const lastNames = ['Pérez', 'Gómez', 'Ruiz', 'Fernández', 'Torres', 'Molina'];
  // Formas ASCII para el correo — evita depender de una función de
  // normalización solo para este generador temporal.
  const firstNamesAscii = [
    'ana',
    'juan',
    'pedro',
    'maria',
    'carlos',
    'lucia',
    'diego',
    'valentina',
    'martin',
  ];
  const lastNamesAscii = [
    'perez',
    'gomez',
    'ruiz',
    'fernandez',
    'torres',
    'molina',
  ];

  final members = <OrgMember>[];
  var index = 0;
  for (var f = 0; f < firstNames.length; f++) {
    for (var l = 0; l < lastNames.length; l++) {
      final role = _roleForIndex(index);
      final status = index % 7 == 0
          ? MemberStatus.suspended
          : MemberStatus.active;
      members.add(
        OrgMember(
          id: 'sample-$index',
          email: '${firstNamesAscii[f]}.${lastNamesAscii[l]}@mail.com',
          name: '${firstNames[f]} ${lastNames[l]}',
          role: role,
          status: status,
          organizationId: 'sample-org',
        ),
      );
      index++;
    }
  }
  return members;
}

/// Reparto no uniforme por rango de índice (ver doc de
/// [generateSampleOrgMembers]): 4 admin / 22 operario / 15 recolector /
/// 13 productor sobre 54 miembros.
UserRole _roleForIndex(int index) {
  if (index < 4) return UserRole.admin;
  if (index < 26) return UserRole.operator;
  if (index < 41) return UserRole.collector;
  return UserRole.producer;
}
