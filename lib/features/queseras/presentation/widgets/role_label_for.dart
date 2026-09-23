import 'package:quesivo/l10n/app_localizations.dart';

import '../../../users/domain/entities/user_role.dart';
import '../../../users/presentation/widgets/user_role_ui.dart';

/// Mapa rol → label l10n para `OrganizationSummary.role` (el String que
/// llega en `organizations[]` de `GET /auth/me`, §55). Delega en el
/// catálogo único del módulo users (`UserRole.fromApi` + `UserRoleUi`),
/// incluido su fallback defensivo a OPERATOR ante un rol desconocido —
/// así las claves `adminRole`/`roleOperator`/`roleCollector`/
/// `roleProducer` se leen de una sola fuente.
extension RoleLabelFor on AppLocalizations {
  String roleLabelFor(String role) => UserRole.fromApi(role).label(this);
}
