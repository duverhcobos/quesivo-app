import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';
import '../widgets/auth_heading.dart';
import '../widgets/forgot_password_actions.dart';
import '../widgets/forgot_password_form.dart';
import '../widgets/quesivo_brand_header.dart';

/// Pantalla de Recuperación de Contraseña QUESIVO
/// (quesivo-design-system.yaml §forgot_password).
///
/// SOLID (SRP): Dumb View — solo lee `ForgotPasswordState` y repinta. El
/// Cubit llega por constructor (resuelto por `AppRouter` vía DI factory).
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key, required this.cubit});

  /// Cubit de formulario resuelto por `AppRouter` vía DI (factory) — la
  /// pantalla no conoce el Service Locator (DIP).
  final ForgotPasswordCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ForgotPasswordCubit>(
      create: (context) => cubit,
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatelessWidget {
  const _ForgotPasswordView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Mismo criterio que register/login: solo el círculo amarillo.
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ?? l10n.forgotPasswordGenericError,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
            // Al éxito no hay snackbar ni pop: la sección inferior se
            // reemplaza por la info card "Revisa tu correo" (ver
            // ForgotPasswordActions).
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // --- Imagen de marca (~62% ancho, §brand_header) ---
                  const QuesivoBrandHeader(logoFraction: 0.62),

                  // --- Heading + descripción (§forgot_password_heading) ---
                  AuthHeading(
                    title: l10n.forgotPassword,
                    description: l10n.forgotPasswordInstructions,
                    titleHeight: 1.05,
                    titleGap: 16,
                    descriptionColor: AppColors.quesivoTextSecondary,
                    descriptionMaxLines: 3,
                    descriptionHeight: 1.45,
                  ),

                  // --- Campo email (§email_form) ---
                  const ForgotPasswordForm(),
                  const SizedBox(height: 36),

                  // --- Sección inferior: botón → card de confirmación ---
                  // Antes de enviar: pill "Enviar enlace". En progreso:
                  // spinner. Tras envío exitoso: info card "Revisa tu
                  // correo" como estado de confirmación (sin snackbar/pop).
                  const ForgotPasswordActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
