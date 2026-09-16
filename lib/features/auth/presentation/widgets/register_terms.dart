import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';

/// Checkbox de términos y condiciones del registro
/// (§terms_and_conditions): casilla navy + texto legal con links amarillos.
class RegisterTermsCheckbox extends StatelessWidget {
  const RegisterTermsCheckbox({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) => p.termsAccepted != c.termsAccepted,
      builder: (context, state) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: state.termsAccepted,
              onChanged: (v) =>
                  context.read<RegisterCubit>().termsToggled(v ?? false),
              activeColor: AppColors.quesivoNavy,
              checkColor: AppColors.quesivoWhite,
              side: const BorderSide(
                color: AppColors.quesivoPlaceholder,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            // Los links son decorativos por ahora: las páginas
            // legales todavía no existen (pendiente de producto).
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: AppColors.quesivoDarkText,
                ),
                children: [
                  TextSpan(text: l10n.termsPrefix),
                  TextSpan(
                    text: l10n.termsLink,
                    style: const TextStyle(
                      color: AppColors.quesivoYellow,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: l10n.termsConnector),
                  TextSpan(
                    text: l10n.privacyLink,
                    style: const TextStyle(
                      color: AppColors.quesivoYellow,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
