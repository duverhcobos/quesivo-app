import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';

/// Splash Screen — primer instante de la identidad visual QUESIVO
/// (quesivo-design-system.yaml §8 pages.splash).
///
/// Composición: fondo blanco, imagotipo centrado como único foco (~70% del
/// ancho), círculo amarillo con huecos de queso arriba a la derecha y círculo
/// navy abajo a la izquierda, ambos parcialmente fuera del canvas.
/// Sin texto de carga ni spinner — el logo es el foco con espacio negativo.
///
/// Vive en su propio mini-feature (`features/splash/`): es la entrada de la
/// app, no una pantalla de autenticación. Solo depende de `AuthCubit` para
/// disparar la verificación de sesión inicial.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Desencadenamos la verificación de sesión cuando el splash se monta;
    // AuthGuard resuelve el redirect cuando el Cubit emite.
    context.read<AuthCubit>().checkSession();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        child: Align(
          // El logo va levemente sobre el centro geométrico (~45% de alto),
          // como en la referencia aprobada del design system.
          alignment: const Alignment(0, -0.15),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            // El imagotipo es la última pieza de la coreografía: permanece
            // oculto la primera mitad del timeline y entra cuando el círculo
            // amarillo va a la mitad de su transición (ver kQuesivoEntryDuration).
            duration: reduceMotion ? Duration.zero : kQuesivoEntryDuration,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.9 + (0.1 * value),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/images/imagotipo_quesivo.png',
              width: screenWidth,
              semanticLabel: 'QUESIVO',
            ),
          ),
        ),
      ),
    );
  }
}
