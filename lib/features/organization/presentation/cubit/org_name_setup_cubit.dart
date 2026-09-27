import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/use_cases/select_organization_use_case.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/failures/organization_failure.dart';
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
  final SelectOrganizationUseCase _selectOrganization;
  final AuthCubit _authCubit;

  OrgNameSetupCubit(
    this._updateName,
    this._skipNameSetup,
    this._selectOrganization,
    this._authCubit,
  ) : super(const OrgNameSetupState());

  /// PATCH /organizations/me → éxito: el AuthCubit aplica el nombre
  /// nuevo y limpia el flag → el guard suelta a /home solo.
  ///
  /// La pantalla va ANTES del home (corrección §71): con sesión personal
  /// el PATCH no tiene org en el JWT — primero se entra a la org del
  /// signup por debajo (`select-organization`), transparente para el
  /// usuario; el signup siempre crea exactamente una (createWithAdmin).
  Future<void> submit(String name) async {
    // Anti doble-tap: un submit en vuelo ignora los siguientes.
    if (state.isSubmitting) return;

    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final auth = _authCubit.state;
    if (auth is AuthSuccess && !auth.enteredOrg) {
      final orgs = auth.user.organizations;
      if (orgs.isEmpty) {
        emit(
          state.copyWith(
            isSubmitting: false,
            failure: const OrganizationUpdateFailure(),
          ),
        );
        return;
      }
      final selected = await _selectOrganization(orgs.first.id);
      if (isClosed || _authCubit.isClosed) return;
      final session = selected.fold((_) => null, (s) => s);
      if (session == null) {
        emit(
          state.copyWith(
            isSubmitting: false,
            failure: const OrganizationUpdateFailure(),
          ),
        );
        return;
      }
      _authCubit.enterOrganizationWithSession(session);
    }

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
