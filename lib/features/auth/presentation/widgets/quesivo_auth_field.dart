import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Campo de texto de las pantallas de autenticación QUESIVO
/// (quesivo-design-system.yaml §register_form / §login_form).
///
/// SOLID (SRP): solo renderiza la caja con el estilo de marca; no sabe para
/// qué se usa (nombre, email, password). `isPassword` agrega el ojo de
/// visibilidad como estado visual interno.
class QuesivoAuthField extends StatefulWidget {
  const QuesivoAuthField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.errorText,
    this.onChanged,
  });

  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? errorText;
  final void Function(String)? onChanged;

  @override
  State<QuesivoAuthField> createState() => _QuesivoAuthFieldState();
}

class _QuesivoAuthFieldState extends State<QuesivoAuthField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.quesivoBorder, width: 1.5),
    );

    return TextFormField(
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(
        color: AppColors.quesivoDarkText,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(
          color: AppColors.quesivoPlaceholder,
          fontSize: 16,
        ),
        errorText: widget.errorText,
        filled: true,
        fillColor: AppColors.quesivoWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 18,
        ),
        prefixIcon: Icon(
          widget.prefixIcon,
          color: AppColors.quesivoNavy,
          size: 28,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.quesivoPlaceholder,
                  size: 26,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.quesivoNavy, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
      ),
    );
  }
}
