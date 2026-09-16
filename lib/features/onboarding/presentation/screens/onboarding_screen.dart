import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:quesivo/l10n/app_localizations.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../data/datasources/interfaces/i_onboarding_status_store.dart';
import '../widgets/onboarding_bottom_panel.dart';
import '../widgets/onboarding_page.dart';

/// Onboarding — carrusel de presentación QUESIVO (no definido en
/// quesivo-design-system.yaml; hereda la identidad por continuidad visual §5).
///
/// Se muestra una sola vez: al terminar ("Comenzar") o saltar ("Saltar") se
/// persiste `IOnboardingStatusStore.markSeen()` y se navega a /login.
/// Sin Cubit: es UI pura con PageController local — el store llega inyectado
/// por constructor (DIP, resuelto en `app_router.dart`).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.statusStore});

  final IOnboardingStatusStore statusStore;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _icons = [
    Icons.water_drop_outlined, // recepción de leche / producción
    Icons.groups_outlined, // productores
    Icons.payments_outlined, // liquidaciones / pagos
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.statusStore.markSeen();
    if (mounted) context.go(AuthGuard.welcomeRoute);
  }

  void _next() {
    if (_currentPage == _icons.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final titles = [
      l10n.onboardingSlide1Title,
      l10n.onboardingSlide2Title,
      l10n.onboardingSlide3Title,
    ];
    final descriptions = [
      l10n.onboardingSlide1Description,
      l10n.onboardingSlide2Description,
      l10n.onboardingSlide3Description,
    ];
    final isLast = _currentPage == _icons.length - 1;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Estático en onboarding — la animación de entrada queda solo en splash.
        animate: false,
        // Sin círculo navy abajo-izquierda: el panel navy lo reemplaza
        // (mismo criterio que la pantalla welcome del design doc).
        bottomCircleFraction: 0,
        child: SafeArea(
          bottom: false, // el panel navy llega hasta el borde inferior
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    l10n.onboardingSkip,
                    style: const TextStyle(
                      color: AppColors.quesivoNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _icons.length,
                  physics: reduceMotion
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) => OnboardingPage(
                    icon: _icons[index],
                    title: titles[index],
                    description: descriptions[index],
                    controller: _pageController,
                    index: index,
                  ),
                ),
              ),
              // Panel navy inferior — patrón welcome_panel del design doc:
              // ancho completo, esquinas superiores redondeadas, flat.
              OnboardingBottomPanel(
                count: _icons.length,
                currentIndex: _currentPage,
                buttonLabel: isLast
                    ? l10n.onboardingStart
                    : l10n.onboardingNext,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
