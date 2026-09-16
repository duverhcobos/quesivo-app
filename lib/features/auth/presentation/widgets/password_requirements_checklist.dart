import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/value_objects/register_password.dart';

/// Checklist vivo de los requisitos de `RegisterPassword` (§register_form).
///
/// SOLID (SRP): solo pinta filas check/pendiente — la regla de qué cuenta
/// como "cumplido" vive en el Value Object (única fuente de verdad).
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    super.key,
    required this.password,
    required this.title,
    required this.minLengthLabel,
    required this.uppercaseLabel,
    required this.lowercaseLabel,
    required this.digitLabel,
  });

  final String password;
  final String title;
  final String minLengthLabel;
  final String uppercaseLabel;
  final String lowercaseLabel;
  final String digitLabel;

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
        _RequirementRow(
          met: RegisterPassword.hasMinLength(password),
          label: minLengthLabel,
        ),
        const SizedBox(height: 6),
        _RequirementRow(
          met: RegisterPassword.hasUppercase(password),
          label: uppercaseLabel,
        ),
        const SizedBox(height: 6),
        _RequirementRow(
          met: RegisterPassword.hasLowercase(password),
          label: lowercaseLabel,
        ),
        const SizedBox(height: 6),
        _RequirementRow(
          met: RegisterPassword.hasDigit(password),
          label: digitLabel,
        ),
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
