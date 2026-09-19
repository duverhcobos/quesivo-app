import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Un requisito de contraseña ya evaluado: si se cumple + su label l10n.
class PasswordRequirementItem {
  const PasswordRequirementItem({required this.met, required this.label});

  final bool met;
  final String label;
}

/// Checklist vivo de requisitos de contraseña (§register_form → core
/// widgets): pinta filas check/pendiente y nada más.
///
/// SOLID (SRP): el widget NO conoce la política — cada feature evalúa
/// `met` con su propia fuente de verdad y la pasa por [items]:
/// auth usa los estáticos del VO `RegisterPassword`, el sheet de creación
/// de usuario usa sus espejos locales de `RegisterDto` del backend. Así
/// core no importa de features (antes el widget vivía en auth y llamaba
/// al VO directamente — inmovible por acoplamiento feature→feature).
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<PasswordRequirementItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.quesivoDarkText,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items) ...[
          _RequirementRow(met: item.met, label: item.label),
          if (item != items.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.quesivoSuccess : AppColors.quesivoPlaceholder;
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: color)),
      ],
    );
  }
}
