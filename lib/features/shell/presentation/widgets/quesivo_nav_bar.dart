import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// Barra de navegación firma del shell post-auth (propuesta §shell-premium).
///
/// Lámina navy a ancho completo que reemplaza al `NavigationBar` de
/// Material — espejo del `ShellHeader`: esquinas superiores radius 20 y
/// cuerpo extendido hasta el borde inferior detrás de la barra de gestos
/// (`SafeArea` interno). Los 4 items comparten la misma celda fija con
/// ícono sobre label; el activo lo marca la **gota láctea** — segundo
/// elemento del imagotipo — apareciendo con fade+scale sobre el borde
/// superior, más su ícono+label en amarillo. Sin chip de fondo: la doble
/// señal amarilla era redundante (§34→1.5.2). La navegación no cambia:
/// mismo `navigationShell.currentIndex` + `goBranch`.
class QuesivoNavBar extends StatelessWidget {
  const QuesivoNavBar({super.key, required this.navigationShell});

  /// Shell de go_router: expone `currentIndex` y `goBranch` para los tabs.
  final StatefulNavigationShell navigationShell;

  /// Alto de la lámina de contenido — el total en pantalla es
  /// `height` + inset inferior del sistema (`SafeArea` interno). Las
  /// pantallas lo leen vía `context.shellNavBarHeight` (§39).
  static const double height = 74;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Cuando el SO pide reducir animaciones, el chip cambia de golpe.
    final animDuration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 250);

    // (ícono inactivo, ícono activo, label) — Inicio + los 3 módulos del
    // loop operativo diario (propuesta §35-tabs-modulos-diarios).
    final items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home, l10n.navHome),
      (Icons.water_drop_outlined, Icons.water_drop, l10n.moduleReception),
      (
        Icons.precision_manufacturing_outlined,
        Icons.precision_manufacturing,
        l10n.moduleProduction,
      ),
      (Icons.point_of_sale_outlined, Icons.point_of_sale, l10n.moduleSales),
    ];

    return Container(
      // Lámina navy a ancho completo — espejo del header: esquinas
      // superiores radius 20, sin márgenes, y extendida hasta el borde
      // inferior detrás de la barra de gestos (SafeArea dentro).
      decoration: const BoxDecoration(
        color: AppColors.quesivoNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.quesivoShadow,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: height,
          // Top 10: la gota del item activo respira — no queda pegando al
          // borde superior redondeado de la lámina.
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                _QuesivoNavItem(
                  icon: items[i].$1,
                  selectedIcon: items[i].$2,
                  label: items[i].$3,
                  isActive: i == navigationShell.currentIndex,
                  animDuration: animDuration,
                  onTap: () => navigationShell.goBranch(
                    i,
                    // Re-tap sobre el tab activo vuelve a la raíz del branch.
                    initialLocation: i == navigationShell.currentIndex,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item individual de la `QuesivoNavBar`.
///
/// Los 4 items comparten la misma celda fija y el mismo layout (ícono sobre
/// label) — lo único que cambia entre estados es el **color** (blanco 60% →
/// amarillo, animado con `TweenAnimationBuilder<Color?>`) y el ícono
/// outlined→filled. La gota láctea hace de marcador sobre el borde
/// superior. Sin chip ni glow: una sola señal amarilla, más limpia (§34).
class _QuesivoNavItem extends StatelessWidget {
  const _QuesivoNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isActive,
    required this.animDuration,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isActive;
  final Duration animDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Misma celda fija y mismo layout para los 4 items: solo cambia el
    // color (blanco 60% → amarillo) y el ícono outlined→filled. El chip de
    // fondo se retiró (§34→1.5.2) — con la gota marcando arriba, el fondo
    // amarillo era doble señal.
    final itemColor = isActive
        ? AppColors.quesivoYellow
        : AppColors.quesivoWhite.withValues(alpha: 0.6);

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: itemColor),
                  duration: animDuration,
                  builder: (context, color, child) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? selectedIcon : icon,
                          size: 22,
                          color: color,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // La gota láctea del imagotipo como marcador: aparece sobre el
              // borde superior del item activo (fade+scale), invisible en el
              // resto — ocupa el mismo espacio, cero layout shift.
              Positioned(
                top: 2,
                left: 0,
                right: 0,
                // Center obligatorio: sin él el Icon se alinea a la
                // izquierda del item, no centrado sobre el borde.
                child: Center(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: animDuration,
                      opacity: isActive ? 1 : 0,
                      child: AnimatedScale(
                        duration: animDuration,
                        scale: isActive ? 1 : 0.6,
                        curve: Curves.easeOutBack,
                        child: const Icon(
                          Icons.water_drop,
                          size: 10,
                          color: AppColors.quesivoYellow,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
