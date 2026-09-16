import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// Card navy del tab Inicio (propuesta §shell-premium): el primer instante
/// post-login.
///
/// Label "Hoy" amarillo + 3 KPIs del día (litros recibidos, recepciones,
/// saldo pendiente) con valores placeholder hasta que el dashboard real
/// aterrice en F5. Los huecos de queso blancos al 6% en la esquina superior
/// repiten el motif del backdrop, versión sutil sobre navy.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        color: AppColors.quesivoNavy,
        child: Stack(
          children: [
            // Huecos de queso: círculos blancos al 6% saliendo del borde.
            Positioned(
              right: -34,
              top: -44,
              child: const _CheeseHole(diameter: 116),
            ),
            const Positioned(
              right: 64,
              top: 14,
              child: _CheeseHole(diameter: 34),
            ),
            const Positioned(
              right: 18,
              top: 92,
              child: _CheeseHole(diameter: 22),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.navToday,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.quesivoYellow,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Kpi(
                        value: l10n.kpiLitersValue,
                        label: l10n.kpiLitersReceived,
                      ),
                      _Kpi(
                        value: l10n.kpiReceptionsValue,
                        label: l10n.kpiReceptions,
                      ),
                      _Kpi(
                        value: l10n.kpiBalanceValue,
                        label: l10n.kpiPendingBalance,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hueco decorativo del hero — eco de los agujeros del queso del isotipo.
class _CheeseHole extends StatelessWidget {
  const _CheeseHole({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: AppColors.quesivoWhite.withValues(alpha: 0.06),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// KPI del hero: valor amarillo grande + label blanco 70% debajo.
class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.quesivoYellow,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              color: AppColors.quesivoWhite.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
