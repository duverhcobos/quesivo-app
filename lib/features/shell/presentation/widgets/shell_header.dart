import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_initials_avatar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import 'drawer/drawer_brand_decoration.dart';

/// Banda navy de identidad del shell post-auth
/// (propuesta 33-header-v2).
///
/// El header deja de mostrar el título del tab — ese contexto baja al
/// cuerpo de cada pantalla vía `TabPageTitle` y lo refuerza el chip del
/// nav. Acá va la identidad: avatar circular amarillo con las iniciales
/// del usuario, el nombre arriba y la organización debajo, más la
/// hamburguesa dentro de un círculo de borde blanco 20% que abre el
/// `QuesivoDrawer` (endDrawer del Scaffold) a la derecha. Consume el
/// inset superior con `SafeArea`, lleva la firma de marca — la porción
/// de queso `DrawerBrandDecoration` asomando recortada por la esquina
/// superior-derecha — y cierra con esquinas inferiores redondeadas 20;
/// el `Divider` desaparece porque el borde curvo ya delimita la banda.
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    // Solo nombre + org interesan: `select` evita reconstruir el header por
    // cualquier otro cambio del AuthState.
    final userName = context.select<AuthCubit, String?>(
      (cubit) => cubit.state is AuthSuccess
          ? (cubit.state as AuthSuccess).user.name
          : null,
    );
    final organizationName = context.select<AuthCubit, String?>(
      (cubit) => cubit.state is AuthSuccess
          ? (cubit.state as AuthSuccess).user.organizationName
          : null,
    );

    final trimmedName = userName?.trim() ?? '';
    final displayName = trimmedName.isNotEmpty ? trimmedName : l10n.orgName;

    // La organización real llega en el JWT/perfil (propuesta 36) — el
    // placeholder localizado solo cubre respuestas legacy sin org.
    final trimmedOrgName = organizationName?.trim() ?? '';
    final displayOrgName = trimmedOrgName.isNotEmpty
        ? trimmedOrgName
        : l10n.orgName;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: ColoredBox(
        color: AppColors.quesivoNavy,
        child: Stack(
          children: [
            // Firma de marca — la porción de queso asoma recortada por la
            // esquina superior-derecha, detrás del contenido (misma técnica
            // del drawer y del diálogo de logout).
            const Positioned(
              top: -36,
              right: -36,
              child: DrawerBrandDecoration(
                diameter: 96,
                color: AppColors.quesivoYellow,
                withCheeseHoles: true,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.075,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // Avatar con iniciales — es identidad, ya no abre el
                    // menú. El anillo blanco 20% separa el círculo del
                    // navy (la tarjeta del drawer no lo lleva).
                    UserInitialAvatar(displayName: displayName, withRing: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.quesivoWhite,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayOrgName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.quesivoWhite.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Trigger del QuesivoDrawer: `Scaffold.of` resuelve el
                    // Scaffold del MainLayout (este header está debajo en el
                    // árbol) y abre el menú lateral desde la derecha. El
                    // círculo de borde blanco 20% es hermana del ✕ navy del
                    // drawer, en versión sobre navy.
                    Material(
                      color: Colors.transparent,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: AppColors.quesivoWhite.withValues(alpha: 0.2),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        // Ripple circular — sin customBorder el splash
                        // saldría cuadrado dentro del círculo.
                        customBorder: const CircleBorder(),
                        onTap: () => Scaffold.of(context).openEndDrawer(),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.menu,
                            size: 22,
                            color: AppColors.quesivoWhite.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
