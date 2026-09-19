import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Botón ✕ de marca — círculo navy 40px con `Icons.close` blanco 22;
/// cierra con `Navigator.pop`. Nació como `DrawerCloseButton` del
/// `QuesivoDrawer` (mismo tamaño que la hamburguesa del `ShellHeader`)
/// y se movió a core/widgets al necesitarlo también el `NewUserSheet`
/// — mismo criterio que `QuesivoTextField`/`PasswordRequirementsChecklist`.
class QuesivoCloseButton extends StatelessWidget {
  const QuesivoCloseButton({super.key, this.enabled = true});

  /// `false`: sin tap y atenuado — los sheets lo usan para bloquear el
  /// cierre mientras un submit está en vuelo.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: AppColors.quesivoNavy,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Ripple circular — mismo criterio que la hamburguesa del header.
          customBorder: const CircleBorder(),
          onTap: enabled ? () => Navigator.of(context).pop() : null,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.close, size: 22, color: AppColors.quesivoWhite),
          ),
        ),
      ),
    );
  }
}
