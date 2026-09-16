import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Avatar de iniciales del shell — círculo `quesivoYellow` con las
/// iniciales del usuario en navy (máx. 2 letras mayúsculas de las dos
/// primeras palabras, '?' si vacío). Lo comparten `ShellHeader`
/// (44px/15 con anillo) y `DrawerIdentity` (56px/18) para que ambos
/// muestren la misma identidad. Cuando el backend traiga foto, el
/// contenido se reemplaza por `CircleAvatar`/imagen dentro del mismo
/// círculo.
class UserInitialAvatar extends StatelessWidget {
  const UserInitialAvatar({
    super.key,
    required this.displayName,
    this.size = 44,
    this.fontSize = 15,
    this.withRing = false,
  });

  final String displayName;
  final double size;
  final double fontSize;

  /// Anillo blanco 20% que separa el círculo del fondo navy — solo lo usa
  /// el `ShellHeader`; sobre la tarjeta navy del drawer no hace falta.
  final bool withRing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.quesivoYellow,
        shape: BoxShape.circle,
        border: withRing
            ? Border.all(
                color: AppColors.quesivoWhite.withValues(alpha: 0.2),
                width: 1.5,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(displayName),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.quesivoNavy,
        ),
      ),
    );
  }
}

/// Hasta 2 letras mayúsculas de las dos primeras palabras — '?' si el
/// nombre viene vacío.
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
