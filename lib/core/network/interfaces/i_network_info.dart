abstract class INetworkInfo {
  /// Verifica asíncronamente si el dispositivo tiene acceso real a Internet,
  /// no solo si está conectado a una red Wifi local.
  ///
  /// SOLID (SRP y DIP): Centralizamos la verificación de red en una interfaz.
  /// Los Repositorios dependen de esta abstracción y no de una librería de terceros.
  Future<bool> get isConnected;
}
