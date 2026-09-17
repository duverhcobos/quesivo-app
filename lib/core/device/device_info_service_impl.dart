import 'dart:io' show Platform;

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'i_device_info_service.dart';

/// Wrapper fino sobre `DeviceInfoPlugin`/`AndroidId` con cache en memoria —
/// los valores no cambian en runtime y el canal nativo no es gratis por
/// llamada.
class DeviceInfoServiceImpl implements IDeviceInfoService {
  DeviceInfoServiceImpl(this._plugin);

  final DeviceInfoPlugin _plugin;
  final AndroidId _androidId = const AndroidId();

  Future<({String? id, String? name})>? _cached;

  Future<({String? id, String? name})> _resolve() {
    final future = _cached ??= _read();
    // No memoizar el fallo: si el canal falló una vez, la próxima llamada
    // reintenta en vez de quedarse sin deviceId toda la sesión.
    return future.then((result) {
      if (result.id == null) _cached = null;
      return result;
    });
  }

  Future<({String? id, String? name})> _read() async {
    try {
      if (Platform.isAndroid) {
        // ANDROID_ID real: device_info_plus v4+ ya no lo expone — su `id`
        // es Build.ID (igual en todos los dispositivos con la misma ROM),
        // así que rompería la agrupación por dispositivo del logout.
        final id = await _androidId.getId();
        final info = await _plugin.androidInfo;
        return (id: id, name: info.model);
      }
      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        return (id: info.identifierForVendor, name: info.utsname.machine);
      }
    } catch (_) {
      // Canal nativo no disponible (tests, plataforma rara): la sesión se
      // crea sin deviceId — el backend lo trata como legacy.
    }
    return (id: null, name: null);
  }

  @override
  Future<String?> getDeviceId() async => (await _resolve()).id;

  @override
  Future<String?> getDeviceName() async => (await _resolve()).name;
}
