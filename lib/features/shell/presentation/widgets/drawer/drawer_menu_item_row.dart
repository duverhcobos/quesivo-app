import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';

/// `true` si [currentLocation] es [route] o una ruta hija suya
/// (`route/…`) — marca el módulo activo en el drawer.
bool isDrawerModuleRouteActive(String currentLocation, String route) =>
    currentLocation == route || currentLocation.startsWith('$route/');

/// Fila de módulo/acción del `QuesivoDrawer` — ícono 22 + gap 14 + label
/// 15px w500 `Expanded` + chevron_right `quesivoPlaceholder` 20.
///
/// La fila queda habilitada si recibe [onTap] o [route]: con [route] navega
/// con `router.push` tras cerrar el drawer (GoRouter se captura antes del
/// pop, mismo patrón que Inicio/logout); si ambos son `null` queda
/// deshabilitada (Opacity 0.45 y sin chevron) hasta que su feature aterrice.
/// [color] tiñe ícono y label (logout lo usa en `quesivoError`) y
/// [showChevron] permite quitar el chevron en acciones habilitadas que no
/// son navegación a una pantalla (logout).
class DrawerMenuItemRow extends StatelessWidget {
  const DrawerMenuItemRow({
    super.key,
    required this.icon,
    required this.label,
    this.route,
    this.onTap,
    this.color = AppColors.quesivoNavy,
    this.showChevron = true,
    this.selected = false,
  });

  final IconData icon;
  final String label;

  /// Ruta destino del módulo (`AuthGuard.*Route`). Si viene, la fila navega
  /// sola: cierra el drawer y hace `go` — desde §35 los módulos son rutas
  /// top-level dentro de las branches del shell, y solo `go` cambia de
  /// branch (`push` apila sin mover `currentIndex` → el tab no se
  /// marcaba). `go` además construye el stack completo del match, así en
  /// rutas hijas (`/home/organizacion`) el back sigue funcionando.
  final String? route;

  final VoidCallback? onTap;
  final Color color;
  final bool showChevron;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap =
        onTap ??
        (route == null
            ? null
            : () {
                // GoRouter se resuelve antes del pop — cerrado el drawer,
                // su contexto queda desactivado para lookups (mismo
                // criterio que Inicio/logout).
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(route!);
              });

    final effectiveColor = selected ? AppColors.quesivoNavy : color;

    // Semantics: anuncia botón + estado seleccionado a TalkBack (la navbar
    // ya lo hace; el drawer estaba mudo).
    final row = Semantics(
      button: effectiveOnTap != null,
      selected: selected,
      label: label,
      child: Material(
        // El fondo `surface` solo aparece cuando la fila está seleccionada;
        // `transparent` deja que el InkWell pinte el ripple igual.
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(selected ? 14 : 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: BorderRadius.circular(selected ? 14 : 8),
          // La pastilla se "enciende" suave: color, radius y padding
          // transicionan juntos al cambiar `selected`.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              // Padding horizontal solo en la pastilla seleccionada.
              horizontal: selected ? 16 : 0,
              vertical: selected ? 14 : 12,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.quesivoSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(selected ? 14 : 8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.quesivoYellow : color,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: effectiveColor,
                    ),
                  ),
                ),
                if (showChevron && effectiveOnTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.quesivoPlaceholder,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Deshabilitada: opaca y sin chevron — mismo criterio que los tiles de
    // módulos pendientes de feature.
    if (effectiveOnTap == null) {
      return Opacity(opacity: 0.45, child: row);
    }
    return row;
  }
}
