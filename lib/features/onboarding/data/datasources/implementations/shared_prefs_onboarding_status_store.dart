import 'package:shared_preferences/shared_preferences.dart';

import '../interfaces/i_onboarding_status_store.dart';

/// Persiste el flag `has_seen_onboarding` en SharedPreferences
/// (almacenamiento plano — no es un secreto, no va en secure storage).
class SharedPrefsOnboardingStatusStore implements IOnboardingStatusStore {
  static const _key = 'has_seen_onboarding';

  final SharedPreferences _prefs;
  bool _isSeen = false;

  SharedPrefsOnboardingStatusStore(this._prefs);

  /// Lee el flag persistido. Se invoca una sola vez desde el registro
  /// async en `setup_di.dart`, resuelto por `locator.allReady()` en bootstrap.
  Future<void> load() async {
    _isSeen = _prefs.getBool(_key) ?? false;
  }

  @override
  bool get isSeen => _isSeen;

  @override
  Future<void> markSeen() async {
    _isSeen = true;
    await _prefs.setBool(_key, true);
  }
}
