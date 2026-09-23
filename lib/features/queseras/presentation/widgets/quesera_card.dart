import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../auth/domain/entities/organization_summary.dart';

/// Card "Entrar" del `QueseraHeroCarousel` (§56 → restilo §59/§60/§61/
/// §62): fondo crema (`quesivoCream`) con ondas de queso suaves en la
/// esquina inferior-izquierda (trasera en S + frontal cuarto de
/// círculo, alphas bajos para no competir); nombre navy + chip de rol
/// navy con punto amarillo y texto blanco; tagline en
/// `quesivoTextSecondary`; y CTA circular amarillo con flecha navy —
/// affordance del tap (toda la card es el target; no es un botón
/// anidado). `loading` muestra el `QuesivoLoader` en lugar del CTA y el
/// tap queda bloqueado (`enabled`).
///
/// Regla de color: crema/amarillo suave = "entrá" (elección); navy =
/// "estás adentro" (`QueseraHeroCard` con badge "Actual" + KPIs).
class QueseraCard extends StatelessWidget {
  const QueseraCard({
    super.key,
    required this.organization,
    required this.loading,
    required this.enabled,
    required this.enterLabel,
    required this.roleLabel,
    required this.tagline,
    required this.onTap,
  });

  final OrganizationSummary organization;
  final bool loading;
  final bool enabled;

  /// No se pinta (el CTA es solo el círculo-flecha) — se usa como label
  /// de `Semantics` para lectores de pantalla.
  final String enterLabel;
  final String roleLabel;
  final String tagline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$enterLabel: ${organization.name}',
      child: Material(
        color: AppColors.quesivoCream,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.quesivoYellow.withValues(alpha: 0.25),
              ),
            ),
            child: Stack(
              children: [
                // Ondas de queso: dos bandas orgánicas curvas saliendo
                // de la esquina inferior-izquierda (referencia §61).
                const Positioned.fill(
                  child: CustomPaint(painter: _CheeseWavesPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              organization.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.quesivoNavy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Chip de rol navy sólido + punto
                            // amarillo — limpio, sin ícono (§62).
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.quesivoNavy,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.quesivoYellow,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    roleLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.quesivoWhite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tagline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.25,
                                color: AppColors.quesivoTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // CTA: círculo amarillo con flecha navy — affordance
                      // del tap; mientras vuela el select, loader.
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: loading
                            ? const Center(child: QuesivoLoader(size: 20))
                            : Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.quesivoYellow,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: AppColors.quesivoNavy,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ondas de queso de la esquina inferior-izquierda (referencia §61):
/// dos bandas orgánicas — una amarilla pálida amplia atrás y una dorada
/// más baja adelante — que emergen del borde izquierdo y mueren en el
/// borde inferior. Textura cálida que llena sin competir.
class _CheeseWavesPainter extends CustomPainter {
  const _CheeseWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ola trasera — amarillo pálido: arranca alta en el borde
    // izquierdo y desciende en una sola cúbica con inflexión (S)
    // hasta morir en el borde inferior.
    final back = Paint()
      ..color = AppColors.quesivoYellow.withValues(alpha: 0.22);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.42)
        // Caída en S: el control 1 tira hacia abajo, el control 2
        // aplana el tramo medio antes de llegar al borde inferior.
        ..cubicTo(w * 0.15, h * 0.98, w * 0.3, h * 0.7, w * 0.4, h)
        ..lineTo(0, h)
        ..close(),
      back,
    );

    // Ola frontal — dorada más saturada: cuarto de círculo que entra a
    // la card (del borde izquierdo al borde inferior, panza hacia dentro).
    final front = Paint()
      ..color = AppColors.quesivoYellow.withValues(alpha: 0.45);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.70)
        ..quadraticBezierTo(h * 0.30, h * 0.70, h * 0.4, h)
        ..lineTo(0, h)
        ..close(),
      front,
    );
  }

  @override
  bool shouldRepaint(_CheeseWavesPainter oldDelegate) => false;
}
