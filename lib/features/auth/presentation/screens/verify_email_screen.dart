import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/verify_email_cubit.dart';
import '../cubit/verify_email_state.dart';
import '../widgets/auth_heading.dart';
import '../widgets/forgot_password_info_card.dart';
import '../widgets/quesivo_brand_header.dart';

/// Pantalla verify-email — destino del deep link
/// `quesivo://verify-email?token=…&email=…` (propuesta 67 / backend 069).
/// Verifica al entrar; éxito → la sesión ya está guardada y
/// `refreshSession()` hace que el AuthGuard rute a /home (auto-login).
///
/// SOLID (SRP): Dumb View — solo lee `VerifyEmailState` y repinta.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, required this.cubit});

  /// Cubit resuelto por `AppRouter` vía DI (factory, params token+email).
  final VerifyEmailCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VerifyEmailCubit>(
      // La verificación arranca sola al crear el cubit — una sola vez.
      create: (context) => cubit..verify(),
      child: const _VerifyEmailView(),
    );
  }
}

class _VerifyEmailView extends StatelessWidget {
  const _VerifyEmailView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<VerifyEmailCubit, VerifyEmailState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isSuccess) {
              // Auto-login: el repo ya guardó la sesión; el cubit global
              // confirma y el AuthGuard rutea a /home (token personal).
              context.read<AuthCubit>().refreshSession();
            }
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  const QuesivoBrandHeader(logoFraction: 0.62),

                  BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
                    builder: (context, state) {
                      // --- Verificando / éxito (spinner — el éxito sale
                      //     de la pantalla vía guard enseguida) ---
                      if (!state.status.isFailure) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AuthHeading(
                              title: l10n.verifyEmailVerifyingTitle,
                              description: l10n.verifyEmailVerifyingDescription,
                              titleHeight: 1.05,
                              titleGap: 16,
                              descriptionColor: AppColors.quesivoTextSecondary,
                              descriptionMaxLines: 3,
                              descriptionHeight: 1.45,
                            ),
                            const SizedBox(height: 48),
                            Center(
                              child: QuesivoLoader(
                                size: 32,
                                semanticLabel: l10n.loadingLabel,
                              ),
                            ),
                          ],
                        );
                      }

                      // --- Link inválido/expirado ---
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuthHeading(
                            title: l10n.verifyEmailInvalidTitle,
                            description:
                                state.errorMessage ??
                                    l10n.verifyEmailInvalidDescription,
                            titleHeight: 1.05,
                            titleGap: 16,
                            descriptionColor: AppColors.quesivoTextSecondary,
                            descriptionMaxLines: 4,
                            descriptionHeight: 1.45,
                          ),
                          const SizedBox(height: 36),
                          if (state.resendStatus.isInProgress)
                            Center(
                              child: QuesivoLoader(
                                size: 28,
                                semanticLabel: l10n.loadingLabel,
                              ),
                            )
                          else if (state.resendStatus.isSuccess)
                            ForgotPasswordInfoCard(
                              title: l10n.resendVerificationSuccessTitle,
                              description:
                                  l10n.resendVerificationSuccessDescription,
                            )
                          else if (state.email.isNotEmpty)
                            QuesivoPrimaryButton(
                              label: l10n.resendVerificationButton,
                              onPressed: () =>
                                  context.read<VerifyEmailCubit>().resend(),
                            ),
                          const SizedBox(height: 40),
                          Center(
                            child: GestureDetector(
                              onTap: () => context.go(AuthGuard.loginRoute),
                              child: Text(
                                l10n.signInLink,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.quesivoYellow,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
