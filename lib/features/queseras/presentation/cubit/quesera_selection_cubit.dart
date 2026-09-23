import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/use_cases/select_organization_use_case.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import 'quesera_selection_state.dart';

/// Orquesta el tap en una card de quesera (capa personal, propuesta §55).
///
/// SOLID (SRP): no decide navegación — eso es del `AuthGuard`/router vía
/// el `AuthSuccess` que emite `AuthCubit` tras
/// `enterOrganizationWithSession()` (§63). Este cubit solo resuelve
/// `POST /auth/select-organization` y reporta loading/error por card.
class QueseraSelectionCubit extends Cubit<QueseraSelectionState> {
  final SelectOrganizationUseCase _selectOrganization;
  final AuthCubit _authCubit;

  QueseraSelectionCubit(this._selectOrganization, this._authCubit)
    : super(const QueseraSelectionState());

  /// Entra a la quesera tocada (§57). Devuelve `true` si quedó activa.
  /// Si el JWT restaurado ya traía ESA org, la entrada es gratis — el
  /// usuario ve la misma card "Entrar" y el mismo tap, pero se omite el
  /// POST (la selección limpia es visual; el token sigue sirviendo).
  Future<bool> select(String organizationId) async {
    if (state.isSelecting) return false;

    final auth = _authCubit.state;
    if (auth is AuthSuccess &&
        auth.user.organizationId == organizationId &&
        !auth.enteredOrg) {
      _authCubit.enterOrganization();
      return true;
    }

    emit(state.copyWith(selectingId: organizationId, clearError: true));

    final result = await _selectOrganization(organizationId);

    return result.fold(
      (failure) {
        emit(
          state.copyWith(clearSelection: true, errorMessage: failure.message),
        );
        return false;
      },
      (session) {
        // Los tokens nuevos ya están en storage; la sesión del response
        // alcanza para reconstruir el User en el lugar (§63) — sin
        // GET /auth/me extra.
        _authCubit.enterOrganizationWithSession(session);
        emit(state.copyWith(clearSelection: true));
        return true;
      },
    );
  }
}
