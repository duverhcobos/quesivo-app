import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../queseras/presentation/widgets/quesera_hero_carousel.dart';
import '../widgets/home_quick_actions.dart';
import '../widgets/home_recent_activity.dart';
import '../../../shell/presentation/widgets/shell_insets.dart';
import '../../../shell/presentation/widgets/tab_page_title.dart';

/// Tab "Inicio" del shell post-auth (propuesta §shell-premium +
/// §56/§58/§59).
///
/// Con quesera activa abre con su `TabPageTitle` "Inicio" (el
/// `ShellHeader` es banda navy de identidad, sin título) +
/// `QueseraHeroCarousel` (la activa lleva los KPIs del día, placeholder
/// hasta F5) + accesos rápidos + actividad reciente. §58 — UN solo
/// layout siempre: no hay modo elección. §59 — sin haber entrado a una
/// quesera en esta sesión (§57 — enteredOrg=false) el selector tiene
/// composición propia: saludo `personalGreeting` con el primer nombre +
/// `chooseQueseraHint` como subtítulo + carousel con cards de marca
/// (queso peeking + pill amarillo); el título "Inicio" no aparece en
/// ese estado.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    // §58/§59 — mismo select de enteredOrg, más el nombre para el saludo
    // del selector (primer nombre — "Hola, Juan").
    final (enteredOrg, userName) = context.select<AuthCubit, (bool, String)>(
      (cubit) => cubit.state is AuthSuccess
          ? (
              (cubit.state as AuthSuccess).enteredOrg,
              (cubit.state as AuthSuccess).user.name,
            )
          : (false, ''),
    );

    // §39: sin SafeArea — los insets del shell se reservan en el padding
    // del ListView (el contenido puede scrollear bajo el chrome navy).
    return ListView(
      padding: EdgeInsets.only(
        left: size.width * 0.075,
        right: size.width * 0.075,
        top: context.shellHeaderHeight + 16,
        bottom: context.shellNavBarHeight + 16,
      ),
      children: [
        // §59 — el selector abre con saludo personal (primer instante de
        // marca, como el splash), no con el título del tab. Con quesera
        // activa vuelve "Inicio".
        if (enteredOrg)
          TabPageTitle(title: l10n.navHome)
        else ...[
          // Caso borde: name vacío → saludo genérico, no "Hola, ".
          Text(
            userName.trim().isEmpty
                ? l10n.greeting
                : l10n.personalGreeting(userName.trim().split(' ').first),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chooseQueseraHint,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.quesivoTextSecondary,
            ),
          ),
        ],
        const SizedBox(height: 20),
        const QueseraHeroCarousel(),
        const SizedBox(height: 24),
        const HomeQuickActions(),
        const SizedBox(height: 28),
        const HomeRecentActivity(),
      ],
    );
  }
}
