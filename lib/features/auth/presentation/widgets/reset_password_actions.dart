import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../cubit/reset_password_cubit.dart';
import '../cubit/reset_password_state.dart';

/// Bloque inferior del reset password: pill "Actualizar contraseña"
/// (§primary_button) o spinner mientras el submit está `inProgress`;
/// debajo, el link "Volver al inicio de sesión" (§login_link).
///
/// El `BlocBuilder` repinta solo cuando cambian `status` o `isValid` — el
/// Cubit se resuelve por el `BlocProvider` de la pantalla.
class ResetPasswordActions extends StatelessWidget {
  const ResetPasswordActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
      buildWhen: (p, c) => p.status != c.status || p.isValid != c.isValid,
      builder: (context, state) {
        return state.status.isInProgress
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // --- Acción primaria (§primary_button:
                  // "Actualizar contraseña") ---
                  QuesivoPrimaryButton(
                    label: l10n.updatePasswordButton,
                    onPressed: state.isValid
                        ? () {
                            FocusScope.of(context).unfocus();
                            context.read<ResetPasswordCubit>().submit();
                          }
                        : null,
                  ),
                  const SizedBox(height: 40),

                  // --- Link a login (§login_link) ---
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go(AuthGuard.loginRoute),
                      child: Text(
                        l10n.backToLogin,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.quesivoYellow,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
      },
    );
  }
}
