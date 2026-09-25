import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/password_requirements_checklist.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/value_objects/register_password.dart';
import '../cubit/accept_invite_cubit.dart';
import '../cubit/accept_invite_state.dart';
import '../cubit/auth_cubit.dart';
import '../widgets/auth_heading.dart';
import '../widgets/forgot_password_info_card.dart';
import '../widgets/quesivo_brand_header.dart';

/// Pantalla accept-invite — destino del deep link
/// `quesivo://accept-invite?token=…&email=…` (propuesta 68 — Email-C,
/// backend 070 / doc 017). El invitado define su contraseña; el POST
/// hace auto-login (la sesión ya quedó guardada por el repositorio) y
/// `refreshSession()` hace que el AuthGuard rute a /home.
///
/// SOLID (SRP): Dumb View — solo lee `AcceptInviteState` y repinta. El
/// Cubit llega por constructor (resuelto por `AppRouter` vía DI factory)
/// con `token`+`email` del query ya dentro.
class AcceptInviteScreen extends StatelessWidget {
  const AcceptInviteScreen({super.key, required this.cubit});

  /// Cubit resuelto por `AppRouter` vía DI (factory, params token+email).
  final AcceptInviteCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AcceptInviteCubit>(
      // Sin llamada al entrar — el submit espera el password del invitado.
      create: (context) => cubit,
      child: const _AcceptInviteView(),
    );
  }
}

class _AcceptInviteView extends StatelessWidget {
  const _AcceptInviteView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Mismo criterio que el resto de auth: solo el círculo amarillo.
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<AcceptInviteCubit, AcceptInviteState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isSuccess) {
              // Auto-login: el repo ya guardó la sesión; el cubit global
              // confirma y el AuthGuard rutea a /home (token personal).
              context.read<AuthCubit>().refreshSession();
            } else if (state.status.isFailure &&
                state.errorMessage !=
                    const InvalidOrExpiredTokenFailure().message) {
              // Error de submit no-token: toast + el form queda para
              // reintentar (el de token pasa a la vista de link
              // inválido — esa vista ES el feedback, sin toast).
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

                  BlocBuilder<AcceptInviteCubit, AcceptInviteState>(
                    builder: (context, state) {
                      // Link inválido: failure de token (submit o link
                      // ya consumido) o deep link que llegó sin token.
                      final invalidLink =
                          !context.read<AcceptInviteCubit>().hasToken ||
                          (state.status.isFailure &&
                              state.errorMessage ==
                                  const InvalidOrExpiredTokenFailure().message);
                      return invalidLink
                          ? const _InvalidLinkView()
                          : const _PasswordFormView();
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

/// Form del invitado: heading con el email del query + nueva contraseña
/// + checklist vivo + confirmación (mismos VOs/formatters de
/// reset-password) + pill "Crear contraseña y entrar".
class _PasswordFormView extends StatelessWidget {
  const _PasswordFormView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocBuilder<AcceptInviteCubit, AcceptInviteState>(
          buildWhen: (p, c) => p.email != c.email,
          builder: (context, state) => AuthHeading(
            title: l10n.acceptInviteTitle,
            description: l10n.acceptInviteDescription(state.email),
            titleHeight: 1.05,
            titleGap: 16,
            descriptionColor: AppColors.quesivoPlaceholder,
          ),
        ),

        // --- Nueva contraseña (mismo shape que §password_form) ---
        BlocBuilder<AcceptInviteCubit, AcceptInviteState>(
          buildWhen: (p, c) => p.password != c.password,
          builder: (context, state) => QuesivoTextField(
            hintText: l10n.newPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegisterPassword.allowedChars),
            ],
            onChanged: (v) =>
                context.read<AcceptInviteCubit>().passwordChanged(v),
          ),
        ),
        const SizedBox(height: 16),
        // --- Requisitos (mismo checklist vivo que en reset/register) ---
        BlocBuilder<AcceptInviteCubit, AcceptInviteState>(
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

        // --- Confirmar contraseña ---
        BlocBuilder<AcceptInviteCubit, AcceptInviteState>(
          buildWhen: (p, c) => p.confirmPassword != c.confirmPassword,
          builder: (context, state) => QuesivoTextField(
            hintText: l10n.confirmPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegisterPassword.allowedChars),
            ],
            onChanged: (v) =>
                context.read<AcceptInviteCubit>().confirmPasswordChanged(v),
            errorText: state.confirmPassword.displayError != null
                ? l10n.passwordsDoNotMatchError
                : null,
          ),
        ),
        const SizedBox(height: 36),

        // --- Acción primaria / spinner ---
        BlocBuilder<AcceptInviteCubit, AcceptInviteState>(
          buildWhen: (p, c) => p.status != c.status || p.isValid != c.isValid,
          builder: (context, state) {
            return state.status.isInProgress
                ? Center(
                    child: QuesivoLoader(
                      size: 28,
                      semanticLabel: l10n.loadingLabel,
                    ),
                  )
                : QuesivoPrimaryButton(
                    label: l10n.acceptInviteButton,
                    onPressed: state.isValid
                        ? () {
                            FocusScope.of(context).unfocus();
                            context.read<AcceptInviteCubit>().submit();
                          }
                        : null,
                  );
          },
        ),
      ],
    );
  }
}

/// Vista de link inválido/expirado — espejo de la de verify-email:
/// heading, "Pedir link nuevo" (solo con email en el query) o loader o
/// card de confirmación tras el reenvío, y link a login.
class _InvalidLinkView extends StatelessWidget {
  const _InvalidLinkView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthHeading(
          title: l10n.acceptInviteInvalidTitle,
          // El `errorMessage` del failure es genérico del flujo de
          // reset ("…desde ¿Olvidaste tu contraseña?") — acá el copy
          // correcto es el del invite.
          description: l10n.acceptInviteInvalidDescription,
          titleHeight: 1.05,
          titleGap: 16,
          descriptionColor: AppColors.quesivoTextSecondary,
          descriptionMaxLines: 4,
          descriptionHeight: 1.45,
        ),
        const SizedBox(height: 36),
        BlocBuilder<AcceptInviteCubit, AcceptInviteState>(
          buildWhen: (p, c) =>
              p.resendStatus != c.resendStatus || p.email != c.email,
          builder: (context, state) {
            if (state.resendStatus.isInProgress) {
              return Center(
                child: QuesivoLoader(
                  size: 28,
                  semanticLabel: l10n.loadingLabel,
                ),
              );
            }
            if (state.resendStatus.isSuccess) {
              return ForgotPasswordInfoCard(
                title: l10n.resendVerificationSuccessTitle,
                description: l10n.resendVerificationSuccessDescription,
              );
            }
            if (state.email.isNotEmpty) {
              return QuesivoPrimaryButton(
                label: l10n.acceptInviteResendButton,
                onPressed: () => context.read<AcceptInviteCubit>().resend(),
              );
            }
            return const SizedBox.shrink();
          },
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
  }
}
