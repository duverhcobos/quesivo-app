import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../../core/widgets/password_requirements_checklist.dart';
import '../../../../../core/widgets/quesivo_text_field.dart';
import '../../../domain/value_objects/temp_password.dart';

/// Sección "Contraseña manual" del `NewUserSheet` (extraída en §68 por
/// la regla de tamaño — el sheet ganó el toggle de modo): el campo de
/// contraseña temporal VISIBLE a propósito (el admin la inventa y la
/// dicta al usuario — ocultarla solo generaría typos) + el checklist
/// vivo evaluado con los predicados del VO `TempPassword`.
///
/// Stateless: el texto lo guarda el sheet vía `onChanged` (como el
/// resto del form — `QuesivoTextField` no es controlado).
class ManualPasswordSection extends StatelessWidget {
  const ManualPasswordSection({
    super.key,
    required this.enabled,
    required this.password,
    required this.hasError,
    required this.onChanged,
  });

  /// `false` mientras el submit está en vuelo — congela el campo.
  final bool enabled;

  /// Valor actual de la contraseña (vive en el State del sheet) —
  /// alimenta el checklist vivo.
  final String password;

  /// Error de validación al submit — el `invalidTempPasswordError` del
  /// campo. El checklist vivo ya es el aviso en vivo (§47): el flag
  /// solo se levanta en `_submit`.
  final bool hasError;

  /// El State del sheet guarda el valor y limpia el error de backend.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tempPassword = TempPassword.dirty(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuesivoTextField(
          hintText: l10n.tempPasswordPlaceholder,
          prefixIcon: Icons.lock_outline,
          enabled: enabled,
          inputFormatters: [
            FilteringTextInputFormatter.allow(TempPassword.allowedChars),
          ],
          errorText: hasError ? l10n.invalidTempPasswordError : null,
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        // Checklist vivo (mismo de registro/reset) — evalúa los
        // predicados del VO TempPassword de dominio.
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
      ],
    );
  }
}
