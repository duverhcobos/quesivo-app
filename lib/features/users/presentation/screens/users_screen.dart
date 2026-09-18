import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quesivo_backdrop.dart';
import '../../../../core/widgets/quesivo_primary_button.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user_role.dart';
import '../widgets/org_member_card.dart';
import '../widgets/users_empty_state.dart';

/// Pantalla principal del módulo Usuarios (`/home/usuarios` — hija del
/// branch Inicio, propuesta 37). Solo UI: el listado se pinta con
/// `_sampleMembers` estáticos hasta la propuesta que integre
/// `GET /auth/users`; "Nuevo usuario" y las acciones de fila son
/// placeholders visuales (el sheet de creación y los diálogos llegan
/// con sus propias propuestas).
///
/// Misma envoltura visual que `ModulePlaceholderScreen`: backdrop de
/// marca + arco navy abajo-derecha, dentro del `MainLayout` (header y
/// nav bar quedan del shell).
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  /// Filas de muestra para validar el diseño de la card y los chips —
  /// se eliminan al integrar `GET /auth/users`. `final` (no `const`)
  /// para que el check `isEmpty` no quede evaluado en compile-time.
  static final _sampleMembers = <OrgMember>[
    const OrgMember(
      id: 'sample-1',
      email: 'ana.perez@mail.com',
      name: 'Ana Pérez',
      role: UserRole.admin,
      status: MemberStatus.active,
      organizationId: 'sample-org',
    ),
    const OrgMember(
      id: 'sample-2',
      email: 'juan.gomez@mail.com',
      name: 'Juan Gómez',
      role: UserRole.operator,
      status: MemberStatus.active,
      organizationId: 'sample-org',
    ),
    const OrgMember(
      id: 'sample-3',
      email: 'pedro.ruiz@mail.com',
      name: 'Pedro Ruiz',
      role: UserRole.collector,
      status: MemberStatus.suspended,
      organizationId: 'sample-org',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.quesivoWhite,
      body: QuesivoBackdrop(
        topCircleFraction: 0.5,
        bottomCircleFraction: 0,
        animate: false,
        child: Stack(
          children: [
            // Arco navy abajo-derecha — misma decoración que el
            // placeholder del módulo (Positioned negativo + ClipOval).
            Positioned(
              bottom: -screenWidth * 0.275,
              right: -screenWidth * 0.275,
              child: ClipOval(
                child: ColoredBox(
                  color: AppColors.quesivoNavy,
                  child: SizedBox(
                    width: screenWidth * 0.55,
                    height: screenWidth * 0.55,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (context.canPop())
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.quesivoNavy,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.orgUsersItem,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.quesivoNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.usersSubtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.quesivoTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          QuesivoPrimaryButton(
                            label: l10n.newUserButton,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.moduleComingSoon)),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _sampleMembers.isEmpty
                                ? const UsersEmptyState()
                                : ListView.separated(
                                    itemCount: _sampleMembers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) =>
                                        OrgMemberCard(
                                          member: _sampleMembers[index],
                                        ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
