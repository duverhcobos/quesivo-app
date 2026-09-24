import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../cubit/reset_password_cubit.dart';
import '../cubit/reset_password_state.dart';
import '../widgets/auth_heading.dart';
import '../widgets/quesivo_brand_header.dart';
import '../widgets/reset_password_actions.dart';
import '../widgets/reset_password_form_fields.dart';

/// Pantalla de Restablecimiento de Contraseña QUESIVO
/// (quesivo-design-system.yaml §reset_password).
///
/// SOLID (SRP): Dumb View — solo lee `ResetPasswordState` y repinta. El Cubit
/// llega por constructor (resuelto por `AppRouter` vía DI factory) con el
/// `token` del deep link ya dentro.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key, required this.cubit});

  final ResetPasswordCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ResetPasswordCubit>(
      create: (context) => cubit,
      child: const _ResetPasswordView(),
    );
  }
}

class _ResetPasswordView extends StatelessWidget {
  const _ResetPasswordView();

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
        child: BlocListener<ResetPasswordCubit, ResetPasswordState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status.isFailure) {
              QuesivoToast.error(
                context,
                message: state.errorMessage ?? l10n.genericAuthError,
              );
            } else if (state.status.isSuccess) {
              QuesivoToast.success(
                context,
                message: l10n.passwordUpdatedSuccess,
              );
              // Spec destinations.success → login (reemplaza la pila:
              // no se puede "volver" al formulario de reset).
              context.go(AuthGuard.loginRoute);
            }
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // --- Imagen de marca (~55% ancho, §brand_header) ---
                  const QuesivoBrandHeader(logoFraction: 0.55),

                  // --- Heading + descripción (§reset_heading, izquierda) ---
                  AuthHeading(
                    title: l10n.resetTitle,
                    description: l10n.resetDescription,
                    titleHeight: 1.05,
                    titleGap: 16,
                    descriptionColor: AppColors.quesivoPlaceholder,
                  ),

                  // --- Campos del formulario (§password_form) ---
                  const ResetPasswordFormFields(),
                  const SizedBox(height: 36),

                  // --- Sección inferior: botón / spinner + link a login ---
                  const ResetPasswordActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
