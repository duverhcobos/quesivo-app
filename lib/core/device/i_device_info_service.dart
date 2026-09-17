/// Identidad del dispositivo para sesiones server-side (propuesta 43 /
/// backend 048): `POST /auth/login|register` envían `deviceId`/`deviceName`
/// y `logout` revoca todas las sesiones del dispositivo.
///
/// SOLID (DIP): los consumidores dependen de la interfaz, no de
/// `device_info_plus` — si el plugin cambia, los consumidores no.
abstract class IDeviceInfoService {
  /// ID estable del dispositivo: ANDROID_ID real (paquete `android_id`) en
  /// Android — ojo, `device_info_plus` ya no lo expone — e
  /// `identifierForVendor` en iOS. `null` si la plataforma no lo expone.
  Future<String?> getDeviceId();

  /// Nombre legible — ej. "Pixel 8" / "iPhone15,2". `null` si no hay.
  Future<String?> getDeviceName();
}
