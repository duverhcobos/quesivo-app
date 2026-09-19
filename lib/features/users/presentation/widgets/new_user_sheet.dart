import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/password_requirements_checklist.dart';
import '../../../../core/widgets/quesivo_close_button.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/users_failure.dart';
import '../../domain/value_objects/member_email.dart';
import '../../domain/value_objects/member_name.dart';
import '../../domain/value_objects/temp_password.dart';
import '../cubit/create_user_cubit.dart';
import '../cubit/create_user_state.dart';
import 'role_selector_chips.dart';

/// Bottom sheet de creación de usuario (§44) — el primero de la app.
/// Integrado en §46: el submit pega a `POST /auth/users` real vía
/// `CreateUserCubit` y el sheet devuelve por `Navigator.pop` el
/// `OrgMember` que responde el backend (uuid, `status`, `linked`).
///
/// Validación manual al submit — `QuesivoTextField` expone `errorText`
/// (patrón del proyecto: el error llega de afuera, no de un `validator`
/// interno). La política vive en los VOs de dominio (`MemberName`,
/// `MemberEmail`, `TempPassword` — misma regla que `RegisterDto` del
/// backend, doc 007-post-users.md). El error del backend se muestra
/// inline sobre las acciones (no snackbar): el form queda abierto para
/// corregir — ej. `MEMBERSHIP_ALREADY_EXISTS` invita a cambiar el email.
class NewUserSheet extends StatefulWidget {
  const NewUserSheet({super.key});

  /// Abre el sheet y devuelve el miembro creado por el backend, o `null`
  /// si se canceló/falló. [cubit] es seam de tests — en producción se
  /// resuelve por `locator`.
  ///
  /// [topInset]: coordenada Y hasta donde el sheet puede crecer (borde
  /// inferior del hero navy). El alto total del sheet —contenido + padding
  /// del teclado— queda topeado ahí: con el teclado abierto el formulario
  /// se encoge y scrollea internamente en vez de cubrir la tarjeta azul.
  static Future<OrgMember?> show(
    BuildContext context, {
    double topInset = 0,
    CreateUserCubit? cubit,
  }) {
    return showModalBottomSheet<OrgMember>(
      context: context,
      // El sheet es modal: abre sobre el navigator RAÍZ para cubrir el
      // QuesivoNavBar del shell — abriéndolo sobre el navigator interno
      // del branch (StatefulShellRoute) la barra quedaba pintada encima
      // y tapaba la parte baja del form (bug visto en físico).
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.quesivoWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - topInset,
      ),
      builder: (_) => BlocProvider(
        create: (_) => cubit ?? locator<CreateUserCubit>(),
        child: const NewUserSheet(),
      ),
    );
  }

  @override
  State<NewUserSheet> createState() => _NewUserSheetState();
}

class _NewUserSheetState extends State<NewUserSheet> {
  /// Pausa de confirmación antes de cerrar: el usuario ve el check del
  /// botón + la línea verde de éxito dentro del sheet (feedback en
  /// físico — el pop inmediato tras el 201 se sentía abrupto).
  static const _successDismissDelay = Duration(milliseconds: 900);

  String _name = '';
  String _email = '';
  String _password = '';
  UserRole? _role;

  bool _nameError = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _roleError = false;

  void _submit() {
    final name = _name.trim();
    final email = _email.trim().toLowerCase();
    setState(() {
      _nameError = !MemberName.dirty(name).isValid;
      _emailError = !MemberEmail.dirty(email).isValid;
      _passwordError = !TempPassword.dirty(_password).isValid;
      _roleError = _role == null;
    });
    if (_nameError || _emailError || _passwordError || _roleError) return;

    context.read<CreateUserCubit>().submit(
      name: name,
      email: email,
      password: _password,
      role: _role!,
    );
  }

  String _failureText(AppLocalizations l10n, UsersFailure? failure) =>
      switch (failure) {
        MembershipAlreadyExistsFailure() => l10n.membershipExistsError,
        LinkedUserSuspendedFailure() => l10n.linkedUserSuspendedError,
        UsersForbiddenFailure() => l10n.usersForbiddenError,
        UsersRateLimitFailure() => l10n.tooManyAttemptsError,
        UsersNetworkFailure() => l10n.networkError,
        _ => l10n.genericError,
      };

  /// Editar cualquier campo limpia el error del backend stale — sin
  /// esto el mensaje persiste sobre datos ya corregidos.
  void _clearBackendError() => context.read<CreateUserCubit>().resetStatus();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Fuera del BlocConsumer: la zona fija (✕) y el PopScope también
    // necesitan saber si hay submit en vuelo o pausa de éxito activa.
    final isBusy = context.select<CreateUserCubit, bool>(
      (c) => c.state.status.isInProgress || c.state.status.isSuccess,
    );
    return PopScope(
      // Bloquea scrim-tap, drag-down y back durante el submit Y la
      // pausa de éxito: cerrar antes pierde el resultado (el miembro
      // pudo haberse creado sin que la UI lo sepa) y emitir sobre el
      // cubit ya cerrado lanza StateError. El pop retardado del
      // listener no lo frena canPop — Navigator.pop no consulta
      // popDisposition (solo maybePop/back lo hacen).
      canPop: !isBusy,
      child: Padding(
        // El sheet sube entero sobre el teclado.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        // Column externo fijo: el handle queda anclado arriba y solo el
        // form scrollea debajo (Flexible, no Expanded — el sheet sigue
        // midiendo al contenido cuando no hace falta scroll).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zona fija: handle centrado + ✕ navy arriba a la derecha
            // (mismo QuesivoCloseButton del drawer). Ni uno ni otro se
            // mueven con el scroll del form.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
              child: SizedBox(
                height: 40,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.quesivoBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      // Inerte durante el submit y la pausa de éxito —
                      // el PopScope bloquea el pop de todos modos; el
                      // atenuado comunica el bloqueo.
                      child: QuesivoCloseButton(enabled: !isBusy),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: BlocConsumer<CreateUserCubit, CreateUserState>(
                listenWhen: (p, c) =>
                    p.status != c.status && c.status.isSuccess,
                listener: (context, state) {
                  // Pausa de confirmación ~900ms: el check del botón y
                  // la línea verde quedan visibles antes de devolver el
                  // miembro REAL del backend (uuid + linked) por pop.
                  final member = state.createdMember;
                  Future.delayed(_successDismissDelay, () {
                    if (context.mounted) {
                      Navigator.of(context).pop(member);
                    }
                  });
                },
                builder: (context, state) {
                  final isBusy =
                      state.status.isInProgress || state.status.isSuccess;
                  final tempPassword = TempPassword.dirty(_password);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.newUserButton,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.quesivoNavy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.newUserSheetHint,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.quesivoTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        QuesivoTextField(
                          hintText: l10n.fullNamePlaceholder,
                          prefixIcon: Icons.person_outline,
                          keyboardType: TextInputType.name,
                          enabled: !isBusy,
                          errorText: _nameError
                              ? l10n.invalidMemberNameError
                              : null,
                          onChanged: (v) => setState(() {
                            _name = v;
                            _nameError = false;
                            _clearBackendError();
                          }),
                        ),
                        const SizedBox(height: 14),
                        QuesivoTextField(
                          hintText: l10n.registerEmailPlaceholder,
                          prefixIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !isBusy,
                          errorText: _emailError
                              ? l10n.invalidEmailError
                              : null,
                          onChanged: (v) => setState(() {
                            _email = v;
                            _emailError = false;
                            _clearBackendError();
                          }),
                        ),
                        const SizedBox(height: 14),
                        // Visible a propósito: es una contraseña temporal que el
                        // admin inventa y le comparte al usuario a mano — ocultarla
                        // solo dificultaría tipearla/dictarla sin typos.
                        QuesivoTextField(
                          hintText: l10n.tempPasswordPlaceholder,
                          prefixIcon: Icons.lock_outline,
                          enabled: !isBusy,
                          errorText: _passwordError
                              ? l10n.invalidTempPasswordError
                              : null,
                          onChanged: (v) => setState(() {
                            _password = v;
                            _passwordError = false;
                            _clearBackendError();
                          }),
                        ),
                        const SizedBox(height: 12),
                        // Checklist vivo (mismo de registro/reset) — evalúa
                        // los predicados del VO TempPassword de dominio.
                        PasswordRequirementsChecklist(
                          title: l10n.passwordReqTitle,
                          items: [
                            PasswordRequirementItem(
                              met: tempPassword.hasMinLength,
                              label: l10n.passwordReqMinLength,
                            ),
                            PasswordRequirementItem(
                              met: tempPassword.hasUppercase,
                              label: l10n.passwordReqUppercase,
                            ),
                            PasswordRequirementItem(
                              met: tempPassword.hasLowercase,
                              label: l10n.passwordReqLowercase,
                            ),
                            PasswordRequirementItem(
                              met: tempPassword.hasDigit,
                              label: l10n.passwordReqDigit,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.roleFieldLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.quesivoNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Form congelado durante el submit: los chips no
                        // aceptan taps (los args ya fueron capturados).
                        IgnorePointer(
                          ignoring: isBusy,
                          child: Opacity(
                            opacity: isBusy ? 0.6 : 1,
                            child: RoleSelectorChips(
                              selected: _role,
                              onChanged: (role) => setState(() {
                                _role = role;
                                _roleError = false;
                                _clearBackendError();
                              }),
                            ),
                          ),
                        ),
                        if (_roleError) ...[
                          const SizedBox(height: 6),
                          Text(
                            l10n.roleRequiredError,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        // Error del backend inline sobre el par de acciones
                        // (no snackbar): el form queda abierto para corregir.
                        if (state.status.isFailure) ...[
                          const SizedBox(height: 8),
                          Text(
                            _failureText(l10n, state.failure),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        // Confirmación visible durante la pausa de éxito
                        // (~900ms antes del pop): check + el mismo texto
                        // que va a mostrar el snackbar de la pantalla —
                        // distingue linked (ya tenía cuenta global).
                        if (state.status.isSuccess) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: AppColors.quesivoSuccess,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  state.createdMember?.linked ?? false
                                      ? l10n.memberLinkedFeedback(
                                          state.createdMember!.name,
                                        )
                                      : l10n.memberCreatedFeedback,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.quesivoSuccess,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Par lado a lado en mitades iguales (feedback del
                        // usuario — mismo tamaño para ambos): negativa ghost
                        // iconSurface a la izquierda, primario amarillo a la
                        // derecha; ambos 64px StadiumBorder, gap 12px.
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isBusy
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.quesivoIconSurface,
                                  foregroundColor: AppColors.quesivoNavy,
                                  elevation: 0,
                                  minimumSize: const Size(0, 64),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(l10n.cancelAction, maxLines: 1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: QuesivoPrimaryButton(
                                label: l10n.createUserButton,
                                // spinner → check → pop: la pausa de
                                // éxito mantiene el botón ocupado.
                                isLoading: state.status.isInProgress,
                                isSuccess: state.status.isSuccess,
                                onPressed: _submit,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
