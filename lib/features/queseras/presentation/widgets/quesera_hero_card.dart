import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/organization_summary.dart';
import 'role_label_for.dart';

/// Card de la quesera ACTIVA dentro del `QueseraHeroCarousel` (§56):
/// hero navy con el nombre de la quesera + chip de rol + badge "Actual"
/// + la fila de KPIs del día (mismos placeholders del HomeHeroCard que
/// reemplaza — datos reales en F5). Ocupa la página 0 del PageView.
class QueseraHeroCard extends StatelessWidget {
  const QueseraHeroCard({super.key, required this.organization});

  final OrganizationSummary organization;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.quesivoNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  organization.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.quesivoWhite,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.quesivoYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.queseraActiveBadge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.quesivoNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.roleLabelFor(organization.role),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.quesivoWhite.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          // Fila de KPIs — trasladada literal del HomeHeroCard saliente:
          // etiqueta "Hoy" amarilla + los 3 indicadores con su
          // maquetación original (placeholders hasta F5).
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
              _Kpi(value: l10n.kpiLitersValue, label: l10n.kpiLitersReceived),
              _Kpi(value: l10n.kpiReceptionsValue, label: l10n.kpiReceptions),
              _Kpi(value: l10n.kpiBalanceValue, label: l10n.kpiPendingBalance),
            ],
          ),
        ],
      ),
    );
  }
}

/// KPI del hero: valor amarillo grande + label blanco 70% debajo.
/// Trasladado tal cual del `HomeHeroCard` (§56 lo absorbe).
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
