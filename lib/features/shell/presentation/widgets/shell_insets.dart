import 'package:flutter/material.dart';

import 'quesivo_nav_bar.dart';
import 'shell_header.dart';

/// Insets que reserva cada pantalla hija del shell (§39 — body en Stack
/// edge-to-edge). El `ShellHeader` y la `QuesivoNavBar` flotan sobre el
/// contenido: cada pantalla decide si su fondo llega al borde (hero navy
/// que se fusiona con la banda) o si su contenido empieza debajo. Estas
/// extensiones son la única fuente de verdad de "cuánto ocupa el chrome".
extension ShellInsets on BuildContext {
  /// Alto total del `ShellHeader`: inset del status bar + contenido navy.
  /// Como padding superior del contenido — o como aire dentro de un hero
  /// navy que pinta detrás de la banda.
  double get shellHeaderHeight =>
      MediaQuery.paddingOf(this).top + ShellHeader.contentHeight;

  /// Alto total de la `QuesivoNavBar`: lámina de 74 + inset inferior del
  /// sistema (barra de gestos). Como padding inferior de contenido
  /// scrolleable — el último ítem puede subir por encima del nav.
  double get shellNavBarHeight =>
      MediaQuery.paddingOf(this).bottom + QuesivoNavBar.height;
}
