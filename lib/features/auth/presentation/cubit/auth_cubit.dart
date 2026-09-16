// lib/features/auth/presentation/cubit/auth_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/use_cases/login_use_case.dart';
import '../../domain/use_cases/login_with_google_use_case.dart';
import '../../domain/use_cases/check_auth_status_use_case.dart';
import '../../domain/use_cases/logout_use_case.dart';
import 'auth_state.dart';

/// Gestor de Estado para la pantalla principal de Auth.
///
/// SOLID (SRP): La única razón de esta clase para cambiar es si las reglas
/// dictan otra forma de actualizar el estado de UI frente a los Use Cases. No
/// llama librerías externas ni construye interfaces; solo recibe triggers,
/// llama a Casos de Uso del Domain, y emite (emit) el Estado resultante (State).
class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final LoginWithGoogleUseCase _loginWithGoogleUseCase;
  final CheckAuthStatusUseCase _checkAuthStatusUseCase;
  final LogoutUseCase _logoutUseCase;

  // Inyectado y testeable.
  AuthCubit(
    this._loginUseCase,
    this._loginWithGoogleUseCase,
    this._checkAuthStatusUseCase,
    this._logoutUseCase,
  ) : super(
        const AuthLoading(),
      ); // La app arranca siempre en estado MISTERIO (Cargando)

  Future<void> checkSession() async {
    emit(const AuthLoading());

    // Agregamos un delay intencional de 2 segundos para que la UI
    // del Splash Screen sea visible humanamente. Sin esto, leer el storage
    // nativo es tan rápido (milisegundos) que hace parpadear la pantalla.
    await Future.delayed(const Duration(seconds: 2));

    final result = await _checkAuthStatusUseCase();
    result.fold(
      (failure) => emit(
        const AuthInitial(),
      ), // Si falla, vuelve al estado inicial (Login Screen)
      (user) => emit(AuthSuccess(user)),
    );
  }

  Future<void> logout() async {
    // El UseCase devuelve Either: un fallo de almacenamiento se traduce
    // en AuthError (SnackBar) en vez de una excepción cruda sin capturar.
    final result = await _logoutUseCase();

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(const AuthInitial()),
    );
  }

  Future<void> login(String email, String password) async {
    emit(const AuthLoading());

    // Patrón funcional de Either<Failure, User> del Use Case
    final failureOrUser = await _loginUseCase(email: email, password: password);

    failureOrUser.fold(
      (failure) =>
          emit(AuthError(failure.message)), // Lado izquierdo de dartz (Error)
      (user) => emit(AuthSuccess(user)), // Lado derecho de dartz (Éxito)
    );
  }

  Future<void> loginWithGoogle() async {
    emit(const AuthLoading());

    final failureOrUser = await _loginWithGoogleUseCase();

    failureOrUser.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }
}
