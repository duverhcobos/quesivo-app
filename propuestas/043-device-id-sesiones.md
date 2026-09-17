# Propuesta: enviar `deviceId`/`deviceName` en login/register (sesiones por dispositivo)

El backend (propuesta 048) acepta `deviceId`/`deviceName` opcionales en
`POST /auth/login` y `POST /auth/register`, los guarda en `user_sessions`, los
hereda en cada rotación de refresh, y `POST /auth/logout` revoca **todas las
sesiones del dispositivo**. La app debe enviar el ID real del dispositivo con
`device_info_plus` (Android ID / iOS `identifierForVendor`).

⚠️ **Nativo**: `device_info_plus` es un plugin con código nativo → este cambio
**no sale por `shorebird patch`**. Requiere `shorebird release` nuevo +
reinstalación en el dispositivo.

Decisión de capa: el `deviceId` es metadato de transporte, no dato de dominio —
las firmas del repo/datasource **no cambian**. `RemoteAuthDataSourceImpl`
resuelve el device internamente vía un servicio inyectado (tests de repo
intactos).

Depende de: backend `propuestas/048-sesiones-por-dispositivo.md` desplegada.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | `flutter pub add device_info_plus` |
| `lib/core/device/i_device_info_service.dart` | **nuevo** — interfaz |
| `lib/core/device/device_info_service_impl.dart` | **nuevo** — wrapper de `DeviceInfoPlugin` con cache |
| `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart` | ctor + campos en login/register |
| `lib/core/di/setup_di.dart` | registrar servicio + actualizar ctor del datasource |
| `pubspec.yaml` + `Environment.appVersion` | bump de versión (release nuevo) |

Sin cambios de i18n, UI, rutas ni repo — firmas públicas intactas.

---

## 1. `pubspec.yaml` (dependencias)

```powershell
flutter pub add device_info_plus android_id
```

(`device_info_plus` para modelo/vendor en iOS; **`android_id` para el
ANDROID_ID real en Android** — el `id` de `device_info_plus` es `Build.ID`,
idéntico en todos los dispositivos con la misma ROM, no sirve para agrupar
sesiones. Sin permisos extra en ninguna plataforma.)

## 2. `i_device_info_service.dart` (archivo nuevo)

**Ruta:** `lib/core/device/i_device_info_service.dart`

```dart
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
```

## 3. `device_info_service_impl.dart` (archivo nuevo)

**Ruta:** `lib/core/device/device_info_service_impl.dart`

```dart
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
```

## 4. `remote_auth_datasource_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/remote_auth_datasource_impl.dart`

**Antes:**

```dart
import '../../../../../core/constants/environment/environment.dart';
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/user_model.dart';
import '../interfaces/i_remote_auth_datasource.dart';

/// Implementación ÚNICA del DataSource remoto.
///
/// SOLID (DIP): Ahora esta clase no depende ni de Dio ni de Http.
/// Depende del `INetworkService` central de la app. Si cambias
/// el proveedor de red, esta clase NUNCA cambiará.
class RemoteAuthDataSourceImpl implements IRemoteAuthDataSource {
  final INetworkService networkService;

  RemoteAuthDataSourceImpl(this.networkService);
```

**Después:**

```dart
import '../../../../../core/constants/environment/environment.dart';
import '../../../../../core/device/i_device_info_service.dart';
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/user_model.dart';
import '../interfaces/i_remote_auth_datasource.dart';

/// Implementación ÚNICA del DataSource remoto.
///
/// SOLID (DIP): Ahora esta clase no depende ni de Dio ni de Http.
/// Depende del `INetworkService` central de la app. Si cambias
/// el proveedor de red, esta clase NUNCA cambiará.
class RemoteAuthDataSourceImpl implements IRemoteAuthDataSource {
  final INetworkService networkService;
  final IDeviceInfoService deviceInfoService;

  RemoteAuthDataSourceImpl(this.networkService, this.deviceInfoService);
```

**Antes (login):**

```dart
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
```

**Después:**

```dart
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        // Metadatos del dispositivo para la sesión (propuesta 43) —
        // opcionales server-side; sin ellos el logout no agrupa por device.
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );
```

**Antes (register):**

```dart
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'organizationName': organizationName,
        'name': name,
        'email': email,
        'password': password,
      },
    );
```

**Después:**

```dart
    final responseData = await networkService.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'organizationName': organizationName,
        'name': name,
        'email': email,
        'password': password,
        'deviceId': await deviceInfoService.getDeviceId(),
        'deviceName': await deviceInfoService.getDeviceName(),
      },
    );
```

## 5. `setup_di.dart` (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**

```dart
  locator.registerLazySingleton<IRemoteAuthDataSource>(
    // EL DATASOURCE AHORA ES ÚNICO Y GENÉRICO
    () => RemoteAuthDataSourceImpl(locator<INetworkService>()),
  );
```

**Después:**

```dart
  locator.registerLazySingleton<IDeviceInfoService>(
    () => DeviceInfoServiceImpl(DeviceInfoPlugin()),
  );
  locator.registerLazySingleton<IRemoteAuthDataSource>(
    // EL DATASOURCE AHORA ES ÚNICO Y GENÉRICO
    () => RemoteAuthDataSourceImpl(
      locator<INetworkService>(),
      locator<IDeviceInfoService>(),
    ),
  );
```

(+ los `import` correspondientes arriba: `device_info_plus`,
`core/device/i_device_info_service.dart`,
`core/device/device_info_service_impl.dart`).

## 6. Bump de versión (release nuevo — plugin nativo)

`pubspec.yaml`: `version: 0.1.0+1` → `0.2.0+2` y
`lib/core/constants/environment/environment.dart`: `appVersion` → `'0.2.0'`
(skill `release-build`: ambos deben ir sincronizados antes del release).

## Tests

- Repo specs: **sin cambios** — la firma pública no cambió (el datasource
  resuelve el device internamente).
- El mock `MockRemoteAuthDataSource` de mocktail auto-implementa la clase —
  sin cambios.
- `DeviceInfoServiceImpl` es un wrapper fino del canal nativo — no lleva
  unit test propio (no hay lógica que probar sin mockear la plataforma;
  `_read` ya degrada a `null` seguro si el canal falla).
- Si existe spec del datasource remoto que instancie
  `RemoteAuthDataSourceImpl` directo, agregar un `MockDeviceInfoService`
  (mocktail) stubbeando `getDeviceId()`/`getDeviceName()`.

---

## Orden de aplicación recomendado

1. `flutter pub add device_info_plus`.
2. `lib/core/device/i_device_info_service.dart` + impl.
3. `remote_auth_datasource_impl.dart` — ctor + bodies.
4. `setup_di.dart` — registro.
5. Bump de versión (`pubspec.yaml` + `Environment.appVersion`).
6. `flutter analyze` + `flutter test`.

## Verificación

- `flutter analyze` limpio, `flutter test` verde.
- Release nuevo: `shorebird release android --dart-define-from-file=shorebird-stg.json`
  (plugin nativo → NO vale patch).
- Manual: login con la build nueva → `SELECT device_id, device_name FROM
  user_sessions ORDER BY created_at DESC` → fila con `device_id` poblado
  y `device_name` = modelo del cel.
- Logout por dispositivo: login dos veces → 2 filas con el mismo
  `device_id` → logout → ambas `revoked=true`.
