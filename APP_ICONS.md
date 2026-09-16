# Íconos de la app — cómo están configurados

Guía de referencia para actualizar el ícono de QUESIVO: qué archivos intervienen,
para qué sirve cada uno y a dónde se copia.

---

## Cómo funciona el sistema de íconos en Android

Android usa **dos sistemas de ícono coexistiendo**, según la versión del
dispositivo:

### 1. Íconos adaptativos (API 26+, Android 8.0+)

En vez de una imagen fija, el ícono se compone de **capas** que el sistema
combina y recorta según la forma del launcher (círculo, squircle, gota…):

| Capa | Recurso | Qué es |
|------|---------|--------|
| `background` | `@color/ic_launcher_background` | Fondo — color plano `#FFFFFF` (blanco QUESIVO) |
| `foreground` | `@mipmap/ic_launcher_foreground` | El isotipo — PNG transparente dibujado más grande que el ícono final (la zona segura visible es ~el 66% central) |
| `monochrome` | `@mipmap/ic_launcher_monochrome` | Variante monocromática (solo alfa) — Android 13+ la tiñe con el color del tema del usuario ("themed icons") |

Los **descriptores** son XML en `res/mipmap-anydpi-v26/`:

- `ic_launcher.xml` — define el ícono adaptativo estándar (background + foreground + monochrome).
- `ic_launcher_round.xml` — la variante para launchers que piden forma circular.

`anydpi` significa "cualquier densidad": un solo XML sirve para todas las
pantallas — el sistema escoge el PNG de capa de la densidad adecuada.

### 2. PNGs legacy (API < 26)

`minSdk = 24` en `android/app/build.gradle.kts`, así que los dispositivos con
Android 7.x e inferiores **no entienden** los XML adaptativos y necesitan el
ícono ya renderizado:

- `res/mipmap-{density}/ic_launcher.png` — ícono cuadrado completo, pre-renderizado
  por densidad de pantalla.
- `res/mipmap-{density}/ic_launcher_round.png` — variante redonda, usada por
  launchers circulares cuando el manifest declara `android:roundIcon`.

Densidades y tamaño del ícono de launcher:

| Carpeta | Densidad | Tamaño típico |
|---------|----------|---------------|
| `mipmap-mdpi` | 1.0× | 48×48 px |
| `mipmap-hdpi` | 1.5× | 72×72 px |
| `mipmap-xhdpi` | 2.0× | 96×96 px |
| `mipmap-xxhdpi` | 3.0× | 144×144 px |
| `mipmap-xxxhdpi` | 4.0× | 192×192 px |

> Los PNGs de `foreground` y `monochrome` en cada `mipmap-*` son las **capas**
> para los XML adaptativos — van más grandes que el ícono final (~108dp de lienzo,
> ~72dp de contenido visible).

### 3. Referencias en el manifest

`android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:label="QUESIVO"                              <!-- nombre bajo el ícono -->
    android:icon="@mipmap/ic_launcher"                   <!-- ícono estándar -->
    android:roundIcon="@mipmap/ic_launcher_round">       <!-- ícono circular -->
```

En API ≥26, `@mipmap/ic_launcher` y `@mipmap/ic_launcher_round` resuelven a los
XML de `mipmap-anydpi-v26/`; en API <26 resuelven a los PNG de `mipmap-*/`.

### 4. Ícono de la Play Store

`store_assets/ic_launcher-playstore.png` — 512×512, **no se compila en el APK**:
es el asset que se sube a Play Console para la ficha de la tienda. Vive fuera de
`res/` a propósito.

---

## Mapa de archivos: qué se copia y por qué

Pack generado (carpeta `isotipo_quesivo/android/res/` o equivalente):

| Origen (pack) | Destino (proyecto) | Para qué |
|---------------|--------------------|----------|
| `mipmap-anydpi-v26/ic_launcher.xml` | `android/app/src/main/res/mipmap-anydpi-v26/` | Descriptor adaptativo estándar |
| `mipmap-anydpi-v26/ic_launcher_round.xml` | `android/app/src/main/res/mipmap-anydpi-v26/` | Descriptor adaptativo redondo |
| `values/ic_launcher_background.xml` | `android/app/src/main/res/values/` | Color de fondo del adaptativo (blanco) |
| `mipmap-{d}/ic_launcher.png` | `res/mipmap-{d}/` | Ícono legacy cuadrado (API <26) |
| `mipmap-{d}/ic_launcher_foreground.png` | `res/mipmap-{d}/` | Capa foreground del adaptativo |
| `mipmap-{d}/ic_launcher_monochrome.png` | `res/mipmap-{d}/` | Capa monocromática (Android 13+ themed icons) |
| `playstore-icon.png` | `store_assets/ic_launcher-playstore.png` | Ficha de Play Console (512×512) |

`{d}` = `hdpi`, `mdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi` (5 densidades).

### Excepciones del pack

- **`ic_launcher_round.png`**: el pack no lo genera (el redondo sale del XML
  adaptativo en API 26+). Como el manifest declara `roundIcon` y hay API <26,
  hay que duplicar `ic_launcher.png` → `ic_launcher_round.png` en cada
  `mipmap-{d}` del destino.
- **`README.txt`**: no se copia — son las instrucciones del generador.

---

## Procedimiento completo de actualización

1. Generar el pack con la imagen fuente del isotipo (ej.
   [appicon.ikit.app](https://appicon.ikit.app) — el que produjo
   `isotipo_quesivo/`; o `flutter_launcher_icons` si se prefiere vía pubspec).
2. Copiar todo el contenido de `<pack>/android/res/` dentro de
   `android/app/src/main/res/` (merge + sobrescribir).
3. En cada `android/app/src/main/res/mipmap-{d}/`, duplicar
   `ic_launcher.png` → `ic_launcher_round.png`.
4. Copiar `<pack>/android/res/playstore-icon.png` →
   `store_assets/ic_launcher-playstore.png`.
5. Verificar `AndroidManifest.xml`: `android:label`, `android:icon`,
   `android:roundIcon` apuntando a los recursos correctos.
6. Desinstalar la app del dispositivo y `flutter run` — el launcher cachea el
   ícono y una reinstalación encima puede no refrescarlo.

## Pendiente — iOS

`ios/Runner/Assets.xcassets/AppIcon.appiconset/` sigue con el ícono de la
plantilla. El sistema iOS no usa capas adaptativas: necesita un set de PNGs
cuadrados sin transparencia en tamaños fijos (16×16 a 1024×1024). Se genera con
el mismo isotipo en el generador (exportar bundle iOS) o con
`flutter_launcher_icons`. Cuando exista el pack iOS: reemplazar los PNGs del
`AppIcon.appiconset` conservando el `Contents.json`.

## Splash nativo por modo (claro/oscuro)

La pantalla de arranque (lo que se ve antes del primer frame de Flutter) cambia
de color según el modo del sistema usando **calificadores de recursos**:

| Archivo | Rol |
|---------|-----|
| `res/values/colors.xml` | `launch_background` = `#FFFFFF` (modo claro) |
| `res/values-night/colors.xml` | `launch_background` = `#07275C` (modo oscuro — navy) |
| `res/drawable{,-v21}/launch_background.xml` | `@color/launch_background` — Android resuelve el valor según el modo automáticamente |
| `res/values{,-night}/styles.xml` | `LaunchTheme`: `windowSplashScreenBackground` apunta al mismo color (API 31+) |

Para cambiar los colores solo se edita `colors.xml` / `values-night/colors.xml`
— los drawables y estilos no se tocan. El mismo mecanismo (`-night`) sirve para
cualquier otro recurso que deba variar por modo (imágenes, drawables…).

## Assets relacionados

| Archivo | Rol |
|---------|-----|
| `assets/images/imagotipo_quesivo.png` | Imagotipo completo (símbolo + palabra) — splash y headers |
| `assets/images/quesivo_isotipo.png` | Solo el isotipo — fuente para generar íconos |
| `isotipo_quesivo/` | Pack de íconos generado (fuente de verdad de esta config) |
