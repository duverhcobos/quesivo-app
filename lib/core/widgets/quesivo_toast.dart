import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_colors.dart';

/// Toast de feedback de Quesivo — pill flotante anclada ARRIBA (bajo el
/// status bar) con icono + texto, entrada slide/fade desde arriba y
/// auto-dismiss.
///
/// Reemplaza al SnackBar: la parte baja ya está ocupada por el
/// QuesivoNavBar persistente y el FAB — un toast abajo colisiona con
/// ambos. Arriba flota sobre el contenido sin tapar nada interactivo y
/// deja pasar los taps (IgnorePointer).
///
/// API SEMÁNTICA — el color/icono representan el estado del feedback,
/// no es decorativo (feedback del usuario):
/// ```dart
/// QuesivoToast.success(context, message: l10n.memberCreatedFeedback);
/// QuesivoToast.info(context, message: l10n.memberLinkedFeedback(name));
/// QuesivoToast.warning(context, message: l10n.memberSuspendedFeedback);
/// QuesivoToast.error(context, message: l10n.genericError);
/// ```
class QuesivoToast {
  const QuesivoToast._();

  static const _defaultHold = Duration(milliseconds: 2600);

  /// Entry del toast activo — UNO a la vez: mostrar uno nuevo retira el
  /// anterior (dos feedbacks dentro del hold se apilaban pills encimadas
  /// — el SnackBar que reemplazó encolaba, hallazgo de auditoría).
  static OverlayEntry? _current;

  /// Verde `quesivoSuccess` + check — operación completada con éxito
  /// (alta, reactivación, reset).
  static void success(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_outline,
    Duration duration = _defaultHold,
  }) => _show(
    context,
    message: message,
    icon: icon,
    backgroundColor: AppColors.quesivoSuccess,
    foregroundColor: AppColors.quesivoWhite,
    duration: duration,
  );

  /// Azul `quesivoInfo` + info — nota informativa, nada nuevo creado
  /// (ej. usuario global que solo quedó vinculado).
  static void info(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
    Duration duration = _defaultHold,
  }) => _show(
    context,
    message: message,
    icon: icon,
    backgroundColor: AppColors.quesivoInfo,
    foregroundColor: AppColors.quesivoWhite,
    duration: duration,
  );

  /// Ámbar `quesivoWarning` + warning — la operación dejó un estado
  /// restrictivo/atención (ej. membresía suspendida). Texto navy: el
  /// ámbar pide contraste oscuro.
  static void warning(
    BuildContext context, {
    required String message,
    IconData icon = Icons.warning_amber_rounded,
    Duration duration = _defaultHold,
  }) => _show(
    context,
    message: message,
    icon: icon,
    backgroundColor: AppColors.quesivoWarning,
    foregroundColor: AppColors.quesivoNavy,
    duration: duration,
  );

  /// Rojo `quesivoError` + error — operación fallida.
  static void error(
    BuildContext context, {
    required String message,
    IconData icon = Icons.error_outline,
    Duration duration = _defaultHold,
  }) => _show(
    context,
    message: message,
    icon: icon,
    backgroundColor: AppColors.quesivoError,
    foregroundColor: AppColors.quesivoWhite,
    duration: duration,
  );

  /// Inserta el toast en el overlay RAÍZ — cubre también sheets/modals
  /// abiertos. [duration]: tiempo visible antes de la salida animada.
  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required Duration duration,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _removeCurrent();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _QuesivoToastView(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        hold: duration,
        onDone: () {
          if (identical(_current, entry)) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    // Paridad a11y con el SnackBar reemplazado — el toast es
    // IgnorePointer sin Semantics propio; sin el announce TalkBack/
    // VoiceOver no enteran del feedback (peor: es el canal único del
    // error del backend).
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  /// Retira el toast activo si sigue insertado — `mounted` cubre el
  /// caso de que ya haya salido por su onDone natural.
  static void _removeCurrent() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _QuesivoToastView extends StatefulWidget {
  const _QuesivoToastView({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.hold,
    required this.onDone,
  });

  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Duration hold;
  final VoidCallback onDone;

  @override
  State<_QuesivoToastView> createState() => _QuesivoToastViewState();
}

class _QuesivoToastViewState extends State<_QuesivoToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();
    // La entrada es animada; el hold corre en FakeAsync-friendly
    // Future.delayed y la salida revierte el mismo controller.
    Future.delayed(widget.hold, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_removing || !mounted) return;
    _removing = true;
    try {
      await _controller.reverse();
    } on TickerCanceled {
      // El entry fue retirado externamente (replace por un toast nuevo)
      // o el overlay se desmontó — el controller ya está disposed.
      return;
    }
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        // Los taps pasan por debajo — el toast nunca bloquea la UI.
        child: IgnorePointer(
          child: Padding(
            // Casi todo el ancho (feedback del usuario) — 16px por lado.
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.35),
                end: Offset.zero,
              ).animate(slide),
              child: FadeTransition(
                opacity: slide,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    // r16 — lenguaje de cards del sistema, no pill r28
                    // (feedback del usuario: las esquinas stadium se
                    // veían demasiado pronunciadas).
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.quesivoNavy.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.icon,
                          size: 20,
                          color: widget.foregroundColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.foregroundColor,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
