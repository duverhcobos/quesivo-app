import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import 'auth_divider.dart';
import 'auth_prompt.dart';
import 'google_auth_button.dart';
import 'quesivo_primary_button.dart';

/// Bloque inferior del registro: botón primario (§primary_button) o spinner
/// mientras submit está `inProgress`, divisor (§social_divider), botón
/// Google (§google_register) y link a login (§login_prompt).
///
/// El `BlocBuilder` repinta solo cuando cambian `status` o `isValid`.
class RegisterActions extends StatelessWidget {
  const RegisterActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) => p.status != c.status || p.isValid != c.isValid,
      builder: (context, state) {
        return state.status.isInProgress
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  QuesivoPrimaryButton(
                    label: l10n.createAccountButton,
                    onPressed: state.isValid
                        ? () {
                            FocusScope.of(context).unfocus();
                            context.read<RegisterCubit>().submit();
                          }
                        : null,
                  ),
                  const SizedBox(height: 28),

                  // --- Divisor (§social_divider) ---
                  AuthDivider(text: l10n.registerDivider),
                  const SizedBox(height: 22),

                  // --- Google (§google_register) ---
                  GoogleAuthButton(
                    label: l10n.continueWithGoogle,
                    onPressed: () =>
                        context.read<AuthCubit>().loginWithGoogle(),
                  ),
                  const SizedBox(height: 26),

                  // --- Link a login (§login_prompt) ---
                  AuthPrompt(
                    text: l10n.alreadyHaveAccount,
                    linkText: l10n.signInLink,
                    onTap: () => context.push(AuthGuard.loginRoute),
                  ),
                  const SizedBox(height: 20),
                ],
              );
      },
    );
  }
}
