import 'package:equatable/equatable.dart';

import '../../../auth/domain/failures/auth_failure.dart';

/// Estado de las cards de invitación (capa personal, backend 072).
/// `respondingId` = qué card está resolviendo accept/decline (spinner
/// en su botón y resto inerte); `failure` dispara el toast de la
/// sección vía listener — viaja el tipo, no el mensaje, para que la UI
/// lo traduzca a l10n (el `failure.message` viene en español fijo).
class OrgInvitesState extends Equatable {
  final String? respondingId;
  final AuthFailure? failure;

  const OrgInvitesState({this.respondingId, this.failure});

  bool get isResponding => respondingId != null;

  OrgInvitesState copyWith({
    String? respondingId,
    AuthFailure? failure,
    bool clearResponding = false,
    bool clearError = false,
  }) {
    return OrgInvitesState(
      respondingId: clearResponding
          ? null
          : (respondingId ?? this.respondingId),
      failure: clearError ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [respondingId, failure];
}
