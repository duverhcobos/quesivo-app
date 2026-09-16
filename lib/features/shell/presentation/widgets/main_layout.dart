import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import 'quesivo_drawer.dart';
import 'quesivo_nav_bar.dart';
import 'shell_header.dart';

/// Layout persistente post-auth (propuestas §shell-premium +
/// §header-navy-avatar + §drawer-cuenta): `ShellHeader` navy de identidad
/// arriba + `QuesivoNavBar` flotante abajo + `QuesivoDrawer` como
/// endDrawer (cuenta/logout, se abre desde la hamburguesa del header).
/// Recibe el `navigationShell` de go_router — no conoce rutas concretas
/// (SRP). Es `StatefulWidget` solo para recordar el índice anterior del
/// tab y dar dirección al slide de transición (derecha↔izquierda según
/// el sentido del cambio).
class MainLayout extends StatefulWidget {
  const MainLayout({super.key, required this.navigationShell});

  /// Shell de go_router: expone `currentIndex` y `goBranch` para los tabs.
  final StatefulNavigationShell navigationShell;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  /// Índice del build anterior — permite saber hacia dónde se movió el tab
  /// para la dirección del slide.
  int _previousIndex = 0;

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final index = navigationShell.currentIndex;

    // Dirección del slide: tab a la derecha → el contenido entra desde la
    // derecha (offset +x → 0); tab a la izquierda → desde la izquierda.
    final direction = index >= _previousIndex ? 1.0 : -1.0;
    _previousIndex = index;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      endDrawer: const QuesivoDrawer(),
      body: Column(
        children: [
          const ShellHeader(),
          // El header ya consumió el inset superior con su SafeArea; se lo
          // retiro a las tabs para que sus SafeArea internos no dupliquen
          // el espacio bajo la banda navy.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              // Slide direccional + fade al cambiar de tab: la `key` en
              // currentIndex reinicia el tween; el shell va como `child`
              // (no se reconstruye — las branches conservan stack y
              // scroll), solo repintan FractionalTranslation y Opacity. Un
              // solo tween maneja ambos: la opacidad cae del desplazamiento
              // restante. Con animaciones off, duración 0.
              child: TweenAnimationBuilder<Offset>(
                key: ValueKey(index),
                tween: Tween(
                  begin: Offset(0.15 * direction, 0),
                  end: Offset.zero,
                ),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, offset, child) => FractionalTranslation(
                  translation: offset,
                  child: Opacity(
                    opacity: 1 - (offset.dx.abs() / 0.15),
                    child: child,
                  ),
                ),
                child: navigationShell,
              ),
            ),
          ),
        ],
      ),
      // Transparente: la `QuesivoNavBar` ya trae su propio fondo navy,
      // margen y sombra — el Scaffold solo le reserva el slot inferior.
      bottomNavigationBar: QuesivoNavBar(navigationShell: navigationShell),
    );
  }
}
