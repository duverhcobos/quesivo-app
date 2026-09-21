import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_close_button.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/users_failure.dart';
import '../../domain/value_objects/member_email.dart';
import '../cubit/link_user_cubit.dart';
import '../cubit/link_user_state.dart';
import 'role_selector_chips.dart';

/// Bottom sheet de vinculación de usuario existente (§48) — espejo
/// estructural de `NewUserSheet` menos nombre/password/checklist: el
/// correo ya tiene cuenta global, así que el form solo pide email +
/// rol y el submit pega a `POST /auth/users/link` vía `LinkUserCubit`
/// (propuesta backend 058 — el endpoint solo crea la membresía).
///
/// Misma mecánica que el sheet de creación: validación manual al submit
/// con el VO de dominio (`MemberEmail` — `Email.allowedChars` bloquea
/// a nivel tecla y el errorText se computa en vivo, patrón §47), el
/// error del backend sale por `QuesivoToast.error` sobre el overlay
/// raíz (el form queda abierto para corregir — ej. `USER_NOT_FOUND`
/// invita a revisar el email o crear el usuario), y el éxito espera
/// ~500ms con el check del botón antes de devolver el `OrgMember`
/// (`linked:true`) por `Navigator.pop`.
class LinkUserSheet extends StatefulWidget {
  const LinkUserSheet({super.key});

  /// Abre el sheet y devuelve el miembro vinculado por el backend, o
  /// `null` si se canceló/falló. [cubit] es seam de tests — en
  /// producción se resuelve por `locator`.
  ///
  /// [topInset]: coordenada Y hasta donde el sheet puede crecer (borde
  /// inferior del hero navy). El alto total del sheet —contenido + padding
  /// del teclado— queda topeado ahí: con el teclado abierto el formulario
  /// se encoge y scrollea internamente en vez de cubrir la tarjeta azul.
  static Future<OrgMember?> show(
    BuildContext context, {
    double topInset = 0,
    LinkUserCubit? cubit,
  }) {
    return showModalBottomSheet<OrgMember>(
      context: context,
      // El sheet es modal: abre sobre el navigator RAÍZ para cubrir el
      // QuesivoNavBar del shell — abriéndolo sobre el navigator interno
      // del branch (StatefulShellRoute) la barra quedaba pintada encima
      // y tapaba la parte baja del form (bug visto en físico).
      useRootNavigator: true,
      // Salida más suave que el default (~200ms): tras la pausa de
      // éxito el sheet baja en ~450ms — el cierre instantáneo se
      // sentía abrupto (feedback del usuario en físico).
      sheetAnimationStyle: const AnimationStyle(
        reverseDuration: Duration(milliseconds: 450),
      ),
      isScrollControlled: true,
      backgroundColor: AppColors.quesivoWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - topInset,
      ),
      builder: (_) => BlocProvider(
        create: (_) => cubit ?? locator<LinkUserCubit>(),
        child: const LinkUserSheet(),
      ),
    );
  }

  @override
  State<LinkUserSheet> createState() => _LinkUserSheetState();
}

class _LinkUserSheetState extends State<LinkUserSheet> {
  /// Pausa de confirmación antes de cerrar: el usuario ve el check del
  /// botón dentro del sheet (mismo ~500ms del sheet de creación).
  static const _successDismissDelay = Duration(milliseconds: 500);

  String _email = '';
  UserRole? _role;

  bool _emailError = false; // submit: vacío · live: formato inválido
  bool _roleError = false;

  void _submit() {
    final email = _email.trim().toLowerCase();
    setState(() {
      _emailError = !MemberEmail.dirty(email).isValid;
      _roleError = _role == null;
    });
    if (_emailError || _roleError) return;

    context.read<LinkUserCubit>().submit(email: email, role: _role!);
  }

  String _failureText(AppLocalizations l10n, UsersFailure? failure) =>
      switch (failure) {
        UserNotFoundFailure() => l10n.userNotFoundError,
        MembershipAlreadyExistsFailure() => l10n.membershipExistsError,
        LinkedUserSuspendedFailure() => l10n.linkedUserSuspendedError,
        UserIsOwnerFailure() => l10n.userIsOwnerError,
        UsersForbiddenFailure() => l10n.usersForbiddenError,
        UsersRateLimitFailure() => l10n.tooManyAttemptsError,
        UsersNetworkFailure() => l10n.networkError,
        _ => l10n.genericError,
      };

  /// Editar cualquier campo limpia el error del backend stale — sin
  /// esto el mensaje persiste sobre datos ya corregidos.
  void _clearBackendError() => context.read<LinkUserCubit>().resetStatus();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Fuera del BlocConsumer: la zona fija (✕) y el PopScope también
    // necesitan saber si hay submit en vuelo o pausa de éxito activa.
    final isBusy = context.select<LinkUserCubit, bool>(
      (c) => c.state.status.isInProgress || c.state.status.isSuccess,
    );
    return PopScope(
      // Bloquea scrim-tap, drag-down y back durante el submit Y la
      // pausa de éxito: cerrar antes pierde el resultado (el miembro
      // pudo haberse vinculado sin que la UI lo sepa) y emitir sobre el
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
              child: BlocConsumer<LinkUserCubit, LinkUserState>(
                listenWhen: (p, c) =>
                    p.status != c.status &&
                    (c.status.isSuccess || c.status.isFailure),
                listener: (context, state) {
                  if (state.status.isFailure) {
                    // Error del backend → toast rojo sobre el overlay
                    // raíz (flota por encima del sheet): el form queda
                    // abierto para corregir — ej. el 404 invita a
                    // revisar el email o crear el usuario.
                    QuesivoToast.error(
                      context,
                      message: _failureText(
                        AppLocalizations.of(context)!,
                        state.failure,
                      ),
                    );
                    return;
                  }
                  // Pausa de confirmación ~500ms: el check del botón
                  // queda visible antes de devolver el miembro REAL
                  // del backend (uuid + linked:true) por pop.
                  final member = state.linkedMember;
                  Future.delayed(_successDismissDelay, () {
                    if (context.mounted) {
                      Navigator.of(context).pop(member);
                    }
                  });
                },
                builder: (context, state) {
                  final isBusy =
                      state.status.isInProgress || state.status.isSuccess;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.linkUserSheetTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.quesivoNavy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.linkUserSheetHint,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.quesivoTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        QuesivoTextField(
                          hintText: l10n.registerEmailPlaceholder,
                          prefixIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !isBusy,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              MemberEmail.allowedChars,
                            ),
                          ],
                          errorText: _emailError
                              ? l10n.invalidEmailError
                              : null,
                          onChanged: (v) {
                            setState(() {
                              _email = v;
                              _emailError =
                                  v.isNotEmpty &&
                                  MemberEmail.dirty(v).isNotValid;
                            });
                            _clearBackendError();
                          },
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
                              onChanged: (role) {
                                setState(() {
                                  _role = role;
                                  _roleError = false;
                                });
                                _clearBackendError();
                              },
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
                        const SizedBox(height: 24),
                        // Par lado a lado en mitades iguales (mismo
                        // criterio del sheet de creación): negativa ghost
                        // iconSurface a la izquierda, primario amarillo a
                        // la derecha; ambos 64px StadiumBorder, gap 12px.
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
                                label: l10n.linkUserSubmit,
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
