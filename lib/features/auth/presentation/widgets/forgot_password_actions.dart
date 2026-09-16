import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/constants/environment/environment.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';
import 'forgot_password_info_card.dart';
import 'quesivo_primary_button.dart';

/// Bloque inferior del forgot password: pill "Enviar enlace"
/// (§primary_button) o spinner mientras submit está `inProgress`; tras un
/// envío exitoso, la info card "Revisa tu correo" (§information_card)
/// reemplaza al botón como estado de confirmación (sin snackbar ni pop).
/// Debajo van el link apilado a login (§login_prompt) y el acceso temporal
/// a reset solo en `EnvType.dev`.
///
/// El `BlocBuilder` repinta solo cuando cambian `status` o `isValid`.
class ForgotPasswordActions extends StatelessWidget {
  const ForgotPasswordActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
      buildWhen: (p, c) => p.status != c.status || p.isValid != c.isValid,
      builder: (context, state) {
        if (state.status.isInProgress) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            if (state.status.isSuccess)
              // --- Info card (§information_card) — solo tras envío ---
              ForgotPasswordInfoCard(
                title: l10n.checkEmailTitle,
                description: l10n.checkEmailDescription,
              )
            else
              // --- Acción primaria (§primary_button: "Enviar enlace") ---
              QuesivoPrimaryButton(
                label: l10n.sendResetLinkButton,
                onPressed: state.isValid
                    ? () {
                        FocusScope.of(context).unfocus();
                        context.read<ForgotPasswordCubit>().submit();
                      }
                    : null,
              ),
            const SizedBox(height: 40),

            // --- Link a login (§login_prompt, apilado) ---
            Center(
              child: Column(
                children: [
                  Text(
                    l10n.rememberedPassword,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.quesivoTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(AuthGuard.loginRoute),
                    child: Text(
                      l10n.signInLink,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.quesivoYellow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ⚠️ ACCESO TEMPORAL DE DESARROLLO: hasta que el
            // deep link del correo exista (backend), la pantalla
            // de reset solo se alcanza por este botón — jamás
            // se renderiza fuera de `dev`.
            if (Environment.currentEnvironment == EnvType.dev)
              TextButton(
                onPressed: () =>
                    context.push('${AuthGuard.resetPasswordRoute}?token=dev'),
                child: Text(l10n.devResetLink),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
