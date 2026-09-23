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
/// del usuario y el nombre (§58 — solo el nombre: la quesera activa la
/// comunica la hero card del Inicio, no el chrome), más la hamburguesa
/// dentro de un círculo de borde blanco 20% que abre el
/// `QuesivoDrawer` (endDrawer del Scaffold) a la derecha. Consume el
/// inset superior con `SafeArea`, lleva la firma de marca — la porción
/// de queso `DrawerBrandDecoration` asomando recortada por la esquina
/// superior-derecha — y cierra con esquinas inferiores redondeadas 20;
/// el `Divider` desaparece porque el borde curvo ya delimita la banda.
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key});

  /// Alto del contenido navy (sin el inset del status bar): avatar 44 +
  /// margen vertical 12×2. Fijado con `SizedBox` en el build para que
  /// `context.shellHeaderHeight` (§39) sea exacto en todo dispositivo.
  /// §42: 76→68 — el margen inferior de la banda se sumaba al aire de la
  /// fila del título del módulo y dejaba un vacío navy entre la
  /// identidad y el título (feedback del usuario: "se desorganizó el
  /// header"); con 12×2 la cabecera vuelve a leerse como una unidad.
  static const double contentHeight = 68;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    // Solo el nombre interesa: `select` evita reconstruir el header por
    // cualquier otro cambio del AuthState.
    final userName = context.select<AuthCubit, String?>(
      (cubit) => cubit.state is AuthSuccess
          ? (cubit.state as AuthSuccess).user.name
          : null,
    );

    final trimmedName = userName?.trim() ?? '';
    final displayName = trimmedName.isNotEmpty ? trimmedName : l10n.orgName;

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
              // Altura fija = contentHeight — antes era implícita
              // (padding 16×2 + avatar 44); ahora es contrato: las
              // pantallas reservan exactamente este alto bajo la banda.
              child: SizedBox(
                height: contentHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
                  child: Row(
                    children: [
                      // Avatar con iniciales — es identidad, ya no abre el
                      // menú. El anillo blanco 20% separa el círculo del
                      // navy (la tarjeta del drawer no lo lleva).
                      UserInitialAvatar(
                        displayName: displayName,
                        withRing: true,
                      ),
                      const SizedBox(width: 12),
                      // §58 — solo el nombre: la segunda línea de
                      // quesera/hint se eliminó (la quesera activa la
                      // comunica la hero card del Inicio). Sin Column:
                      // el Row centra el Text igual que al avatar.
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.quesivoWhite,
                          ),
                        ),
                      ),
                      // Trigger del QuesivoDrawer: `Scaffold.of` resuelve el
                      // Scaffold del MainLayout (este header está debajo en el
                      // árbol) y abre el menú lateral desde la derecha. El
                      // círculo de borde blanco 20% es hermana del ✕ navy del
                      // drawer, en versión sobre navy.
                      Material(
                        color: AppColors.transparent,
                        shape: CircleBorder(
                          side: BorderSide(
                            color: AppColors.quesivoWhite.withValues(
                              alpha: 0.2,
                            ),
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
            ),
          ],
        ),
      ),
    );
  }
}
