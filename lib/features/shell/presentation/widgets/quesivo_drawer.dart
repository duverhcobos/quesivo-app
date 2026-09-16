import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import 'drawer/drawer_brand_decoration.dart';
import 'drawer/drawer_close_button.dart';
import 'drawer/drawer_identity.dart';
import 'drawer/drawer_menu_list.dart';

/// Menú a pantalla completa del shell post-auth
/// (propuesta §25-drawer-fullscreen).
///
/// Sigue siendo el `endDrawer` del Scaffold del `MainLayout` — conserva el
/// desliz desde la derecha, el scrim y el gesto de cierre nativos — pero
/// `width: double.infinity` lo convierte en una página, no en un panel
/// angosto: imagotipo + botón ✕ arriba, identidad (avatar, nombre, quesera
/// y rol), los módulos del MVP agrupados en 4 categorías y `Cerrar sesión`
/// destructivo al final del scroll.
///
/// Detrás del contenido va una única decoración de marca con la misma
/// técnica del `QuesivoBackdrop` (`Positioned` negativo + `ClipOval` +
/// `ColoredBox`): el círculo amarillo con huecos blancos arriba-derecha
/// (96px, top/right -36 — el mismo tamaño/posición que la firma del
/// `ShellHeader`, §33). El arco navy inferior se retiró (§31) — competía
/// con la tarjeta navy de identidad.
///
/// `Inicio` navega con pop + `context.go` a /home; las 17 filas de módulo
/// llevan su `route` (AuthGuard.*Route) y navegan con pop + `router.go` —
/// desde §35 los módulos son rutas top-level dentro de las branches del
/// shell y solo `go` cambia `currentIndex` (`push` apilaba sin marcar el
/// tab). Cuando cada feature real aterrice, su GoRoute reemplaza al
/// placeholder con la misma ruta y este drawer no se vuelve a tocar.
///
/// Este archivo es solo la composición: cada pieza vive en su propio
/// widget del mismo directorio (propuesta §29-refactor-drawer) —
/// `DrawerBrandDecoration`, `DrawerCloseButton`, `DrawerIdentity` y
/// `DrawerMenuList` (que a su vez usa `DrawerHomeTile`,
/// `DrawerSectionLabel` y `DrawerMenuItemRow`).
class QuesivoDrawer extends StatelessWidget {
  const QuesivoDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Mismo `select` del ShellHeader: solo nombre/org interesan, así el
    // drawer no se reconstruye por otros cambios del AuthState.
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

    final trimmedOrgName = organizationName?.trim() ?? '';
    final displayOrgName = trimmedOrgName.isNotEmpty
        ? trimmedOrgName
        : l10n.orgName;

    return Drawer(
      width: double.infinity,
      backgroundColor: AppColors.quesivoWhite,
      // Ruta activa — marca en el menú el módulo donde está parado el
      // usuario (ej. /operaciones/produccion → fila Producción
      // seleccionada). Dos fuentes descartadas antes de esta:
      // - `GoRouterState.of(context)`: este Drawer cuelga del Scaffold
      //   del `MainLayout` del shell, que no se reconstruye al hacer
      //   `push` dentro de un branch — queda con la ruta congelada al
      //   montar el shell.
      // - `routeInformationProvider.value`: se desincroniza (verificado
      //   en el device — tras cerrar el drawer podía seguir reportando
      //   la ruta anterior aunque la navegación real ya hubiera
      //   ocurrido). No es la fuente de verdad.
      // La fuente correcta es el propio `GoRouterDelegate`: expone
      // `state` (== `GoRouterState` de la configuración YA construida y
      // resuelta) y es un `ChangeNotifier` que notifica en cada
      // navegación real — se escucha con `ListenableBuilder`.
      child: Builder(
        builder: (context) {
          final routerDelegate = GoRouter.of(context).routerDelegate;

          return ListenableBuilder(
            listenable: routerDelegate,
            builder: (context, child) {
              final currentLocation = GoRouter.of(
                context,
              ).state.matchedLocation;

              return _buildContent(
                context,
                displayName: displayName,
                displayOrgName: displayOrgName,
                currentLocation: currentLocation,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required String displayName,
    required String displayOrgName,
    required String currentLocation,
  }) {
    return Stack(
      children: [
        // Única decoración de marca que queda (§30→31): el círculo
        // amarillo con huecos blancos arriba-derecha, misma técnica del
        // `QuesivoBackdrop` (Positioned negativo saca media forma del
        // canvas). El arco navy abajo-derecha se retiró — competía con la
        // tarjeta navy de identidad y ensuciaba las últimas tarjetas.
        // Mismo tamaño/posición que la firma del ShellHeader (§33).
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: imagotipo a la izquierda + ✕ a la derecha. El ✕
              // ocupa la posición exacta de la hamburguesa del
              // `ShellHeader` (inset derecho width*0.075, tope a +18px
              // bajo el SafeArea) — el mismo toque abre y cierra.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  MediaQuery.sizeOf(context).width * 0.075,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // El PNG trae padding blanco horneado (~35% del
                    // alto): height 56 → ~36px de logo visible.
                    Image.asset(
                      'assets/images/imagotipo_quesivo.png',
                      height: 56,
                    ),
                    const Spacer(),
                    // +2px: el círculo de la hamburguesa (40px) queda
                    // centrado en la fila de 44 del header — acá el ✕ se
                    // alinea al tope, así que compensa ese mismo aire.
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: DrawerCloseButton(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Identidad: avatar + nombre / quesera / rol.
              DrawerIdentity(
                displayName: displayName,
                displayOrgName: displayOrgName,
              ),
              const SizedBox(height: 24),
              // Módulos por categoría + logout al final del scroll —
              // la lista lleva su propio padding inferior.
              DrawerMenuList(currentLocation: currentLocation),
            ],
          ),
        ),
      ],
    );
  }
}
