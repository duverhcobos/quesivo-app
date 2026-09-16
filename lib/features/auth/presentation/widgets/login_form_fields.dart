import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import 'quesivo_auth_field.dart';

/// Campos del formulario de login (§login_form, gap 16) más el link
/// "¿Olvidaste tu contraseña?" (§forgot_password, alineado a la derecha).
///
/// Cada `BlocBuilder` repinta solo su campo (`buildWhen` por VO) — el Cubit
/// se resuelve por el `BlocProvider` de la pantalla.
class LoginFormFields extends StatelessWidget {
  const LoginFormFields({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Email (§login_form.email) ---
        BlocBuilder<LoginCubit, LoginState>(
          buildWhen: (p, c) => p.email != c.email,
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.registerEmailPlaceholder,
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => context.read<LoginCubit>().emailChanged(v),
            errorText: state.email.displayError != null
                ? l10n.invalidEmailError
                : null,
          ),
        ),
        const SizedBox(height: 16),

        // --- Password (§login_form.password) ---
        BlocBuilder<LoginCubit, LoginState>(
          buildWhen: (p, c) => p.password != c.password,
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.registerPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            onChanged: (v) => context.read<LoginCubit>().passwordChanged(v),
            errorText: state.password.displayError != null
                ? l10n.invalidPasswordError
                : null,
          ),
        ),

        // --- ¿Olvidaste tu contraseña? (§forgot_password, right) ---
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => context.push(AuthGuard.forgotPasswordRoute),
            child: Text(
              l10n.forgotPassword,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.quesivoYellow,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.quesivoYellow,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
