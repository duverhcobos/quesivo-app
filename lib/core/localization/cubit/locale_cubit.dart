import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit que controla el idioma de toda la aplicación.
///
/// SOLID (SRP): Su única y excluyente responsabilidad es mantener
/// en memoria qué prefirió el usuario (Inglés o Español). No toca
/// preferencias persistentes locales ni lógicas de UI.
class LocaleCubit extends Cubit<Locale?> {
  // Arranca en nulo, lo que significa: "Usar automáticamente el idioma nativo del celular"
  LocaleCubit() : super(null);

  /// Obliga a la aplicación entera a reconstruirse con el nuevo idioma.
  void changeLocale(Locale locale) {
    emit(locale);
  }

  /// Borra la preferencia manual y vuelve a confiar en el SO.
  void clearLocale() {
    emit(null);
  }

  /// SOLID (SRP): La UI ya no necesita saber en qué orden van los idiomas.
  /// El Cubit asume toda la responsabilidad matemática de rotarlos.
  void toggleLanguage() {
    final code = state?.languageCode ?? 'es';

    if (code == 'es') {
      emit(const Locale('en'));
    } else if (code == 'en') {
      emit(const Locale('pt'));
    } else {
      emit(const Locale('es'));
    }
  }
}
