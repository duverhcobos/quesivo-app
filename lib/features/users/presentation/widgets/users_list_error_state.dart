import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';

/// Estado de error del listado de Usuarios (§49) — `GET /auth/users`
/// falló en la carga inicial o en el refresh (red/403/429/5xx). Mismo
/// lenguaje visual que `UsersEmptyState`: círculo iconSurface con
/// ícono navy + mensaje + primario de marca que relanza
/// `UsersListCubit.load()`.
class UsersListErrorState extends StatelessWidget {
  const UsersListErrorState({super.key, required this.onRetry, this.message});

  /// Tap del botón reintentar — la screen lo cablea a `cubit.load()`.
  final VoidCallback onRetry;

  /// Texto del estado — default `l10n.usersLoadError`; la screen pasa
  /// `tooManyAttemptsError` cuando el failure fue 429 (rate limit).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.quesivoIconSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.quesivoNavy,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message ?? l10n.usersLoadError,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.quesivoNavy,
              ),
            ),
          ),
          const SizedBox(height: 20),
          QuesivoPrimaryButton(
            label: l10n.retryButton,
            fullWidth: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
