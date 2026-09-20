import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatter

import '../theme/app_colors.dart';

/// Campo de texto de marca QUESIVO (quesivo-design-system.yaml
/// §register_form / §login_form / §create_user_sheet) — borde
/// quesivoBorder r15, prefixIcon navy, fill blanco.
///
/// SOLID (SRP): solo renderiza la caja con el estilo de marca; no sabe
/// para qué se usa (nombre, email, password). `isPassword` agrega el ojo
/// de visibilidad como estado visual interno.
///
/// Movido a core/widgets en §44 — es una primitiva de marca compartida
/// por auth y los módulos (antes `QuesivoAuthField` en features/auth).
class QuesivoTextField extends StatefulWidget {
  const QuesivoTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.errorText,
    this.onChanged,
    this.enabled = true,
    this.inputFormatters,
  });

  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? errorText;
  final void Function(String)? onChanged;

  /// `false` bloquea la edición — la sheet de creación lo usa para
  /// congelar los campos mientras el submit está en vuelo.
  final bool enabled;

  /// Formatters de tecla — el sheet de creación los usa para bloquear
  /// caracteres que el campo jamás acepta (dígitos en nombre, espacios
  /// en email, símbolos en contraseña temporal).
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<QuesivoTextField> createState() => _QuesivoTextFieldState();
}

class _QuesivoTextFieldState extends State<QuesivoTextField> {
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
      enabled: widget.enabled,
      inputFormatters: widget.inputFormatters,
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
        // Mismo r15 de marca al deshabilitar — sin esto el decorator cae
        // al border del tema global (r12) y el campo cambia de forma
        // durante el submit del sheet.
        disabledBorder: border,
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
