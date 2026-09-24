// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/auth_heading.dart';
import '../widgets/login_actions.dart';
import '../widgets/login_form_fields.dart';
import '../widgets/quesivo_brand_header.dart';

/// Pantalla de Login QUESIVO (quesivo-design-system.yaml §login).
///
/// SOLID (SRP): Dumb View — solo lee `LoginState` y repinta. El Cubit
/// local llega por constructor (resuelto por `AppRouter` vía DI factory);
/// la sesión la maneja el `AuthCubit` global vía `checkSession()`.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.cubit});

  /// Cubit de formulario resuelto por `AppRouter` vía DI (factory) — la
  /// pantalla no conoce el Service Locator (DIP).
  final LoginCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginCubit>(
      create: (context) => cubit,
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Mismo criterio que register: solo el círculo amarillo con huecos;
        // el navy inferior se omite para no competir con el form.
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
            BlocListener<LoginCubit, LoginState>(
              listenWhen: (previous, current) =>
                  previous.status != current.status,
              listener: (context, state) {
                if (state.status.isFailure) {
                  QuesivoToast.error(
                    context,
                    message: state.errorMessage ?? l10n.genericAuthError,
                  );
                } else if (state.status.isSuccess) {
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
                  const SizedBox(height: 48),

                  // --- Imagen de marca (~65% ancho, §brand_header) ---
                  const QuesivoBrandHeader(logoFraction: 0.65),

                  // --- Heading + descripción (§login_heading, a la izquierda
                  //     como register — decisión del usuario sobre el spec) ---
                  AuthHeading(
                    title: l10n.loginTitle,
                    description: l10n.loginDescription,
                  ),

                  // --- Formulario (§login_form) ---
                  const LoginFormFields(),
                  const SizedBox(height: 24),

                  // --- Acción primaria (§primary_button: pill amarillo 64px) ---
                  const LoginActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
