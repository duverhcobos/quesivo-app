/// Fuente de verdad para saber si el usuario ya vio el onboarding.
///
/// SOLID (DIP): los consumidores (AuthGuard, OnboardingScreen) dependen de esta
/// interfaz, no de SharedPreferences. Se carga una sola vez al arrancar la app
/// (AppBootstrap, antes de `setupDI()` resolver el resto del grafo) para que
/// el guard pueda leer el flag de forma síncrona en cada redirect.
///
/// Excepción arquitectónica consciente: `AuthGuard` y `OnboardingScreen`
/// consumen esta interfaz de `data/` directamente, sin mediar un caso de uso
/// de `domain/`. Se decidió así porque es un flag de UI (no una regla de
/// negocio) y el feature no tiene entidades de dominio propias — agregar una
/// capa `domain/` solo para este flag sería sobre-ingeniería. Si `onboarding`
/// gana lógica de negocio real en el futuro, introducir la capa `domain/` en
/// ese momento.
abstract class IOnboardingStatusStore {
  /// `true` si el carrusel ya se completó o se saltó alguna vez.
  bool get isSeen;

  /// Persiste `isSeen = true` (al terminar o saltar el carrusel).
  Future<void> markSeen();
}
