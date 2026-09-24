import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_toast.dart';
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
/// - Quesera activa (`enteredOrg` + org en el user) → UNA sola
///   `QueseraHeroCard` navy a todo ancho — sin PageView, sin dots, sin
///   cards "Entrar" al lado (§64: la quesera activa no se acompaña ni
///   se slidea; para cambiar de quesera se vuelve al selector con el
///   back y se toca otra card).
/// - Selector (sin haber entrado en esta sesión — §57, aunque el JWT
///   restaurado traiga org): todas `QueseraCard` "Entrar"; con >1,
///   `viewportFraction 0.88` — el borde de la siguiente asoma a la
///   derecha y los dots marcan la posición. El swipe NUNCA entra a una
///   quesera — solo el tap dispara `select-organization`.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Transición selector ↔ hero (§64): fade + leve settle de escala
  /// (0.97 → 1 con easeOutCubic). Más perceptible que un crossfade
  /// puro — la que sale se "aleja" encogiéndose apenas y la que entra
  /// aterriza. Con `disableAnimations` la duración cae a cero.
  Widget _switcher(bool reduceMotion, Widget child) {
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
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

    // La quesera activa va SOLA, sin slide (§64): card única navy a
    // todo ancho — ni PageView ni dots ni cards "Entrar" al lado. Para
    // cambiar de quesera se vuelve al selector (back) y se toca otra.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (activeOrgId != null) {
      _page = 0; // al salir (org → selector) el PageView vuelve a abrir en 0
      final active = ordered.firstWhere((o) => o.id == activeOrgId);
      return _switcher(
        reduceMotion,
        SizedBox(
          key: const ValueKey('hero'),
          height: _heroHeight,
          // La hero también entra animada (fade + slide-up) — con el
          // crossfade solo el cambio era casi imperceptible.
          child: _CardEntrance(
            index: 0,
            child: QueseraHeroCard(organization: active),
          ),
        ),
      );
    }

    return _switcher(
      reduceMotion,
      KeyedSubtree(
        key: const ValueKey('selector'),
        child: BlocProvider(
          create: (_) => locator<QueseraSelectionCubit>(),
          child: BlocConsumer<QueseraSelectionCubit, QueseraSelectionState>(
            listener: (context, state) {
              if (state.errorMessage != null) {
                QuesivoToast.error(context, message: state.errorMessage!);
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
                      style: const TextStyle(
                        color: AppColors.quesivoTextSecondary,
                      ),
                    ),
                  ),
                );
              }

              final multi = ordered.length > 1;
              // Selector (acá activeOrgId siempre es null — la activa salió
              // por el early return de arriba): todas "Entrar", alto compacto.
              const cardHeight = _enterHeight;

              // 1 sola quesera → card única a ancho completo, sin PageView
              // ni dots (viewportFraction 0.88 la dejaría al 88%).
              if (!multi) {
                final org = ordered.first;
                return SizedBox(
                  height: cardHeight,
                  child: _CardEntrance(
                    index: 0,
                    child: QueseraCard(
                      organization: org,
                      loading: selection.selectingId == org.id,
                      enabled: !selection.isSelecting,
                      enterLabel: l10n.queseraEnterCta,
                      roleLabel: l10n.roleLabelFor(org.role),
                      tagline: l10n.queseraCardTagline,
                      onTap: () =>
                          context.read<QueseraSelectionCubit>().select(org.id),
                    ),
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
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _CardEntrance(
                            index: i,
                            child: QueseraCard(
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
        ),
      ),
    );
  }
}

/// Entrada escalonada de las cards del selector (§64): fade + slide-up
/// suave, cada card ~70ms después de la anterior — la pantalla se siente
/// viva sin ser ruidosa. Respeta `MediaQuery.disableAnimations`.
class _CardEntrance extends StatefulWidget {
  const _CardEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<_CardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    // Stagger: cada card arranca un poco después de la anterior.
    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
