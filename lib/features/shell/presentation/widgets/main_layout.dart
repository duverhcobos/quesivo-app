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
/// §39: el body es un `Stack` edge-to-edge — la hija pinta a pantalla
/// completa detrás del chrome y reserva sus insets con
/// `context.shellHeaderHeight` / `context.shellNavBarHeight`
/// (shell_insets.dart); así un hero navy puede fusionarse con la banda y
/// las esquinas redondeadas del chrome revelan el fondo de la propia
/// pantalla, no el del Scaffold.
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
      // El teclado NO desplaza el chrome: con el default (true) el body se
      // encoge con viewInsets y el Positioned(bottom: 0) del QuesivoNavBar
      // sube flotando sobre el teclado (bug visto en físico). Con false el
      // nav queda donde está y el teclado lo cubre — las pantallas siguen
      // scrolleables y los formularios viven en sheets con useRootNavigator
      // + viewInsets propios, que no dependen de este resize.
      resizeToAvoidBottomInset: false,
      // §39 — Stack edge-to-edge: la hija pinta a pantalla completa y
      // reserva sus insets con shell_insets; el header y el nav flotan
      // encima. Ya no se remueve el padding superior del MediaQuery: las
      // pantallas lo necesitan para calcular shellHeaderHeight.
      body: Stack(
        children: [
          // Slide direccional + fade al cambiar de tab — mismo tween que
          // antes, ahora deslizando el contenido bajo el chrome navy.
          Positioned.fill(
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
          const Positioned(top: 0, left: 0, right: 0, child: ShellHeader()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: QuesivoNavBar(navigationShell: navigationShell),
          ),
        ],
      ),
    );
  }
}
