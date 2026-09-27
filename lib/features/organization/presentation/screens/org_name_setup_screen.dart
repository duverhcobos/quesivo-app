import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_loader.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../../../core/widgets/quesivo_toast.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/auth_heading.dart';
import '../../../auth/presentation/widgets/quesivo_brand_header.dart';
import '../../domain/failures/organization_failure.dart';
import '../cubit/org_name_setup_cubit.dart';
import '../cubit/org_name_setup_state.dart';

/// Pantalla "¿Cómo se llama tu quesera?" (propuesta 71 — backend 087;
/// obligatoria desde propuesta 72 — sin opción de omitir).
///
/// Post-signup por Google la org nació con el nombre de la cuenta: el
/// `AuthGuard` fuerza esta ruta mientras `user.isNewSignup` sea true
/// (persistente — reaparece tras restart hasta completar). "Guardar"
/// hace `PATCH /organizations/me`, el flag se limpia y el guard rutea
/// a /home solo — la pantalla no navega.
///
/// El `OrgNameSetupCubit` lo provee la GoRoute (factory DI) — esta vista
/// es dumb: lee estado y repinta.
class OrgNameSetupScreen extends StatefulWidget {
  const OrgNameSetupScreen({super.key});

  @override
  State<OrgNameSetupScreen> createState() => _OrgNameSetupScreenState();
}

class _OrgNameSetupScreenState extends State<OrgNameSetupScreen> {
  /// El nombre que el signup generó a partir de la cuenta Google
  /// pre-llena el campo — el usuario edita sobre él, no escribe de cero.
  late final String _originalName;
  late String _name;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state;
    _originalName = auth is AuthSuccess
        ? (auth.user.organizationName ?? '')
        : '';
    _name = _originalName;
  }

  /// Guardar queda disabled solo con el campo vacío — desde §72 el
  /// paso es obligatorio (no hay skip): confirmar el nombre generado
  /// también debe ser válido, un PATCH con el mismo nombre es
  /// idempotente y limpia el flag igual.
  bool get _canSubmit => _name.trim().isNotEmpty;

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<OrgNameSetupCubit>().submit(_name.trim());
  }

  String _failureText(AppLocalizations l10n, OrganizationFailure? failure) =>
      switch (failure) {
        OrganizationNetworkFailure() => l10n.orgNameSetupErrorOffline,
        _ => l10n.orgNameSetupErrorGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    // Form congelado durante el submit: el campo no acepta edición —
    // los args ya fueron capturados.
    final isSubmitting = context.select<OrgNameSetupCubit, bool>(
      (c) => c.state.isSubmitting,
    );

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        // Mismo criterio que el resto de auth: solo el círculo amarillo.
        topCircleFraction: 0.68,
        bottomCircleFraction: 0,
        child: BlocListener<OrgNameSetupCubit, OrgNameSetupState>(
          listenWhen: (previous, current) =>
              current.failure != null && previous.failure != current.failure,
          listener: (context, state) {
            QuesivoToast.error(
              context,
              message: _failureText(l10n, state.failure),
            );
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.075),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // --- Imagen de marca (~62% ancho, §brand_header) ---
                  const QuesivoBrandHeader(logoFraction: 0.62),

                  AuthHeading(
                    title: l10n.orgNameSetupTitle,
                    description: l10n.orgNameSetupDescription,
                    titleHeight: 1.05,
                    titleGap: 16,
                    descriptionColor: AppColors.quesivoTextSecondary,
                    descriptionMaxLines: 3,
                    descriptionHeight: 1.45,
                  ),

                  // --- Nombre de la quesera (pre-llenado) ---
                  QuesivoTextField(
                    hintText: l10n.orgNameSetupFieldLabel,
                    prefixIcon: Icons.storefront_outlined,
                    keyboardType: TextInputType.name,
                    initialValue: _originalName,
                    enabled: !isSubmitting,
                    onChanged: (value) => setState(() => _name = value),
                  ),
                  const SizedBox(height: 36),

                  // --- Acciones: submit → loader en vuelo (el bloque
                  // entero cede, patrón de los forms de auth). El select
                  // de isSubmitting de arriba ya reconstruye el build —
                  // sin BlocBuilder anidado (revisión 71).
                  if (isSubmitting)
                    Center(
                      child: QuesivoLoader(
                        size: 32,
                        semanticLabel: l10n.loadingLabel,
                      ),
                    )
                  else
                    QuesivoPrimaryButton(
                      label: l10n.orgNameSetupSubmit,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
