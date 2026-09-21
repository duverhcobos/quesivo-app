import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/entities/user_role.dart';
import '../../domain/use_cases/link_user_use_case.dart';
import 'link_user_state.dart';

/// Cubit del `LinkUserSheet` — orquesta SOLO el submit contra
/// `POST /auth/users/link` (registerFactory: muere con el sheet). La
/// validación de campos es de la sheet vía VOs; acá solo llega el
/// comando ya válido.
class LinkUserCubit extends Cubit<LinkUserState> {
  final LinkUserUseCase _linkUser;

  LinkUserCubit(this._linkUser) : super(const LinkUserState());

  Future<void> submit({required String email, required UserRole role}) async {
    // Anti doble-tap: un submit en vuelo ignora los siguientes.
    if (state.status.isInProgress) return;

    emit(const LinkUserState(status: FormzSubmissionStatus.inProgress));
    final result = await _linkUser(email: email, role: role);
    // Si el sheet se cerró con el submit en vuelo, el BlocProvider ya
    // cerró el cubit: emitir sobre él lanza StateError. El miembro pudo
    // haberse vinculado igual — aparecerá en el próximo GET /auth/users.
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        LinkUserState(status: FormzSubmissionStatus.failure, failure: failure),
      ),
      (member) => emit(
        LinkUserState(
          status: FormzSubmissionStatus.success,
          linkedMember: member,
        ),
      ),
    );
  }

  /// Limpia un failure viejo cuando el usuario edita el form — el error
  /// del backend no debe quedar stale sobre campos ya corregidos.
  void resetStatus() {
    if (state.status.isFailure) emit(const LinkUserState());
  }
}
