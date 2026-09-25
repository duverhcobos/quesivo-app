import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Caso de Uso: aceptar la invitación por correo — flujo Email-C
/// (doc 017, propuestas backend 070/071). El link del correo trae el
/// `token`; el invitado solo define su contraseña — el backend crea la
/// sesión de una (mismo shape de respuesta que verify-email) y el
/// repositorio la persiste igual que login: la pantalla solo llama
/// `AuthCubit.refreshSession()` y AuthGuard lleva a /home.
class AcceptInviteUseCase {
  final IAuthRepository repository;

  const AcceptInviteUseCase(this.repository);

  Future<Either<AuthFailure, User>> call({
    required String token,
    required String password,
  }) {
    return repository.acceptInvite(token: token, password: password);
  }
}
