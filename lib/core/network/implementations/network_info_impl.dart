import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../interfaces/i_network_info.dart';

/// Implementación concreta de INetworkInfo usando 'internet_connection_checker'.
///
/// SOLID (DIP): Inyectamos la librería de terceros en lugar de instanciarla
/// directamente, lo que permite pasar un Mock de `InternetConnectionChecker`
/// durnate nuestras pruebas unitarias.
class NetworkInfoImpl implements INetworkInfo {
  final InternetConnectionChecker connectionChecker;

  NetworkInfoImpl(this.connectionChecker);

  @override
  Future<bool> get isConnected => connectionChecker.hasConnection;
}
