import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';

/// Row de acciones de la pantalla welcome: "Iniciar Sesión" (amarillo,
/// push a login) y "Registrarse" (blanco, push a register) — §welcome.
class WelcomeActions extends StatelessWidget {
  const WelcomeActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        // Botón primario: Iniciar Sesión (amarillo, texto navy)
        Expanded(
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: () => context.push(AuthGuard.loginRoute),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.quesivoYellow,
                foregroundColor: AppColors.quesivoNavy,
                elevation: 0,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l10n.welcomeSignIn),
            ),
          ),
        ),
        const SizedBox(width: 18),
        // Botón secundario: Registrarse (blanco, texto navy)
        Expanded(
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: () => context.push(AuthGuard.registerRoute),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.quesivoWhite,
                foregroundColor: AppColors.quesivoNavy,
                elevation: 0,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l10n.welcomeSignUp),
            ),
          ),
        ),
      ],
    );
  }
}
