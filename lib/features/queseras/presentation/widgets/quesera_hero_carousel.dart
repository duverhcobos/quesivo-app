import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/organization_summary.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/quesera_selection_cubit.dart';
import '../cubit/quesera_selection_state.dart';
import 'quesera_card.dart';
import 'quesera_hero_card.dart';
import 'role_label_for.dart';

/// Selector de quesera en la zona del hero del Inicio (§56) — el "en
/// qué quesera estoy" siempre a la vista, sin menús.
///
/// - 1 quesera + org activa → una sola `QueseraHeroCard` navy a todo
///   ancho (PageView de una página — sin dots, sin peek).
/// - N queseras → `viewportFraction 0.88`: el borde de la siguiente
///   card asoma a la derecha y los dots marcan la posición — el slide
///   se descubre solo. Página 0 = la activa (hero navy); las demás son
///   `QueseraCard` "Entrar". El swipe NUNCA cambia de quesera — solo
///   el tap sobre una card no-activa dispara `select-organization`.
/// - Sin haber entrado a una quesera en esta sesión (§57 — `enteredOrg`
///   false, aunque el JWT restaurado traiga org): todas son
///   `QueseraCard` "Entrar" — el selector siempre arranca limpio.
///
/// El cubit es factory y vive acá — nace y muere con el carousel.
class QueseraHeroCarousel extends StatefulWidget {
  const QueseraHeroCarousel({super.key});

  @override
  State<QueseraHeroCarousel> createState() => _QueseraHeroCarouselState();
}

class _QueseraHeroCarouselState extends State<QueseraHeroCarousel> {
  /// Alto de las cards. La `QueseraHeroCard` suma nombre + rol + la fila
  /// de KPIs trasladada del HomeHeroCard (label "Hoy" + 3 indicadores
  /// con labels de hasta 2 líneas) — ~195px de contenido con el padding,
  /// así que 208 deja aire para el Spacer sin overflow. Las cards
  /// "Entrar" no llevan KPIs — en el selector (sin activa) el alto baja
  /// a 172 (§61: la card es un Row horizontal; el aire extra deja
  /// respirar el badge + chip + tagline y las ondas).
  static const double _heroHeight = 208;
  static const double _enterHeight = 172;

  /// 0.88 → la siguiente card asoma ~12% a la derecha: el slide se
  /// descubre solo. Solo se usa cuando hay >1 quesera (con 1 se
  /// renderiza la card a ancho completo, sin PageView) — por eso la
  /// fracción va fija y no hace falta recrear el controller.
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  /// Último `activeOrgId` visto — detecta la transición selector→org
  /// para volver a la página 0 (la activa se reordena al índice 0 pero
  /// el viewport no se mueve solo: quedaría mostrando la card "Entrar"
  /// de otra quesera — auditoría §63).
  String? _lastActiveOrgId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // §57 — "activa" exige las DOS cosas: el JWT trae la org Y el
    // usuario ya entró en esta sesión de app. Con token restaurado
    // (orgId presente pero enteredOrg=false) todas son cards "Entrar":
    // el selector siempre arranca limpio.
    final (orgs, activeOrgId) = context
        .select<AuthCubit, (List<OrganizationSummary>, String?)>(
          (cubit) => cubit.state is AuthSuccess
              ? (
                  (cubit.state as AuthSuccess).user.organizations,
                  (cubit.state as AuthSuccess).enteredOrg
                      ? (cubit.state as AuthSuccess).user.organizationId
                      : null,
                )
              : (const <OrganizationSummary>[], null),
        );

    // La activa primero; el resto detrás, en el orden del /me.
    final ordered = [...orgs]
      ..sort((a, b) {
        if (a.id == activeOrgId) return -1;
        if (b.id == activeOrgId) return 1;
        return 0;
      });

    // Selector → quesera: la activa saltó al índice 0 — el viewport
    // debe acompañar (post-frame: el PageView puede no existir aún en
    // este build si antes había 1 sola card).
    if (activeOrgId != null && _lastActiveOrgId == null) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpToPage(0);
      });
    }
    _lastActiveOrgId = activeOrgId;

    return BlocProvider(
      create: (_) => locator<QueseraSelectionCubit>(),
      child: BlocConsumer<QueseraSelectionCubit, QueseraSelectionState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, selection) {
          // Defensivo (el gate 065 hace que no ocurra, pero el estado
          // vacío no debe crashear): sin queseras → mensaje centrado.
          if (ordered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  l10n.noQueserasAvailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.quesivoTextSecondary),
                ),
              ),
            );
          }

          final multi = ordered.length > 1;
          // Sin quesera activa (selector) todas son cards "Entrar" →
          // alto compacto; con hero navy en el mixto → alto completo.
          final cardHeight = activeOrgId == null ? _enterHeight : _heroHeight;

          // 1 sola quesera → card única a ancho completo, sin PageView
          // ni dots (viewportFraction 0.88 la dejaría al 88%).
          if (!multi) {
            final org = ordered.first;
            final isActive = org.id == activeOrgId;
            return SizedBox(
              height: cardHeight,
              child: isActive
                  ? QueseraHeroCard(organization: org)
                  : QueseraCard(
                      organization: org,
                      loading: selection.selectingId == org.id,
                      enabled: !selection.isSelecting,
                      enterLabel: l10n.queseraEnterCta,
                      roleLabel: l10n.roleLabelFor(org.role),
                      tagline: l10n.queseraCardTagline,
                      onTap: () =>
                          context.read<QueseraSelectionCubit>().select(org.id),
                    ),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: cardHeight,
                child: PageView.builder(
                  controller: _controller,
                  // padEnds false: el peek se ve solo a la derecha —
                  // la página 0 arranca pegada al margen de la pantalla.
                  padEnds: false,
                  itemCount: ordered.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final org = ordered[i];
                    final isActive = org.id == activeOrgId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: isActive
                          ? QueseraHeroCard(organization: org)
                          : QueseraCard(
                              organization: org,
                              loading: selection.selectingId == org.id,
                              enabled: !selection.isSelecting,
                              enterLabel: l10n.queseraEnterCta,
                              roleLabel: l10n.roleLabelFor(org.role),
                              tagline: l10n.queseraCardTagline,
                              onTap: () => context
                                  .read<QueseraSelectionCubit>()
                                  .select(org.id),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < ordered.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _page == i ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _page == i
                            ? AppColors.quesivoNavy
                            : AppColors.quesivoBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
