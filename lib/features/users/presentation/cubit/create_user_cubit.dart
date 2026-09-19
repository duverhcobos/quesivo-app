import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../domain/entities/user_role.dart';
import '../../domain/use_cases/create_user_use_case.dart';
import 'create_user_state.dart';

/// Cubit del `NewUserSheet` — orquesta SOLO el submit contra
/// `POST /auth/users` (registerFactory: muere con el sheet). La
/// validación de campos es de la sheet vía VOs; acá solo llega el
/// comando ya válido.
class CreateUserCubit extends Cubit<CreateUserState> {
  final CreateUserUseCase _createUser;

  CreateUserCubit(this._createUser) : super(const CreateUserState());

  Future<void> submit({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    // Anti doble-tap: un submit en vuelo ignora los siguientes.
    if (state.status.isInProgress) return;

    emit(const CreateUserState(status: FormzSubmissionStatus.inProgress));
    final result = await _createUser(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    // Si el sheet se cerró con el submit en vuelo, el BlocProvider ya
    // cerró el cubit: emitir sobre él lanza StateError. El miembro pudo
    // haberse creado igual — aparecerá en el próximo GET /auth/users.
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        CreateUserState(
          status: FormzSubmissionStatus.failure,
          failure: failure,
        ),
      ),
      (member) => emit(
        CreateUserState(
          status: FormzSubmissionStatus.success,
          createdMember: member,
        ),
      ),
    );
  }

  /// Limpia un failure viejo cuando el usuario edita el form — el error
  /// inline del backend no debe quedar stale sobre campos ya corregidos.
  void resetStatus() {
    if (state.status.isFailure) emit(const CreateUserState());
  }
}
