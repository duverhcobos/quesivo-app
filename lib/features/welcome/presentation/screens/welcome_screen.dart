import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/welcome_actions.dart';
import '../widgets/welcome_brand_area.dart';
import '../widgets/welcome_panel.dart';

/// Pantalla de bienvenida QUESIVO (quesivo-design-system.yaml §welcome).
///
/// Presenta la marca y ofrece dos acciones de autenticación: iniciar sesión
/// o registrarse. Sin Cubit — es UI pura sin estado de negocio.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: Column(
        children: [
          // --- Área de marca (61% superior) ---
          const WelcomeBrandArea(),
          // --- Panel navy (39% inferior) ---
          Expanded(
            child: WelcomePanel(
              title: l10n.welcomeTitle,
              description: l10n.welcomeDescription,
              actions: const WelcomeActions(),
            ),
          ),
        ],
      ),
    );
  }
}
