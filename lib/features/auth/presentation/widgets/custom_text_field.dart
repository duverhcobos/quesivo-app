// lib/features/auth/presentation/widgets/custom_text_field.dart
import 'package:flutter/material.dart';

/// Un pequeño widget reutilizable (Small Widget).
///
/// SOLID (SRP): Solo se encarga de renderizar la caja de texto.
/// No sabe ni le importa para qué se usará (Email, Contraseña, etc).
class CustomTextField extends StatelessWidget {
  final String labelText;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final String? errorText;

  // Uso intensivo de 'const' constructors para optimización de UI.
  const CustomTextField({
    super.key,
    required this.labelText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: labelText,
        errorText: errorText,
        // Dejamos que el AppTheme inyecte los bordes dinámicamente
      ),
    );
  }
}
