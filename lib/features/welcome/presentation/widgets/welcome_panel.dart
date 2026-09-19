import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Panel navy inferior de la pantalla de bienvenida
/// (quesivo-design-system.yaml §welcome.welcome_panel).
///
/// Esquinas superiores redondeadas 30px, ancho completo, pegado al borde
/// inferior. Flat 2D: sin sombras, sin bordes, sin degradados.
class WelcomePanel extends StatelessWidget {
  const WelcomePanel({
    super.key,
    required this.title,
    required this.description,
    required this.actions,
  });

  final String title;
  final String description;

  /// Fila de botones (ej. "Iniciar Sesión" + "Registrarse").
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.quesivoNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width * 0.08,
            vertical: MediaQuery.sizeOf(context).height * 0.035,
          ),
          // SingleChildScrollView: en pantallas bajas o con fuente de
          // accesibilidad grande el contenido scrollea en vez de
          // desbordar el Expanded (overflow de 3.7px visto en físico).
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: AppColors.quesivoWhite,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                    color: AppColors.quesivoWhite.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 30),
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
