import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../../core/routes/auth_guard.dart';
import '../../../../../core/theme/app_colors.dart';
import '../user_initials_avatar.dart';

/// Tarjeta de identidad del `QuesivoDrawer` — el único bloque navy sólido
/// del menú: `UserInitialAvatar` (mismo avatar de iniciales del header) +
/// nombre / quesera / chip de rol del usuario
/// + chevron que la marca como accionable. `displayName` ya viene resuelto
/// por el drawer (nombre real o fallback localizado).
///
/// Tocarla cierra el drawer y lleva a `AuthGuard.orgDataRoute` (Datos de
/// la organización — el destino de perfil más cercano hoy; cuando exista
/// una pantalla de perfil real, solo se repunta esta ruta).
class DrawerIdentity extends StatelessWidget {
  const DrawerIdentity({super.key, required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppColors.quesivoNavy,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // GoRouter se resuelve antes del pop — cerrado el drawer, su
            // contexto queda desactivado para lookups (mismo criterio que
            // Inicio/logout).
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push(AuthGuard.orgDataRoute);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Mismo avatar de iniciales del ShellHeader — 56px/18
                // acá, sin anillo (ya va sobre la tarjeta navy).
                UserInitialAvatar(
                  displayName: displayName,
                  size: 56,
                  fontSize: 18,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.quesivoWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // Placeholder de la quesera — la org real
                        // llega con el backend.
                        l10n.orgName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.quesivoWhite.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.quesivoYellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          // Rol fijo del MVP — único rol hoy.
                          l10n.adminRole,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.quesivoNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Chevron de affordance — la tarjeta es accionable.
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.quesivoWhite.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
