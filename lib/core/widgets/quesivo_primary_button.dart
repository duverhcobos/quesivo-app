import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pill amarillo 64px/18/w700 de marca (§primary_button) — botón primario
/// compartido por auth y los módulos, con estado disabled atenuado.
///
/// `onPressed` en `null` deja el botón deshabilitado (amarillo/navy
/// atenuados al 45%/50%).
class QuesivoPrimaryButton extends StatelessWidget {
  const QuesivoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
    this.isLoading = false,
    this.isSuccess = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// `true`: el label se reemplaza por un spinner navy y el botón queda
  /// deshabilitado — el alto de 64px se conserva (no salta el layout).
  final bool isLoading;

  /// `true`: el label se reemplaza por un check navy — tercer estado de
  /// un submit async (respuesta OK mostrada un instante dentro del botón
  /// antes de que el contenedor reaccione/cierre). También deshabilita.
  final bool isSuccess;

  /// `true` (default): el botón toma todo el ancho disponible — patrón de
  /// auth. `false`: abraza al label — para pares de acciones lado a lado
  /// en sheets (el primario no debería estirarse a medio form).
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: (isLoading || isSuccess) ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.quesivoYellow,
        foregroundColor: AppColors.quesivoNavy,
        disabledBackgroundColor: AppColors.quesivoYellow.withValues(
          alpha: 0.45,
        ),
        disabledForegroundColor: AppColors.quesivoNavy.withValues(alpha: 0.5),
        elevation: 0,
        // El alto lo fija el botón mismo — así la variante hug-content no
        // necesita un SizedBox de ancho, que dentro de un Row sin límites
        // fuerza width:∞ y crashea (bug visto en físico).
        minimumSize: const Size(0, 64),
        // 16px: en los CTAs full-width el padding es invisible (texto
        // centrado) y en los pares 1:1 le da aire al label en la mitad.
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      // scaleDown: en pares 1:1 (sheets) un label largo como
      // "Actualizar contraseña" no entra en la mitad a 18px — escala en
      // vez de envolver a 2 líneas y romper la simetría del par.
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.quesivoNavy,
              ),
            )
          : isSuccess
          ? const Icon(
              Icons.check_rounded,
              size: 26,
              color: AppColors.quesivoNavy,
            )
          : FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
