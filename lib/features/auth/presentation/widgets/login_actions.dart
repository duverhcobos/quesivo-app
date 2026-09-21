import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import 'auth_divider.dart';
import 'auth_prompt.dart';
import 'google_auth_button.dart';

/// Bloque inferior del login: botón primario (§primary_button) o spinner
/// mientras submit está `inProgress`, divisor (§social_divider), botón
/// Google (§google_login) y link a registro (§register_prompt).
///
/// El `BlocBuilder` repinta solo cuando cambian `status` o `isValid`.
class LoginActions extends StatelessWidget {
  const LoginActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<LoginCubit, LoginState>(
      buildWhen: (p, c) => p.status != c.status || p.isValid != c.isValid,
      builder: (context, state) {
        return state.status.isInProgress
            ? Center(
                child: QuesivoLoader(
                  size: 28,
                  semanticLabel: l10n.loadingLabel,
                ),
              )
            : Column(
                children: [
                  // --- Acción primaria (§primary_button: pill amarillo) ---
                  QuesivoPrimaryButton(
                    label: l10n.loginButton,
                    onPressed: state.isValid
                        ? () {
                            FocusScope.of(context).unfocus();
                            context.read<LoginCubit>().submit();
                          }
                        : null,
                  ),
                  const SizedBox(height: 28),

                  // --- Divisor (§social_divider) ---
                  AuthDivider(text: l10n.loginDivider),
                  const SizedBox(height: 22),

                  // --- Google (§google_login: pill blanco) ---
                  GoogleAuthButton(
                    label: l10n.continueWithGoogle,
                    onPressed: () =>
                        context.read<AuthCubit>().loginWithGoogle(),
                  ),
                  const SizedBox(height: 26),

                  // --- Link a registro (§register_prompt) ---
                  AuthPrompt(
                    text: l10n.noAccountPrompt,
                    linkText: l10n.signUpLink,
                    onTap: () => context.push(AuthGuard.registerRoute),
                  ),
                  const SizedBox(height: 20),
                ],
              );
      },
    );
  }
}
