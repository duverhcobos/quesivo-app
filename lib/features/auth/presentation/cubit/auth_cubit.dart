// lib/features/auth/presentation/cubit/auth_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session_expired_notifier.dart';
import '../../domain/entities/org_invite.dart';
import '../../domain/entities/organization_session.dart';
import '../../domain/entities/organization_summary.dart';
import '../../domain/failures/auth_failure.dart';
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
  final SessionExpiredNotifier _sessionExpiredNotifier;

  late final StreamSubscription<void> _sessionExpiredSub;

  // Inyectado y testeable.
  AuthCubit(
    this._loginUseCase,
    this._loginWithGoogleUseCase,
    this._checkAuthStatusUseCase,
    this._logoutUseCase,
    this._sessionExpiredNotifier,
  ) : super(const AuthLoading()) {
    // La capa de red avisa cuando el refresh token murió (revocado,
    // expirado o reuso detectado): si el usuario estaba adentro de la
    // app, pasarlo a AuthInitial para que AuthGuard lo mande a welcome.
    _sessionExpiredSub = _sessionExpiredNotifier.stream.listen((_) {
      // isClosed: un evento puede llegar entre close() y la cancelación
      // efectiva de la suscripción — emitir ahí lanzaría StateError.
      if (!isClosed && state is AuthSuccess) emit(const AuthInitial());
    });
  }

  @override
  Future<void> close() {
    _sessionExpiredSub.cancel();
    return super.close();
  }

  Future<void> checkSession() async {
    emit(const AuthLoading());

    // Agregamos un delay intencional de 2 segundos para que la UI
    // del Splash Screen sea visible humanamente. Sin esto, leer el storage
    // nativo es tan rápido (milisegundos) que hace parpadear la pantalla.
    await Future.delayed(const Duration(seconds: 2));

    await _loadSession();
  }

  /// Recarga la sesión SIN el delay del splash — para los triggers
  /// post-login/register y post-select-organization, donde el usuario
  /// ya está adentro y 2s de espera sería fricción. Misma fuente:
  /// `GET /auth/me` vía `CheckAuthStatusUseCase` (propuesta backend 066).
  Future<void> refreshSession() async {
    emit(const AuthLoading());
    await _loadSession();
  }

  /// Refresh de `/me` en segundo plano (§69 — caso del invitado ya
  /// logueado): el mail de org-invite puede llegar con la sesión viva y
  /// el `User` en memoria no tiene la invitación — sin esto la card no
  /// aparece hasta el próximo login. Lo dispara el deep link
  /// `quesivo://org-invites`. A diferencia de `refreshSession` NO emite
  /// `AuthLoading` (no hay flash de splash — el usuario ya está mirando
  /// el /home) y un fallo no patea a AuthInitial: la sesión sigue como
  /// está y el próximo `checkAuthStatus` natural reintenta. Solo corre
  /// con `AuthSuccess` — sin sesión el guard manda a welcome igual.
  Future<void> refreshSessionSilently() async {
    final current = state;
    if (current is! AuthSuccess) return;
    final result = await _checkAuthStatusUseCase();
    if (isClosed) return;
    result.fold((_) {}, (user) {
      // El state pudo cambiar mientras el /me estaba en vuelo (logout,
      // sesión expirada, otra respuesta): solo pisamos si sigue Success.
      // El flag y enteredOrg se toman del state FRESCO, no del snapshot
      // pre-await — si corrió applyOrganizationRenamed/skipOrgNameSetup/
      // exitOrganization en el medio, resucitar los valores viejos
      // volvería a forzar la pantalla de nombrado ya completada.
      final fresh = state;
      if (fresh is AuthSuccess) {
        emit(
          AuthSuccess(
            // Propuesta 71 — `isNewSignup` no viaja en /me: se preserva
            // del user vivo igual que enteredOrg.
            user.copyWith(isNewSignup: fresh.user.isNewSignup),
            enteredOrg: fresh.enteredOrg,
          ),
        );
      }
    });
  }

  /// Marca que el usuario entró a una quesera en esta sesión de app
  /// (§57). Lo llama `QueseraSelectionCubit` tras un select-organization
  /// exitoso — o directo cuando el tap cayó en la org que el JWT ya
  /// traía (sesión restaurada, entrada gratis).
  void enterOrganization() {
    final current = state;
    if (current is AuthSuccess && !current.enteredOrg) {
      emit(AuthSuccess(current.user, enteredOrg: true));
    }
  }

  /// Reconstruye el User en el lugar tras un select-organization
  /// exitoso (§63): los tokens org-scoped ya están persistidos y el
  /// response trae orgId/orgName — sin `GET /auth/me` extra. El rol
  /// sale de `organizations` (la membresía de ESA quesera; si no está
  /// en la lista se conservan los roles actuales). `id`, `email`,
  /// `name`, `status` y `organizations` quedan sin cambio.
  void enterOrganizationWithSession(OrganizationSession session) {
    final current = state;
    if (current is! AuthSuccess) return;

    final membership = current.user.organizations.where(
      (o) => o.id == session.organizationId,
    );

    emit(
      AuthSuccess(
        current.user.copyWith(
          token: session.accessToken,
          refreshToken: session.refreshToken,
          organizationId: session.organizationId,
          organizationName: session.organizationName,
          roles: membership.isEmpty
              ? current.user.roles
              : [membership.first.role],
        ),
        enteredOrg: true,
      ),
    );
  }

  /// Sale de la quesera activa — vuelve al selector limpio (§57: la
  /// selección se deja limpia al salir). El token org-scoped sigue
  /// guardado y sirviendo; solo baja la flag de UI. Lo llama el back
  /// del shell parado en Inicio.
  void exitOrganization() {
    final current = state;
    if (current is AuthSuccess && current.enteredOrg) {
      emit(AuthSuccess(current.user));
    }
  }

  /// El usuario aceptó la invitación de una org (backend 072 — doc
  /// 019): la membresía quedó `active` server-side; acá se mueve la
  /// invitación de `pendingInvites` a `organizations` en el lugar —
  /// la card "Entrar" aparece sin `GET /me` extra ni flash de
  /// `AuthLoading` (el storage cacheado queda stale solo hasta el
  /// próximo /me natural — el backend ya mutó, no hay drift real).
  void applyOrgInviteAccepted(OrgInvite invite) {
    final current = state;
    if (current is! AuthSuccess) return;
    emit(
      AuthSuccess(
        current.user.copyWith(
          organizations: [
            // Dedup defensivo (revisión §69): una race o re-emit no
            // puede dejar la misma org dos veces en el selector.
            ...current.user.organizations.where(
              (o) => o.id != invite.organizationId,
            ),
            OrganizationSummary(
              id: invite.organizationId,
              name: invite.organizationName,
              role: invite.role,
            ),
          ],
          pendingInvites: current.user.pendingInvites
              .where((i) => i.id != invite.id)
              .toList(),
        ),
        enteredOrg: current.enteredOrg,
      ),
    );
  }

  /// Decline (doc 020): la membresía `invited` se borró server-side —
  /// la invitación sale de `pendingInvites` en el lugar.
  void applyOrgInviteDeclined(OrgInvite invite) {
    final current = state;
    if (current is! AuthSuccess) return;
    emit(
      AuthSuccess(
        current.user.copyWith(
          pendingInvites: current.user.pendingInvites
              .where((i) => i.id != invite.id)
              .toList(),
        ),
        enteredOrg: current.enteredOrg,
      ),
    );
  }

  /// PATCH /organizations/me exitoso (propuesta 71): actualiza el nombre
  /// de la org en el user (selector + header) y limpia el flag — el guard
  /// suelta al home en la próxima evaluación.
  void applyOrganizationRenamed(String newName) {
    final current = state;
    if (current is! AuthSuccess) return;
    emit(
      AuthSuccess(
        current.user.copyWith(
          organizationName: newName,
          isNewSignup: false,
          organizations: [
            for (final o in current.user.organizations)
              o.id == current.user.organizationId
                  ? OrganizationSummary(id: o.id, name: newName, role: o.role)
                  : o,
          ],
        ),
        enteredOrg: current.enteredOrg,
      ),
    );
  }

  /// "Por ahora no" en la pantalla de nombrado: limpia el flag sin PATCH —
  /// la org conserva el nombre generado (renombrable después con el mismo
  /// endpoint). El repositorio ya persistió el flag limpio en la sesión
  /// local (skipNameSetup del OrgNameSetupCubit).
  void skipOrgNameSetup() {
    final current = state;
    if (current is! AuthSuccess) return;
    emit(
      AuthSuccess(
        current.user.copyWith(isNewSignup: false),
        enteredOrg: current.enteredOrg,
      ),
    );
  }

  Future<void> _loadSession() async {
    final result = await _checkAuthStatusUseCase();
    result.fold(
      (failure) => emit(
        const AuthInitial(),
      ), // Si falla, vuelve al estado inicial (Login Screen)
      (user) {
        // Propuesta 71 — el `isNewSignup` de /auth/google no viaja en
        // /me: si hay un Success vivo que lo tenga prendido se preserva
        // (igual que enteredOrg en los otros emits); el resto del tiempo
        // llega ya seteado desde la sesión persistida.
        final current = state;
        emit(
          AuthSuccess(
            current is AuthSuccess
                ? user.copyWith(isNewSignup: current.user.isNewSignup)
                : user,
          ),
        );
      },
    );
  }

  Future<void> logout() async {
    // El UseCase devuelve Either: un fallo de almacenamiento se traduce
    // en AuthError (toast) en vez de una excepción cruda sin capturar.
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

    await failureOrUser.fold(
      (failure) async {
        // Cancelar el picker no es un error: volver al estado inicial
        // sin mensaje — el usuario simplemente desistió.
        if (failure is GoogleSignInCancelledFailure) {
          emit(const AuthInitial());
          return;
        }
        emit(AuthError(failure.message));
      },
      // El AuthSuccess del response de /auth/google NO trae
      // organizations (sesión personal) — el selector de queseras se
      // llena con GET /auth/me. refreshSession() hidrata igual que los
      // otros auto-logins (login, verify-email, accept-invite).
      (_) => refreshSession(),
    );
  }
}
