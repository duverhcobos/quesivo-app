import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// Campo de búsqueda del listado de Usuarios — filtra por nombre o
/// correo sobre lo ya cargado (local; server-side query queda para
/// cuando `GET /auth/users` lo soporte). El ícono de limpiar solo
/// aparece con texto cargado (`ValueListenableBuilder` sobre el propio
/// `controller`, sin rebuild del padre).
class UsersSearchField extends StatelessWidget {
  const UsersSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.quesivoBorder),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          inputFormatters: [
            // Unión de lo buscable (nombre + email): regex local del
            // widget — es filtro de UI, no regla de dominio (§47).
            FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ@._%+\-' ]"),
            ),
          ],
          // Style explícito — sin él el texto tipeado hereda onSurface del
          // tema activo: en modo oscuro sale casi blanco sobre el fill
          // quesivoWhite forzado y no se lee (bug visto en físico). Mismo
          // criterio que QuesivoTextField.
          style: const TextStyle(
            color: AppColors.quesivoDarkText,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          cursorColor: AppColors.quesivoNavy,
          decoration: InputDecoration(
            hintText: l10n.searchUsersHint,
            hintStyle: const TextStyle(color: AppColors.quesivoTextSecondary),
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.quesivoTextSecondary,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.quesivoTextSecondary,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            filled: true,
            fillColor: AppColors.quesivoWhite,
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(
                color: AppColors.quesivoNavy,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
      },
    );
  }
}
