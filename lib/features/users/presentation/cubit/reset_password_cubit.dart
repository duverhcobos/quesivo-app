import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/use_cases/update_user_password_use_case.dart';
import 'reset_password_state.dart';

/// Cubit del `ResetPasswordSheet` — orquesta SOLO el submit contra
/// `PATCH /auth/users/:id/password` (registerFactory: muere con el
/// sheet, mismo molde que `LinkUserCubit`). La validación del campo es
/// de la sheet vía `TempPassword`; acá solo llega el comando válido.
class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final UpdateUserPasswordUseCase _updateUserPassword;

  ResetPasswordCubit(this._updateUserPassword)
    : super(const ResetPasswordState());

  Future<void> submit({
    required String userId,
    required String password,
  }) async {
    // Anti doble-tap: un submit en vuelo ignora los siguientes.
    if (state.status.isInProgress) return;

    emit(const ResetPasswordState(status: FormzSubmissionStatus.inProgress));
    final result = await _updateUserPassword(
      userId: userId,
      password: password,
    );
    // Si el sheet se cerró con el submit en vuelo, el BlocProvider ya
    // cerró el cubit: emitir sobre él lanza StateError. El reset pudo
    // haberse aplicado igual en el backend.
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        ResetPasswordState(
          status: FormzSubmissionStatus.failure,
          failure: failure,
        ),
      ),
      (member) => emit(
        ResetPasswordState(
          status: FormzSubmissionStatus.success,
          resetMember: member,
        ),
      ),
    );
  }

  /// Limpia un failure viejo cuando el admin edita el campo — el error
  /// del backend no debe quedar stale sobre el dato ya corregido.
  void resetStatus() {
    if (state.status.isFailure) emit(const ResetPasswordState());
  }
}
