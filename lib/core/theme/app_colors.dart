import 'package:flutter/material.dart';

/// Paleta de Colores Centralizada — identidad "Quesivo"
///
/// SOLID (SRP): Ningún TextBox o Pantalla debe tener un color quemado ("hardcoded").
/// Las pantallas son "ciegas" a los colores reales. Solo conocen nombres abstractos.
///
/// El bloque light/dark es la paleta heredada del proyecto origen (pendiente de
/// migración a los tokens `quesivo*` de abajo — ver `Design/quesivo-design-system.yaml` §2).
class AppColors {
  // --- TEMA CLARO (LIGHT THEME) ---
  static const Color primaryLight = Color(0xFF224349); // teal — paleta heredada
  static const Color secondaryLight = Color(
    0xFF295B3C,
  ); // verde — paleta heredada
  static const Color accentLight = Color(
    0xFFCA602B,
  ); // terracota — paleta heredada
  static const Color backgroundLight = Color(0xFFFAFEFF);
  static const Color surfaceLight = Color(0xFFF6F8F8);
  static const Color textLight = Color(0xFF091415);
  static const Color errorLight = Color(0xFFB00020);

  // --- TEMA OSCURO (DARK THEME) ---
  static const Color primaryDark = Color(0xFFB6D7DD);
  static const Color secondaryDark = Color(0xFFA4D6B6);
  static const Color accentDark = Color(0xFFDF8F68);
  static const Color backgroundDark = Color(0xFF000405);
  static const Color surfaceDark = Color(0xFF0D1112);
  static const Color textDark = Color(0xFFEAF5F6);
  static const Color errorDark = Color(0xFFCF6679);

  // --- COLORES NEUTROS Y COMPARTIDOS ---
  static const Color grey = Colors.grey;
  static const Color transparent = Colors.transparent;

  // --- IDENTIDAD QUESIVO (Design/quesivo-design-system.yaml §2) ---
  // Tokens fijos de marca: las pantallas de identidad (splash, welcome, auth)
  // usan estos valores directos — no dependen del ColorScheme ni del modo oscuro.
  static const Color quesivoNavy = Color(0xFF07275C); // primary
  static const Color quesivoYellow = Color(0xFFF7A81D); // secondary_accent
  static const Color quesivoWhite = Color(0xFFFFFFFF); // background
  static const Color quesivoDarkText = Color(0xFF172033); // texto principal
  static const Color quesivoSurface = Color(0xFFF7F9FC); // tarjetas / secciones
  static const Color quesivoBorder = Color(0xFFE5EAF2); // bordes sutiles
  static const Color quesivoTextSecondary = Color(0xFF68758A);
  static const Color quesivoPlaceholder = Color(0xFF7A8499);
  static const Color quesivoIconSurface = Color(0xFFEEF2F7); // fondo de íconos
  static const Color quesivoShadow = Color(0x1F07275C); // sombra navy 12%
  static const Color quesivoBarrier = Color(0x59000000); // barrera modal 35%

  // Semánticos (§2 semantic_colors)
  static const Color quesivoSuccess = Color(0xFF2E9B62);
  static const Color quesivoWarning = Color(0xFFF2A900);
  static const Color quesivoError = Color(0xFFD64545);
  static const Color quesivoInfo = Color(0xFF3478C8);
}
