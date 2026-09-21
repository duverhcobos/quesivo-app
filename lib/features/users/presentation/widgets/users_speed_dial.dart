import 'package:flutter/material.dart';
import 'package:quesivo/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../shell/presentation/widgets/shell_insets.dart';

/// Speed dial del listado de usuarios (§48) — el FAB amarillo ahora
/// expande dos acciones porque el backend 058 separó las intenciones
/// que `POST /auth/users` fusionaba: "Crear usuario" (alta nueva) y
/// "Vincular existente" (solo membresía para un user con cuenta global).
///
/// Mecánica: el tap en el FAB morfa el ícono `person_add_outlined` →
/// `close` y las dos acciones suben con fade+slide ~200ms sobre un
/// scrim TRANSPARENTE a pantalla completa (tap afuera cierra). El scrim
/// va por `OverlayEntry` sobre el overlay RAÍZ (`rootOverlay: true` —
/// mismo motivo del `useRootNavigator` de los sheets): el widget vive
/// anclado abajo-derecha del Stack (`Positioned right:24 /
/// bottom:nav+16`) dentro del navigator del branch del StatefulShellRoute,
/// cuyo overlay no cubre el QuesivoNavBar del shell — en el overlay raíz
/// el scrim cubre todo, igual que el FAB actual tapa el nav.
///
/// Cada acción = label en pill blanca a la izquierda + mini botón
/// circular navy con ícono blanco (paleta de marca). El widget solo
/// conoce los callbacks `onCreate`/`onLink` — qué sheet abre cada uno
/// lo decide la screen.
class UsersSpeedDial extends StatefulWidget {
  const UsersSpeedDial({
    super.key,
    required this.onCreate,
    required this.onLink,
  });

  /// Acción "Crear usuario" — se dispara tras cerrar el dial.
  final VoidCallback onCreate;

  /// Acción "Vincular existente" — se dispara tras cerrar el dial.
  final VoidCallback onLink;

  @override
  State<UsersSpeedDial> createState() => _UsersSpeedDialState();
}

class _UsersSpeedDialState extends State<UsersSpeedDial>
    with SingleTickerProviderStateMixin {
  /// Fade+slide de las acciones (~200ms según la propuesta).
  static const _animDuration = Duration(milliseconds: 200);

  /// Gap vertical entre el borde superior del FAB (56px) y la primera
  /// acción, y entre acciones.
  static const _actionsGap = 16.0;
  static const _fabSize = 56.0;

  late final AnimationController _controller;
  OverlayEntry? _overlayEntry;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);
  }

  @override
  void dispose() {
    // El entry pudo quedar insertado si el dial se desmonta abierto —
    // se retira antes de disponer el controller que lo anima.
    _removeEntry();
    _controller.dispose();
    super.dispose();
  }

  void _removeEntry() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    entry?.remove();
  }

  void _toggle() => _open ? _close() : _openDial();

  void _openDial() {
    // Defensa: el FAB sigue activable por teclado/lector de pantalla
    // durante el reverse del cierre (el scrim no captura ese foco) — si
    // un entry viejo sigue insertado, quedaría huérfano para siempre.
    _removeEntry();
    setState(() => _open = true);
    // Overlay RAÍZ (rootOverlay: true — mismo motivo del useRootNavigator
    // de los sheets): el widget vive dentro del navigator del branch del
    // StatefulShellRoute, cuyo overlay NO cubre el QuesivoNavBar del
    // shell — en el overlay raíz el scrim cubre TODA la pantalla y el
    // tap-afuera también cierra sobre el nav (sin disparar lo de abajo).
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    _controller.forward();
  }

  Future<void> _close() async {
    if (!_open) return;
    setState(() => _open = false);
    // Salida animada dentro del entry — se retira al terminar el
    // reverse. TickerCanceled: el widget se desmontó con el dial
    // abierto y dispose ya retiró el entry + controller.
    try {
      await _controller.reverse();
    } on TickerCanceled {
      return;
    }
    _removeEntry();
  }

  /// Cierra el dial y luego dispara la acción — el sheet que abre la
  /// screen queda por encima del overlay del dial.
  void _runAction(VoidCallback action) {
    _close();
    action();
  }

  /// Scrim + acciones dentro del overlay raíz. Las acciones se apilan
  /// sobre el FAB respetando su misma esquina (right 24 / bottom
  /// nav+16) — el FAB mide 56px, así que la primera acción arranca
  /// `fabSize + gap` por encima de ese margen.
  Widget _buildOverlay(BuildContext overlayContext) {
    final l10n = AppLocalizations.of(overlayContext)!;
    final slide = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return Stack(
      children: [
        // Scrim transparente a pantalla completa — tap afuera cierra.
        // BlockSemantics: con el dial abierto, TalkBack/VoiceOver no
        // pueden alcanzar el contenido ni el FAB de abajo (a11y).
        Positioned.fill(
          child: BlockSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom:
              overlayContext.shellNavBarHeight + 16 + _fabSize + _actionsGap,
          child: FadeTransition(
            opacity: _controller,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(slide),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SpeedDialAction(
                    label: l10n.fabLinkUser,
                    icon: Icons.link_outlined,
                    onTap: () => _runAction(widget.onLink),
                  ),
                  const SizedBox(height: 12),
                  _SpeedDialAction(
                    label: l10n.fabCreateUser,
                    icon: Icons.person_add_outlined,
                    onTap: () => _runAction(widget.onCreate),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Mismo FAB circular amarillo de siempre: person_add ↔ close morfa
    // según el estado del dial (el label vive en el tooltip para a11y).
    return FloatingActionButton(
      onPressed: _toggle,
      tooltip: l10n.newUserButton,
      backgroundColor: AppColors.quesivoYellow,
      foregroundColor: AppColors.quesivoNavy,
      shape: const CircleBorder(),
      child: AnimatedSwitcher(
        duration: _animDuration,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          _open ? Icons.close : Icons.person_add_outlined,
          key: ValueKey<bool>(_open),
        ),
      ),
    );
  }
}

/// Acción del speed dial: pill blanca con el label a la izquierda +
/// mini botón circular navy con ícono blanco a la derecha. Ambas mitades
/// disparan el mismo `onTap` (el label es el target principal).
class _SpeedDialAction extends StatelessWidget {
  const _SpeedDialAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppColors.quesivoWhite,
          borderRadius: BorderRadius.circular(24),
          elevation: 4,
          shadowColor: AppColors.quesivoShadow,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.quesivoNavy,
                  // El entry del overlay no tiene Scaffold/Material de
                  // tema encima — sin esto el texto heredaría el
                  // decoration de fallback (subrayado amarillo).
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: AppColors.quesivoNavy,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: AppColors.quesivoShadow,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 20, color: AppColors.quesivoWhite),
            ),
          ),
        ),
      ],
    );
  }
}
