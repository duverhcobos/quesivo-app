import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/org_invite.dart';
import '../../../auth/domain/failures/auth_failure.dart';
import '../../../auth/domain/use_cases/accept_org_invite_use_case.dart';
import '../../../auth/domain/use_cases/decline_org_invite_use_case.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import 'org_invites_state.dart';

/// Orquesta Aceptar/Rechazar sobre una card de invitación de la capa
/// personal (backend 072). Mismo molde que `QueseraSelectionCubit`:
/// no decide navegación — resuelve el POST y reporta loading/error por
/// card; en éxito el `AuthCubit` mueve el ítem entre `pendingInvites`
/// y `organizations` en el lugar (sin `GET /me` extra).
class OrgInvitesCubit extends Cubit<OrgInvitesState> {
  final AcceptOrgInviteUseCase _acceptOrgInvite;
  final DeclineOrgInviteUseCase _declineOrgInvite;
  final AuthCubit _authCubit;

  OrgInvitesCubit(
    this._acceptOrgInvite,
    this._declineOrgInvite,
    this._authCubit,
  ) : super(const OrgInvitesState());

  /// POST /auth/me/org-invites/:orgId/accept → invited pasa a active.
  /// Devuelve `true` si quedó aceptada (la sección muestra el toast de
  /// "ya sos parte de X"); error → `errorMessage` para el listener.
  Future<bool> accept(OrgInvite invite) async {
    if (state.isResponding) return false;
    emit(state.copyWith(respondingId: invite.id, clearError: true));

    final result = await _acceptOrgInvite(invite.organizationId);
    if (isClosed) return false;

    return result.fold(
      (failure) {
        // 404 = la membresía ya no existe (la resolviste en otro device
        // o el admin la canceló): la card stale sale en el lugar, sin
        // esperar el próximo /me (revisión §69).
        if (failure is OrgInviteNotFoundFailure) {
          _authCubit.applyOrgInviteDeclined(invite);
        }
        emit(state.copyWith(clearResponding: true, failure: failure));
        return false;
      },
      (_) {
        _authCubit.applyOrgInviteAccepted(invite);
        emit(state.copyWith(clearResponding: true));
        return true;
      },
    );
  }

  /// POST /auth/me/org-invites/:orgId/decline → borra la membresía
  /// invited (el typo del admin se resuelve desde acá). En éxito la
  /// card desaparece — sin toast de "éxito" en una negativa, la
  /// desaparición ES el feedback.
  Future<bool> decline(OrgInvite invite) async {
    if (state.isResponding) return false;
    emit(state.copyWith(respondingId: invite.id, clearError: true));

    final result = await _declineOrgInvite(invite.organizationId);
    if (isClosed) return false;

    return result.fold(
      (failure) {
        if (failure is OrgInviteNotFoundFailure) {
          _authCubit.applyOrgInviteDeclined(invite);
        }
        emit(state.copyWith(clearResponding: true, failure: failure));
        return false;
      },
      (_) {
        _authCubit.applyOrgInviteDeclined(invite);
        emit(state.copyWith(clearResponding: true));
        return true;
      },
    );
  }
}
