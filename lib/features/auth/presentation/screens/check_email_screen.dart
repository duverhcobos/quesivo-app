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
import '../../../../core/widgets/quesivo_toast.dart';
import '../cubit/check_email_cubit.dart';
import '../cubit/check_email_state.dart';
import '../widgets/auth_heading.dart';
import '../widgets/forgot_password_info_card.dart';
import '../widgets/quesivo_brand_header.dart';

/// Pantalla "Revisa tu correo" (verificación pendiente — propuesta 67 /
/// backend 069): destino tras registrarse, tras un login con correo sin
/// verificar, o cuando un link de verificación falla. Reenvía el correo
/// con el email que llegó por query param.
///
/// SOLID (SRP): Dumb View — solo lee `CheckEmailState` y repinta. El
/// Cubit llega por constructor (resuelto por `AppRouter` vía DI factory).
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, required this.cubit});

  /// Cubit resuelto por `AppRouter` vía DI (factory) — la pantalla no
  /// conoce el Service Locator (DIP).
  final CheckEmailCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CheckEmailCubit>(
      create: (context) => cubit,
      child: const _CheckEmailView(),
    );
  }
}

class _CheckEmailView extends StatelessWidget {
  const _CheckEmailView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<CheckEmailCubit, CheckEmailState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isFailure) {
              QuesivoToast.error(
                context,
                message: state.errorMessage ?? l10n.genericAuthError,
              );
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

                  AuthHeading(
                    title: l10n.checkEmailTitle,
                    description: l10n.verifyEmailSentDescription,
                    titleHeight: 1.05,
                    titleGap: 16,
                    descriptionColor: AppColors.quesivoTextSecondary,
                    descriptionMaxLines: 4,
                    descriptionHeight: 1.45,
                  ),

                  // --- Card con el email destino (§information_card,
                  //     mismo widget que forgot — es genérica) ---
                  const SizedBox(height: 8),
                  BlocBuilder<CheckEmailCubit, CheckEmailState>(
                    buildWhen: (p, c) => p.email != c.email,
                    builder: (context, state) => ForgotPasswordInfoCard(
                      title: l10n.checkEmailTitle,
                      description: state.email,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- Acciones: reenviar + volver al login ---
                  BlocBuilder<CheckEmailCubit, CheckEmailState>(
                    buildWhen: (p, c) => p.status != c.status,
                    builder: (context, state) {
                      if (state.status.isInProgress) {
                        return Center(
                          child: QuesivoLoader(
                            size: 28,
                            semanticLabel: l10n.loadingLabel,
                          ),
                        );
                      }
                      return Column(
                        children: [
                          if (state.status.isSuccess)
                            ForgotPasswordInfoCard(
                              title: l10n.resendVerificationSuccessTitle,
                              description:
                                  l10n.resendVerificationSuccessDescription,
                            )
                          else
                            QuesivoPrimaryButton(
                              label: l10n.resendVerificationButton,
                              onPressed: () =>
                                  context.read<CheckEmailCubit>().resend(),
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
