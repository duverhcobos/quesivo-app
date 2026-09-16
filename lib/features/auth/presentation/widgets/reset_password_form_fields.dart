import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../cubit/reset_password_cubit.dart';
import '../cubit/reset_password_state.dart';
import 'password_requirements_checklist.dart';
import 'quesivo_auth_field.dart';

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
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.newPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            onChanged: (v) =>
                context.read<ResetPasswordCubit>().passwordChanged(v),
          ),
        ),
        const SizedBox(height: 16),
        // --- Requisitos (mismo checklist vivo que en register) ---
        BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
          buildWhen: (p, c) => p.password.value != c.password.value,
          builder: (context, state) => PasswordRequirementsChecklist(
            password: state.password.value,
            title: l10n.passwordReqTitle,
            minLengthLabel: l10n.passwordReqMinLength,
            uppercaseLabel: l10n.passwordReqUppercase,
            lowercaseLabel: l10n.passwordReqLowercase,
            digitLabel: l10n.passwordReqDigit,
          ),
        ),
        const SizedBox(height: 16),

        // --- Confirmar contraseña (§password_form.confirm_password) ---
        BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
          buildWhen: (p, c) => p.confirmPassword != c.confirmPassword,
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.confirmPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
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
