import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../widgets/home_hero_card.dart';
import '../widgets/home_quick_actions.dart';
import '../widgets/home_recent_activity.dart';
import '../../../shell/presentation/widgets/tab_page_title.dart';

/// Tab "Inicio" del shell post-auth (propuesta §shell-premium).
///
/// Abre con su `TabPageTitle` (el `ShellHeader` ahora es banda navy de
/// identidad, sin título) + hero navy con los KPIs del día (placeholder
/// hasta F5) + accesos rápidos + actividad reciente.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.075,
          vertical: 16,
        ),
        children: [
          TabPageTitle(title: l10n.navHome),
          const SizedBox(height: 20),
          const HomeHeroCard(),
          const SizedBox(height: 24),
          const HomeQuickActions(),
          const SizedBox(height: 28),
          const HomeRecentActivity(),
        ],
      ),
    );
  }
}
