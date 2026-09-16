import 'package:flutter/material.dart';

/// Área de marca superior (61% del alto) con el imagotipo (~42% vertical
/// del área) — §welcome.
class WelcomeBrandArea extends StatelessWidget {
  const WelcomeBrandArea({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      height: size.height * 0.61,
      width: double.infinity,
      child: Center(
        child: Padding(
          // Ubicar el logo al ~42% vertical del área de marca
          padding: EdgeInsets.only(top: size.height * 0.61 * 0.10),
          child: Image.asset(
            'assets/images/imagotipo_quesivo.png',
            width: size.width,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
