import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/use_cases/skip_org_name_setup_use_case.dart';
import '../../domain/use_cases/update_organization_name_use_case.dart';
import 'org_name_setup_state.dart';

/// Orquesta la pantalla "¿Cómo se llama tu quesera?" (propuesta 71 —
/// signup por Google: la org nació con el nombre de la cuenta).
///
/// SOLID (SRP): no decide navegación — tras el PATCH exitoso (o el
/// skip) actualiza el `AuthCubit` y el `AuthGuard` redirige a /home en
/// la próxima evaluación, sin navegación manual acá.
class OrgNameSetupCubit extends Cubit<OrgNameSetupState> {
  final UpdateOrganizationNameUseCase _updateName;
  final SkipOrgNameSetupUseCase _skipNameSetup;
  final AuthCubit _authCubit;

  OrgNameSetupCubit(this._updateName, this._skipNameSetup, this._authCubit)
    : super(const OrgNameSetupState());

  /// PATCH /organizations/me → éxito: el AuthCubit aplica el nombre
  /// nuevo y limpia el flag → el guard suelta a /home solo.
  Future<void> submit(String name) async {
    // Anti doble-tap: un submit en vuelo ignora los siguientes.
    if (state.isSubmitting) return;

    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _updateName(name);
    // Si la pantalla murió con el submit en vuelo, el BlocProvider ya
    // cerró el cubit: emitir sobre él lanzaría StateError.
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(isSubmitting: false, failure: failure)),
      (newName) {
        // El AuthCubit global pudo cerrarse durante el await (teardown
        // de la app) — emitir sobre él lanzaría StateError.
        if (_authCubit.isClosed) return;
        _authCubit.applyOrganizationRenamed(newName);
      },
    );
  }

  /// Limpia el flag sin PATCH — la org conserva el nombre generado.
  /// Persiste `isNewSignup: false` en la sesión local (best-effort: si
  /// el storage falla el flag igual se limpia en memoria — en el peor
  /// caso la pantalla reaparece tras un restart).
  Future<void> skip() async {
    // Anti doble-tap: un submit/skip en vuelo ignora los siguientes.
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    await _skipNameSetup();
    if (isClosed || _authCubit.isClosed) return;
    _authCubit.skipOrgNameSetup();
  }
}
