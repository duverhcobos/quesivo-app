import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../../core/constants/environment/environment.dart';
import '../../../../../core/routes/auth_guard.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/presentation/cubit/auth_cubit.dart';
import 'drawer_category_card.dart';
import 'drawer_home_tile.dart';
import 'drawer_logout_dialog.dart';
import 'drawer_menu_item_row.dart';
import 'drawer_staggered_item.dart';

/// Lista de ítems del `QuesivoDrawer` — Inicio, los 17 módulos agrupados
/// en 4 `DrawerCategoryCard` y Cerrar sesión al final del scroll. Recibe
/// la ruta activa para marcar el ítem seleccionado (pastilla surface +
/// ícono amarillo, propuesta §28).
///
/// Es `StatefulWidget` por la entrada escalonada (propuesta §30): un
/// `AnimationController` de 600ms dispara el fade + slide-up de cada
/// bloque vía `DrawerStaggeredItem` al montarse la lista; con animaciones
/// deshabilitadas el menú aparece completo de una.
class DrawerMenuList extends StatefulWidget {
  const DrawerMenuList({super.key, required this.currentLocation});

  final String currentLocation;

  @override
  State<DrawerMenuList> createState() => _DrawerMenuListState();
}

class _DrawerMenuListState extends State<DrawerMenuList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta la accesibilidad: con animaciones deshabilitadas el menú
    // aparece completo de una (skill frontend-design). MediaQuery no puede
    // leerse en initState — didChangeDependencies es el primer punto legal
    // y además respeta MediaQuery sobreescritos en tests/subárboles.
    if (!_controller.isAnimating && _controller.value == 0) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    var index = 0;

    // Cada bloque del menú (Inicio, las 4 tarjetas de categoría y
    // logout — 6 índices) entra en cascada con su propio Interval.
    Widget stagger(Widget child) => DrawerStaggeredItem(
      animation: _controller,
      index: index++,
      child: child,
    );

    // Módulos por categoría + logout al final del scroll. El
    // padding inferior amplio evita que el arco navy tape
    // el último ítem.
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        children: [
          stagger(
            DrawerHomeTile(
              label: l10n.navHome,
              selected: widget.currentLocation == AuthGuard.homeRoute,
              onTap: () {
                // GoRouter se resuelve antes del pop — cerrado
                // el drawer, su contexto queda desactivado para
                // lookups (mismo criterio que el logout).
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(AuthGuard.homeRoute);
              },
            ),
          ),
          const SizedBox(height: 16),
          stagger(
            DrawerCategoryCard(
              title: l10n.menuSectionOperations,
              children: [
                DrawerMenuItemRow(
                  icon: Icons.water_drop_outlined,
                  label: l10n.moduleReception,
                  route: AuthGuard.receptionsRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.receptionsRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.precision_manufacturing_outlined,
                  label: l10n.moduleProduction,
                  route: AuthGuard.productionRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.productionRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.inventory_2_outlined,
                  label: l10n.moduleSupplies,
                  route: AuthGuard.suppliesRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.suppliesRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.shopping_bag_outlined,
                  label: l10n.modulePurchases,
                  route: AuthGuard.purchasesRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.purchasesRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.assignment_outlined,
                  label: l10n.moduleOrders,
                  route: AuthGuard.ordersRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.ordersRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.point_of_sale_outlined,
                  label: l10n.moduleSales,
                  route: AuthGuard.salesRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.salesRoute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          stagger(
            DrawerCategoryCard(
              title: l10n.menuSectionDirectory,
              children: [
                DrawerMenuItemRow(
                  icon: Icons.groups_outlined,
                  label: l10n.moduleProducers,
                  route: AuthGuard.producersRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.producersRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.local_shipping_outlined,
                  label: l10n.moduleCollectors,
                  route: AuthGuard.collectorsRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.collectorsRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.storefront_outlined,
                  label: l10n.moduleSuppliers,
                  route: AuthGuard.suppliersRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.suppliersRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.people_outline,
                  label: l10n.moduleClients,
                  route: AuthGuard.clientsRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.clientsRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.kitchen_outlined,
                  label: l10n.moduleTools,
                  route: AuthGuard.toolsRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.toolsRoute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          stagger(
            DrawerCategoryCard(
              title: l10n.menuSectionFinances,
              children: [
                DrawerMenuItemRow(
                  icon: Icons.receipt_long_outlined,
                  label: l10n.moduleSettlements,
                  route: AuthGuard.settlementsRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.settlementsRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.request_quote_outlined,
                  label: l10n.moduleAdvances,
                  route: AuthGuard.advancesRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.advancesRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.payments_outlined,
                  label: l10n.moduleProducerPayments,
                  route: AuthGuard.producerPaymentsRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.producerPaymentsRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.money_off_outlined,
                  label: l10n.moduleExpenses,
                  route: AuthGuard.expensesRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.expensesRoute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          stagger(
            DrawerCategoryCard(
              title: l10n.menuSectionSettings,
              children: [
                DrawerMenuItemRow(
                  icon: Icons.business_outlined,
                  label: l10n.orgDataItem,
                  route: AuthGuard.orgDataRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.orgDataRoute,
                  ),
                ),
                DrawerMenuItemRow(
                  icon: Icons.group_outlined,
                  label: l10n.orgUsersItem,
                  route: AuthGuard.orgUsersRoute,
                  selected: isDrawerModuleRouteActive(
                    widget.currentLocation,
                    AuthGuard.orgUsersRoute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          stagger(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Divider que marca la "zona destructiva" — separa el
                // logout del resto del menú sin agregar ruido.
                const Divider(height: 1, color: AppColors.quesivoBorder),
                const SizedBox(height: 12),
                // Acción destructiva como último ítem — pide
                // confirmación antes de cerrar sesión; el guard
                // redirige a /welcome al quedar sin sesión.
                DrawerMenuItemRow(
                  icon: Icons.logout,
                  label: l10n.logoutTooltip,
                  color: AppColors.quesivoError,
                  showChevron: false,
                  onTap: _confirmLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          stagger(
            // Pie con la versión — referencia rápida para soporte.
            Center(
              child: Text(
                l10n.appVersion(Environment.appVersion),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.quesivoTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Diálogo de confirmación de logout — se abre sobre el drawer, así
  /// cancelar deja el menú como estaba y confirmar cierra el drawer y
  /// dispara el logout. Se captura el cubit antes del pop porque el
  /// contexto del drawer queda desactivado para `read` al cerrarse.
  Future<void> _confirmLogout() async {
    final authCubit = context.read<AuthCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DrawerLogoutDialog(),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      authCubit.logout();
    }
  }
}
