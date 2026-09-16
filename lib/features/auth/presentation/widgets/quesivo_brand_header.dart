import 'package:flutter/material.dart';

/// Imagotipo centrado + gap inferior (quesivo-design-system.yaml
/// §brand_header).
///
/// `logoFraction` = fracción del ancho de pantalla que ocupa el imagotipo
/// (register 0.65, forgot 0.62, reset 0.55, login 0.65).
class QuesivoBrandHeader extends StatelessWidget {
  const QuesivoBrandHeader({super.key, required this.logoFraction});

  final double logoFraction;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Column(
      children: [
        Center(
          child: Image.asset(
            'assets/images/imagotipo_quesivo.png',
            width: size.width * logoFraction,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: size.height * 0.03),
      ],
    );
  }
}
