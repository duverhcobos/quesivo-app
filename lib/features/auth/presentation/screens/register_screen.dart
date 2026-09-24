// lib/features/auth/presentation/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import '../widgets/auth_heading.dart';
import '../widgets/quesivo_brand_header.dart';
import '../widgets/register_actions.dart';
import '../widgets/register_form_fields.dart';
import '../widgets/register_terms.dart';

/// Pantalla de Registro QUESIVO (quesivo-design-system.yaml §register).
///
/// SOLID (SRP): Dumb View — solo lee `RegisterState` y repinta. El Cubit
/// local se crea por factory en cada ingreso; la sesión resultante la
/// maneja el `AuthCubit` global vía `checkSession()`.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, required this.cubit});

  /// Cubit de formulario resuelto por `AppRouter` vía DI (factory) — la
  /// pantalla no conoce el Service Locator (DIP).
  final RegisterCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RegisterCubit>(
      create: (context) => cubit,
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Spec §register.decorative_elements: solo el círculo amarillo ~34%
        // arriba a la derecha (con huecos de queso); el navy inferior se
        // omite para no competir con el form (mismo criterio que onboarding).
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: MultiBlocListener(
          listeners: [
            BlocListener<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthError) {
                  QuesivoToast.error(context, message: state.message);
                }
              },
            ),
            BlocListener<RegisterCubit, RegisterState>(
              listenWhen: (previous, current) =>
                  previous.status != current.status,
              listener: (context, state) {
                if (state.status.isFailure) {
                  QuesivoToast.error(
                    context,
                    message: state.errorMessage ?? l10n.genericAuthError,
                  );
                } else if (state.status.isSuccess) {
                  // Auto-login: la sesión ya quedó guardada por el repo;
                  // el cubit global confirma y AuthGuard rutea a /home.
                  context.read<AuthCubit>().refreshSession();
                }
              },
            ),
          ],
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compensa el alto que ocupaba el botón volver (~48px) para
                  // que el imagotipo conserve su posición vertical.
                  const SizedBox(height: 48),

                  // --- Imagen de marca (~65% ancho, §brand_header) ---
                  const QuesivoBrandHeader(logoFraction: 0.65),

                  // --- Heading + descripción (§register_heading) ---
                  AuthHeading(
                    title: l10n.registerTitle,
                    description: l10n.registerDescription,
                  ),

                  // --- Formulario (§register_form, gap 16-18) ---
                  const RegisterFormFields(),

                  // --- Términos (§terms_and_conditions) ---
                  const SizedBox(height: 16),
                  const RegisterTermsCheckbox(),
                  const SizedBox(height: 24),

                  // --- Acción primaria (§primary_button: pill amarillo 64px) ---
                  const RegisterActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
