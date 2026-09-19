import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../domain/entities/user_role.dart';

/// Mapa único rol → label l10n + ícono de dominio (§44) — antes el mismo
/// switch vivía duplicado en `MemberRoleChip` y `RoleFilterChips`, y el
/// selector del sheet de creación sería la tercera copia.
///
/// Íconos queseros (§38): escudo = admin, casco = operario de planta,
/// camión = recolector de ruta, tractor = productor lechero.
extension UserRoleUi on UserRole {
  String label(AppLocalizations l10n) => switch (this) {
    UserRole.admin => l10n.adminRole,
    UserRole.operator => l10n.roleOperator,
    UserRole.collector => l10n.roleCollector,
    UserRole.producer => l10n.roleProducer,
  };

  IconData get icon => switch (this) {
    UserRole.admin => Icons.shield_outlined,
    UserRole.operator => Icons.engineering_outlined,
    UserRole.collector => Icons.local_shipping_outlined,
    UserRole.producer => Icons.agriculture_outlined,
  };
}
