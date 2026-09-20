import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/widgets/quesivo_text_field.dart';
import '../../domain/value_objects/email.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';

/// Campo email del formulario de recuperación de contraseña (§email_form).
///
/// El `BlocBuilder` repinta solo cuando cambia el VO `email` — el Cubit se
/// resuelve por el `BlocProvider` de la pantalla.
class ForgotPasswordForm extends StatelessWidget {
  const ForgotPasswordForm({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // --- Campo email (§email_form) ---
    return BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
      buildWhen: (p, c) => p.email != c.email,
      builder: (context, state) => QuesivoTextField(
        hintText: l10n.registerEmailPlaceholder,
        prefixIcon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
        inputFormatters: [
          FilteringTextInputFormatter.allow(Email.allowedChars),
        ],
        onChanged: (v) => context.read<ForgotPasswordCubit>().emailChanged(v),
        errorText: state.email.displayError != null
            ? l10n.invalidEmailError
            : null,
      ),
    );
  }
}
