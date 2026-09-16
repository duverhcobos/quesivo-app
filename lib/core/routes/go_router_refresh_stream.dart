import 'dart:async';
import 'package:flutter/foundation.dart';

/// Adaptador para convertir un Stream (como el de Cubit/Bloc) en un Listenable.
/// Esto es necesario porque GoRouter requiere un Listenable para su propiedad
/// `refreshListenable`.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
