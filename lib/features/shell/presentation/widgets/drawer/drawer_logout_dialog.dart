import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import 'drawer_brand_decoration.dart';

/// Diálogo de confirmación de logout del `QuesivoDrawer` — tarjeta blanca
/// radius 16 con el lenguaje del design system (nada del AlertDialog
/// genérico del tema): el círculo amarillo con huecos de queso asomando
/// por la esquina superior-derecha (el mismo `DrawerBrandDecoration` del
/// drawer — el elemento firma de marca recortado por el borde de la
/// tarjeta), círculo `quesivoError` al 12% con `Icons.logout` error 28,
/// título navy 18 w700, mensaje secondary 14 centrado, botón destructivo
/// `quesivoError` a ancho completo y "Cancelar" como TextButton secondary
/// debajo — acciones apiladas, deliberadas.
class DrawerLogoutDialog extends StatelessWidget {
  const DrawerLogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: AppColors.quesivoWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Firma de marca: la porción de queso asoma por la esquina
            // superior-derecha — la misma decoración recortada del drawer,
            // que hace el diálogo reconocible como Quesivo.
            const Positioned(
              top: -36,
              right: -36,
              child: DrawerBrandDecoration(
                diameter: 100,
                color: AppColors.quesivoYellow,
                withCheeseHoles: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícono de la acción en círculo tenido — misma técnica del
                  // avatar/íconos del menú (superficie suave + ícono fuerte).
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.quesivoError.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.logout,
                      size: 28,
                      color: AppColors.quesivoError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.logoutConfirmTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.quesivoNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.logoutConfirmMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.quesivoTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Acción destructiva a ancho completo — el protagonista del
                  // diálogo; debajo la salida segura como texto.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.quesivoError,
                        foregroundColor: AppColors.quesivoWhite,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        l10n.logoutConfirmAction,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n.cancelAction,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.quesivoTextSecondary,
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
