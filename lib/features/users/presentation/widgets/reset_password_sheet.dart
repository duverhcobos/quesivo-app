import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/password_requirements_checklist.dart';
import '../../../../core/widgets/quesivo_close_button.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/failures/users_failure.dart';
import '../../domain/value_objects/temp_password.dart';
import '../cubit/reset_password_cubit.dart';
import '../cubit/reset_password_state.dart';

/// Sheet de reset de contraseña por admin (§45, integrado en §52) —
/// mini-form con un solo campo, mismo contenedor y convenciones que
/// `NewUserSheet`/`LinkUserSheet`. El submit pega a
/// `PATCH /auth/users/:id/password` real vía `ResetPasswordCubit`
/// (registerFactory: muere con el sheet; el reset además revoca las
/// sesiones del target en esta org y levanta el lockout, doc 010) y
/// devuelve por `Navigator.pop` el `OrgMember` del 200 — no cambia a
/// la vista, la pantalla solo muestra el toast de éxito.
///
/// La política vive en el VO `TempPassword` (min 8, mayúscula,
/// minúscula, dígito — misma del backend) — el checklist y el submit
/// consumen sus predicados (§47 fix de auditoría: antes regexes
/// espejo locales). El error del backend sale por `QuesivoToast.error`
/// sobre el overlay raíz con el sheet abierto para reintentar, y en
/// éxito el check del botón queda visible ~500ms antes del pop — mismo
/// feedback que creación/vinculación.
class ResetPasswordSheet extends StatefulWidget {
  const ResetPasswordSheet({super.key, required this.member});

  final OrgMember member;

  /// Abre el sheet y devuelve el miembro que respondió el backend en el
  /// 200, o `null` si se canceló/falló. [cubit] es seam de tests — en
  /// producción se resuelve por `locator`.
  ///
  /// [topInset]: borde inferior del hero navy — tope del sheet con el
  /// teclado abierto (mismo patrón que NewUserSheet.show).
  static Future<OrgMember?> show(
    BuildContext context,
    OrgMember member, {
    double topInset = 0,
    ResetPasswordCubit? cubit,
  }) {
    return showModalBottomSheet<OrgMember>(
      context: context,
      // Modal sobre el navigator RAÍZ — cubre el QuesivoNavBar del shell
      // (sin esto la barra queda pintada encima del sheet, bug §44 fix).
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
        create: (_) => cubit ?? locator<ResetPasswordCubit>(),
        child: ResetPasswordSheet(member: member),
      ),
    );
  }

  @override
  State<ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<ResetPasswordSheet> {
  /// Pausa de confirmación antes de cerrar: el usuario ve el check del
  /// botón dentro del sheet (mismo ~500ms del sheet de creación).
  static const _successDismissDelay = Duration(milliseconds: 500);

  String _password = '';
  bool _passwordError = false;

  void _submit() {
    setState(() => _passwordError = TempPassword.dirty(_password).isNotValid);
    if (_passwordError) return;
    context.read<ResetPasswordCubit>().submit(
      userId: widget.member.id,
      password: _password,
    );
  }

  String _failureText(AppLocalizations l10n, UsersFailure? failure) =>
      switch (failure) {
        // Las reglas OWNER_*/MEMBERSHIP_NOT_FOUND son defensivas — la
        // card del dueño y la propia no muestran ⋮, y una membresía
        // stale solo llega si otro cliente la tocó primero.
        OwnerPasswordResetFailure() => l10n.ownerPasswordResetError,
        MemberNotFoundFailure() => l10n.memberNotFoundError,
        InvalidMemberDataFailure() => l10n.invalidTempPasswordError,
        UsersForbiddenFailure() => l10n.usersForbiddenError,
        UsersRateLimitFailure() => l10n.tooManyAttemptsError,
        UsersNetworkFailure() => l10n.networkError,
        _ => l10n.genericError,
      };

  /// Editar el campo limpia el error del backend stale — sin esto el
  /// mensaje persiste sobre el dato ya corregido.
  void _clearBackendError() => context.read<ResetPasswordCubit>().resetStatus();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Fuera del BlocConsumer: la zona fija (✕) y el PopScope también
    // necesitan saber si hay submit en vuelo o pausa de éxito activa.
    final isBusy = context.select<ResetPasswordCubit, bool>(
      (c) => c.state.status.isInProgress || c.state.status.isSuccess,
    );
    return PopScope(
      // Bloquea scrim-tap, drag-down y back durante el submit Y la
      // pausa de éxito: cerrar antes pierde el resultado (el reset pudo
      // haberse aplicado sin que la UI lo sepa) y emitir sobre el cubit
      // ya cerrado lanza StateError. El pop retardado del listener no
      // lo frena canPop — Navigator.pop no consulta popDisposition.
      canPop: !isBusy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        // Zona fija (handle + ✕) + scroll del form — idéntico a
        // NewUserSheet: Flexible, no Expanded, mide al contenido.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              child: BlocConsumer<ResetPasswordCubit, ResetPasswordState>(
                listenWhen: (p, c) =>
                    p.status != c.status &&
                    (c.status.isSuccess || c.status.isFailure),
                listener: (context, state) {
                  if (state.status.isFailure) {
                    // Error del backend → toast rojo sobre el overlay
                    // raíz (flota por encima del sheet): el form queda
                    // abierto para corregir y reintentar.
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
                  // queda visible antes de devolver el miembro del 200.
                  final member = state.resetMember;
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
                          l10n.resetPasswordAction,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.quesivoNavy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.resetPasswordSheetHint(widget.member.name),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.quesivoTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Visible a propósito — igual que en la
                        // creación: el admin la inventa y se la dicta
                        // al usuario.
                        QuesivoTextField(
                          hintText: l10n.newPasswordPlaceholder,
                          prefixIcon: Icons.lock_outline,
                          enabled: !isBusy,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              TempPassword.allowedChars,
                            ),
                          ],
                          errorText: _passwordError
                              ? l10n.invalidTempPasswordError
                              : null,
                          onChanged: (v) {
                            setState(() {
                              _password = v;
                              _passwordError = false;
                            });
                            _clearBackendError();
                          },
                        ),
                        const SizedBox(height: 12),
                        PasswordRequirementsChecklist(
                          title: l10n.passwordReqTitle,
                          items: [
                            PasswordRequirementItem(
                              met: TempPassword.dirty(_password).hasMinLength,
                              label: l10n.passwordReqMinLength,
                            ),
                            PasswordRequirementItem(
                              met: TempPassword.dirty(_password).hasUppercase,
                              label: l10n.passwordReqUppercase,
                            ),
                            PasswordRequirementItem(
                              met: TempPassword.dirty(_password).hasLowercase,
                              label: l10n.passwordReqLowercase,
                            ),
                            PasswordRequirementItem(
                              met: TempPassword.dirty(_password).hasDigit,
                              label: l10n.passwordReqDigit,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Par 1:1 — misma piel que NewUserSheet: ghost
                        // a la izquierda, primario amarillo a la derecha.
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
                                label: l10n.updatePasswordButton,
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
