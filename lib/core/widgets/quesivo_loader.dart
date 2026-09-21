import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Variantes de color del loader según la superficie donde vive.
enum QuesivoLoaderVariant {
  /// Arco quesivoYellow + track navy tenue — la firma de marca: el arco
  /// es la "porción de queso" del imagotipo girando sobre el aro. Para
  /// superficies claras (quesivoSurface/white): loaders de pantalla.
  accent,

  /// Arco + track navy — dentro del pill amarillo del primario (un arco
  /// amarillo desaparecería sobre quesivoYellow) y en momentos sutiles
  /// como el footer del listado.
  navy,

  /// Arco + track quesivoWhite — sobre superficies navy (hero, splash).
  onNavy,
}

/// Spinner de marca (§50) — reemplaza al `CircularProgressIndicator`
/// genérico en toda la app. Aro track tenue + arco de ~110° con caps
/// redondos rotando 1.1s; el arco es la porción de queso del imagotipo.
///
/// Respeta `MediaQuery.disableAnimations`: con "quitar animaciones" del
/// SO activo el loader queda como arco estático (de marca, sin movimiento).
/// `semanticLabel` envuelve en `Semantics` — usarlo en estados de carga
/// de pantalla/bloque (l10n `loadingLabel`); en loaders inline/transitorios
/// (footer de paginación, dentro del botón) dejarlo en null para no llenar
/// TalkBack de anuncios repetidos.
class QuesivoLoader extends StatefulWidget {
  const QuesivoLoader({
    super.key,
    this.size = 24,
    this.variant = QuesivoLoaderVariant.accent,
    this.semanticLabel,
  });

  /// Lado del cuadrado que ocupa el loader; el grosor del trazo es
  /// `size / 9` (22px → ~2.4, igual que los spinners que reemplaza).
  final double size;

  /// Paleta según la superficie — ver `QuesivoLoaderVariant`.
  final QuesivoLoaderVariant variant;

  /// Label para lectores de pantalla — solo en loaders de estado de
  /// pantalla/bloque; null (default) en inline/transitorios.
  final String? semanticLabel;

  @override
  State<QuesivoLoader> createState() => _QuesivoLoaderState();
}

class _QuesivoLoaderState extends State<QuesivoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El ajuste del SO se lee acá (MediaQuery no está listo en initState)
    // y reacciona si cambia en caliente — con movimiento reducido el
    // arco queda estático en vez de rotar.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (arc, track) = switch (widget.variant) {
      QuesivoLoaderVariant.accent => (
        AppColors.quesivoYellow,
        AppColors.quesivoNavy.withValues(alpha: 0.18),
      ),
      QuesivoLoaderVariant.navy => (
        AppColors.quesivoNavy,
        AppColors.quesivoNavy.withValues(alpha: 0.18),
      ),
      QuesivoLoaderVariant.onNavy => (
        AppColors.quesivoWhite,
        AppColors.quesivoWhite.withValues(alpha: 0.25),
      ),
    };

    final loader = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _QuesivoLoaderPainter(
          progress: _controller.value,
          arcColor: arc,
          trackColor: track,
          strokeWidth: widget.size / 9,
        ),
      ),
    );
    return widget.semanticLabel == null
        ? loader
        : Semantics(label: widget.semanticLabel, child: loader);
  }
}

/// Pinta el aro track completo + el arco de ~110° rotando. `progress`
/// (0..1 del controller) define el ángulo de inicio.
class _QuesivoLoaderPainter extends CustomPainter {
  _QuesivoLoaderPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  /// ~110° — la "porción de queso" del imagotipo.
  static const _sweep = math.pi * 0.61;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = trackColor);
    canvas.drawArc(
      arcRect,
      -math.pi / 2 + progress * math.pi * 2,
      _sweep,
      false,
      paint..color = arcColor,
    );
  }

  @override
  bool shouldRepaint(_QuesivoLoaderPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
