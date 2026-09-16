import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Utilidad centralizada para animaciones de transición en GoRouter.
///
/// SOLID (Principio de Responsabilidad Única - SRP):
/// El AppRouter no debería saber *cómo* se anima una pantalla, solo saber *qué* pantalla cargar.
/// Delegamos la "fabricación" de la animación a esta clase.
///
/// SOLID (Principio Abierto/Cerrado - OCP):
/// Si mañana necesitas un Slide, Scale o Rotation, simplemente añades un método
/// aquí sin necesidad de tocar la configuración central del Router.
class CustomTransitions {
  /// Transición suave de desvanecimiento (Fade In)
  static CustomTransitionPage fade({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(
      milliseconds: 500,
    ), // 0.5 segundos para que se note
  }) {
    return CustomTransitionPage(
      key: state
          .pageKey, // Importante para que Flutter identifique el cambio de página
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Transición de aparición desde abajo hacia arriba (Slide Up)
  static CustomTransitionPage slideUp({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0); // Abajo
        const end = Offset.zero; // Centro
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }
}
