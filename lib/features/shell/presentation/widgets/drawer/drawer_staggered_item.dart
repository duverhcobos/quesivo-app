import 'package:flutter/material.dart';

/// Envoltorio de entrada escalonada del `DrawerMenuList` — cada ítem del
/// menú aparece con fade + slide-up de 12px en una ventana `Interval`
/// propia según su [index], así el menú "cae" en cascada al abrirse el
/// drawer. La animación completa del controller es ~600ms con un paso de
/// ~30ms entre ítems.
class DrawerStaggeredItem extends StatelessWidget {
  const DrawerStaggeredItem({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  /// Controller del `DrawerMenuList` (0 → 1 al abrirse el drawer).
  final Animation<double> animation;

  /// Posición del ítem en la lista — determina su `Interval` de entrada.
  final int index;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Ventana propia del ítem dentro del controller: arranca en
    // index*0.045 y dura 0.4 — los últimos ítems terminan junto al 1.0.
    final begin = (index * 0.045).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(
        begin,
        (begin + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
