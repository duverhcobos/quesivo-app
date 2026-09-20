import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/widgets/password_requirements_checklist.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../domain/value_objects/register_password.dart';
import '../cubit/reset_password_cubit.dart';
import '../cubit/reset_password_state.dart';

/// Campos del formulario de restablecimiento de contraseña
/// (§password_form): nueva contraseña + checklist vivo de requisitos +
/// confirmación con error de mismatch, en gap 16.
///
/// Cada `BlocBuilder` repinta solo su campo (`buildWhen` por VO) — el
/// Cubit se resuelve por el `BlocProvider` de la pantalla.
class ResetPasswordFormFields extends StatelessWidget {
  const ResetPasswordFormFields({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Nueva contraseña (§password_form.new_password) ---
        BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
          buildWhen: (p, c) => p.password != c.password,
          builder: (context, state) => QuesivoTextField(
            hintText: l10n.newPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegisterPassword.allowedChars),
            ],
            onChanged: (v) =>
                context.read<ResetPasswordCubit>().passwordChanged(v),
          ),
        ),
        const SizedBox(height: 16),
        // --- Requisitos (mismo checklist vivo que en register) ---
        BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
          buildWhen: (p, c) => p.password.value != c.password.value,
          builder: (context, state) => PasswordRequirementsChecklist(
            title: l10n.passwordReqTitle,
            items: [
              PasswordRequirementItem(
                met: RegisterPassword.hasMinLength(state.password.value),
                label: l10n.passwordReqMinLength,
              ),
              PasswordRequirementItem(
                met: RegisterPassword.hasUppercase(state.password.value),
                label: l10n.passwordReqUppercase,
              ),
              PasswordRequirementItem(
                met: RegisterPassword.hasLowercase(state.password.value),
                label: l10n.passwordReqLowercase,
              ),
              PasswordRequirementItem(
                met: RegisterPassword.hasDigit(state.password.value),
                label: l10n.passwordReqDigit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Confirmar contraseña (§password_form.confirm_password) ---
        BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
          buildWhen: (p, c) => p.confirmPassword != c.confirmPassword,
          builder: (context, state) => QuesivoTextField(
            hintText: l10n.confirmPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegisterPassword.allowedChars),
            ],
            onChanged: (v) =>
                context.read<ResetPasswordCubit>().confirmPasswordChanged(v),
            errorText: state.confirmPassword.displayError != null
                ? l10n.passwordsDoNotMatchError
                : null,
          ),
        ),
      ],
    );
  }
}
