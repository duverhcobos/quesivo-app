import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import 'password_requirements_checklist.dart';
import 'quesivo_auth_field.dart';

/// Los 5 campos del formulario de registro (§register_form, gap 16) más el
/// checklist vivo de requisitos entre password y confirmación.
///
/// Cada `BlocBuilder` repinta solo su campo (`buildWhen` por VO) — el Cubit
/// se resuelve por el `BlocProvider` de la pantalla.
class RegisterFormFields extends StatelessWidget {
  const RegisterFormFields({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // La quesera va primero: es la entidad que se registra
        // (organización = tenant principal del SaaS).
        BlocBuilder<RegisterCubit, RegisterState>(
          buildWhen: (p, c) => p.organizationName != c.organizationName,
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.orgNamePlaceholder,
            prefixIcon: Icons.storefront_outlined,
            onChanged: (v) =>
                context.read<RegisterCubit>().organizationNameChanged(v),
            errorText: state.organizationName.displayError != null
                ? l10n.invalidOrgNameError
                : null,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<RegisterCubit, RegisterState>(
          buildWhen: (p, c) => p.fullName != c.fullName,
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.fullNamePlaceholder,
            prefixIcon: Icons.person_outline,
            onChanged: (v) => context.read<RegisterCubit>().fullNameChanged(v),
            errorText: state.fullName.displayError != null
                ? l10n.invalidFullNameError
                : null,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<RegisterCubit, RegisterState>(
          buildWhen: (p, c) => p.email != c.email,
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.registerEmailPlaceholder,
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => context.read<RegisterCubit>().emailChanged(v),
            errorText: state.email.displayError != null
                ? l10n.invalidEmailError
                : null,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<RegisterCubit, RegisterState>(
          buildWhen: (p, c) => p.password != c.password,
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.registerPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            onChanged: (v) => context.read<RegisterCubit>().passwordChanged(v),
            // Sin errorText: el checklist vivo de abajo ya comunica
            // cada requisito — el mensaje genérico sería redundante.
          ),
        ),
        const SizedBox(height: 16),
        // --- Requisitos de contraseña (checklist vivo) ---
        BlocBuilder<RegisterCubit, RegisterState>(
          buildWhen: (p, c) => p.password.value != c.password.value,
          builder: (context, state) => PasswordRequirementsChecklist(
            password: state.password.value,
            title: l10n.passwordReqTitle,
            minLengthLabel: l10n.passwordReqMinLength,
            uppercaseLabel: l10n.passwordReqUppercase,
            lowercaseLabel: l10n.passwordReqLowercase,
            digitLabel: l10n.passwordReqDigit,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<RegisterCubit, RegisterState>(
          buildWhen: (p, c) => p.confirmPassword != c.confirmPassword,
          builder: (context, state) => QuesivoAuthField(
            hintText: l10n.confirmPasswordPlaceholder,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            onChanged: (v) =>
                context.read<RegisterCubit>().confirmPasswordChanged(v),
            errorText: state.confirmPassword.displayError != null
                ? l10n.passwordsDoNotMatchError
                : null,
          ),
        ),
      ],
    );
  }
}
