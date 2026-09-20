import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/password_requirements_checklist.dart';
import '../../../../core/widgets/quesivo_close_button.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/value_objects/temp_password.dart';

/// Sheet de reset de contraseña por admin (§45) — mini-form con un solo
/// campo, mismo contenedor y convenciones que `NewUserSheet` (§44 +
/// fixes 1.9.x). Devuelve el password ingresado o `null` al cancelar —
/// la integración de `PATCH /auth/users/:id/password` lo manda al
/// backend tal cual (el reset además levanta el lockout del email,
/// doc 010).
///
/// La política vive en el VO `TempPassword` (min 8, mayúscula,
/// minúscula, dígito — misma del backend) — el checklist y el submit
/// consumen sus predicados (§47 fix de auditoría: antes regexes
/// espejo locales).
class ResetPasswordSheet extends StatefulWidget {
  const ResetPasswordSheet({super.key, required this.member});

  final OrgMember member;

  /// Abre el sheet y devuelve la contraseña nueva, o `null` si se
  /// canceló.
  ///
  /// [topInset]: borde inferior del hero navy — tope del sheet con el
  /// teclado abierto (mismo patrón que NewUserSheet.show).
  static Future<String?> show(
    BuildContext context,
    OrgMember member, {
    double topInset = 0,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      // Modal sobre el navigator RAÍZ — cubre el QuesivoNavBar del shell
      // (sin esto la barra queda pintada encima del sheet, bug §44 fix).
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.quesivoWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - topInset,
      ),
      builder: (_) => ResetPasswordSheet(member: member),
    );
  }

  @override
  State<ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<ResetPasswordSheet> {
  String _password = '';
  bool _passwordError = false;

  void _submit() {
    setState(() => _passwordError = TempPassword.dirty(_password).isNotValid);
    if (_passwordError) return;
    Navigator.of(context).pop(_password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                  const Align(
                    alignment: Alignment.centerRight,
                    child: QuesivoCloseButton(),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
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
                  // Visible a propósito — igual que en la creación: el
                  // admin la inventa y se la dicta al usuario.
                  QuesivoTextField(
                    hintText: l10n.newPasswordPlaceholder,
                    prefixIcon: Icons.lock_outline,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        TempPassword.allowedChars,
                      ),
                    ],
                    errorText: _passwordError
                        ? l10n.invalidTempPasswordError
                        : null,
                    onChanged: (v) => setState(() {
                      _password = v;
                      _passwordError = false;
                    }),
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
                  // Par 1:1 — misma piel que NewUserSheet: ghost a la
                  // izquierda, primario amarillo a la derecha.
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.quesivoIconSurface,
                            foregroundColor: AppColors.quesivoNavy,
                            elevation: 0,
                            minimumSize: const Size(0, 64),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
