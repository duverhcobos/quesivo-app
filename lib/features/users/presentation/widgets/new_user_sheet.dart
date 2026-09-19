import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../../../core/widgets/quesivo_text_field.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import 'role_selector_chips.dart';

/// Bottom sheet de creación de usuario (§44) — el primero de la app.
/// Solo UI: valida el form y devuelve el `OrgMember` construido vía
/// `Navigator.pop`; la integración de `POST /auth/users` lo reemplaza
/// por la llamada real sin tocar este widget (misma respuesta visual).
///
/// Validación manual al submit — `QuesivoTextField` expone `errorText`
/// (patrón del proyecto: el error llega de afuera, no de un `validator`
/// interno). La política de password espeja `RegisterDto` del backend
/// (min 8, mayúscula, minúscula, dígito — doc 007-post-users.md); la
/// propuesta de integración introduce el VO de dominio correspondiente.
class NewUserSheet extends StatefulWidget {
  const NewUserSheet({super.key});

  /// Abre el sheet y devuelve el miembro creado, o `null` si se canceló.
  static Future<OrgMember?> show(BuildContext context) {
    return showModalBottomSheet<OrgMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.quesivoWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const NewUserSheet(),
    );
  }

  @override
  State<NewUserSheet> createState() => _NewUserSheetState();
}

class _NewUserSheetState extends State<NewUserSheet> {
  // Espejo local de la política del backend — la integración introduce
  // el VO de dominio (misma regla que RegisterPassword de auth).
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  static final _hasLower = RegExp(r'[a-z]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasDigit = RegExp(r'\d');

  String _name = '';
  String _email = '';
  String _password = '';
  UserRole? _role;

  bool _nameError = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _roleError = false;

  bool get _validPassword =>
      _password.length >= 8 &&
      _hasLower.hasMatch(_password) &&
      _hasUpper.hasMatch(_password) &&
      _hasDigit.hasMatch(_password);

  void _submit() {
    final name = _name.trim();
    final email = _email.trim().toLowerCase();
    setState(() {
      _nameError = name.isEmpty;
      _emailError = !_emailRegex.hasMatch(email);
      _passwordError = !_validPassword;
      _roleError = _role == null;
    });
    if (_nameError || _emailError || _passwordError || _roleError) return;

    Navigator.of(context).pop(
      OrgMember(
        // Id sintético — la integración devuelve el uuid del backend.
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        email: email,
        name: name,
        role: _role!,
        status: MemberStatus.active,
        organizationId: 'sample-org',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      // El sheet sube entero sobre el teclado.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.quesivoBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.newUserButton,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.quesivoNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.newUserSheetHint,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.quesivoTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            QuesivoTextField(
              hintText: l10n.fullNamePlaceholder,
              prefixIcon: Icons.person_outline,
              keyboardType: TextInputType.name,
              errorText: _nameError ? l10n.invalidMemberNameError : null,
              onChanged: (v) => setState(() {
                _name = v;
                _nameError = false;
              }),
            ),
            const SizedBox(height: 14),
            QuesivoTextField(
              hintText: l10n.registerEmailPlaceholder,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError ? l10n.invalidEmailError : null,
              onChanged: (v) => setState(() {
                _email = v;
                _emailError = false;
              }),
            ),
            const SizedBox(height: 14),
            // Visible a propósito: es una contraseña temporal que el
            // admin inventa y le comparte al usuario a mano — ocultarla
            // solo dificultaría tipearla/dictarla sin typos.
            QuesivoTextField(
              hintText: l10n.tempPasswordPlaceholder,
              prefixIcon: Icons.lock_outline,
              errorText: _passwordError ? l10n.invalidTempPasswordError : null,
              onChanged: (v) => setState(() {
                _password = v;
                _passwordError = false;
              }),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.roleFieldLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.quesivoNavy,
              ),
            ),
            const SizedBox(height: 8),
            RoleSelectorChips(
              selected: _role,
              onChanged: (role) => setState(() {
                _role = role;
                _roleError = false;
              }),
            ),
            if (_roleError) ...[
              const SizedBox(height: 6),
              Text(
                l10n.roleRequiredError,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            QuesivoPrimaryButton(
              label: l10n.createUserButton,
              onPressed: _submit,
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l10n.cancelAction,
                  style: const TextStyle(
                    color: AppColors.quesivoTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
