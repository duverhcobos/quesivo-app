import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';

/// Pantalla placeholder genérica de los módulos del drawer
/// (propuesta §26-modulos-placeholder).
///
/// Mientras cada feature real aterriza, las 17 rutas de módulo
/// (`AuthGuard.*Route` a nivel raíz) pintan esta pantalla: ícono + label del
/// módulo centrados con el subtítulo `l10n.moduleComingSoon`, back
/// arriba-izquierda (`context.pop()` — los módulos entran por `push`, así
/// siempre hay a dónde volver).
///
/// Fondo: `QuesivoBackdrop` sin animación con el círculo amarillo superior
/// achicado (0.5 del ancho) y sin el navy inferior-izquierdo; en su lugar un
/// arco navy parcialmente fuera del canvas abajo-derecha — mismo criterio de
/// decoración del `QuesivoDrawer` a pantalla completa.
///
/// Cuando un módulo real se implemente, su `GoRoute` reemplaza al placeholder
/// conservando la misma ruta — el drawer no se vuelve a tocar.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({
    super.key,
    required this.icon,
    required this.label,
  });

  /// Ícono del módulo (el mismo que muestra su fila en el drawer).
  final IconData icon;

  /// Nombre visible del módulo (ya resuelto vía `AppLocalizations`).
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        topCircleFraction: 0.5,
        bottomCircleFraction: 0,
        animate: false,
        child: Stack(
          children: [
            // Arco navy abajo-derecha, parcialmente fuera del canvas —
            // misma técnica que la decoración del QuesivoDrawer
            // (Positioned negativo + ClipOval + ColoredBox plano).
            Positioned(
              bottom: -screenWidth * 0.275,
              right: -screenWidth * 0.275,
              child: ClipOval(
                child: ColoredBox(
                  color: AppColors.quesivoNavy,
                  child: SizedBox(
                    width: screenWidth * 0.55,
                    height: screenWidth * 0.55,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back arriba-izquierda solo cuando hay algo que popear:
                  // los módulos que son raíz de tab (recepción/producción/
                  // ventas, §35) no tienen ruta debajo — `context.pop()`
                  // ahí lanzaría GoException. El SizedBox conserva el aire.
                  if (context.canPop())
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.quesivoNavy,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Círculo de ícono — mismo surface que los tiles
                          // de accesos rápidos del home.
                          Container(
                            width: 88,
                            height: 88,
                            decoration: const BoxDecoration(
                              color: AppColors.quesivoIconSurface,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              icon,
                              size: 44,
                              color: AppColors.quesivoNavy,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.quesivoNavy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.moduleComingSoon,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.quesivoTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
