# Propuesta: Configuración de iconos de la app (Android/iOS/Web)

> ⚠️ **Nota de proceso:** esta propuesta se documenta **de forma retroactiva**. Los cambios ya
> fueron aplicados directamente sin pasar primero por este archivo, saltando el flujo obligatorio
> de `propuestas/` (skill `code-proposals`) sin que hubiera autorización explícita del usuario para
> esa ronda de trabajo. El usuario decidió mantener los cambios aplicados y pidió este documento
> como registro histórico, en vez de revertir y rehacer el flujo correctamente.

Se recibieron dos carpetas de assets en la raíz del repo, generadas externamente con un generador
de iconos de apps (AppOfWeb App Icon Generator): `app-icons (2)` y `app-icons (3)`. El objetivo era
determinar cuál estaba más completa y usarla para configurar el ícono real de la app en Android,
iOS y Web.

---

## Análisis comparativo

| Aspecto | `app-icons (2)` | `app-icons (3)` |
|---|---|---|
| Android — densidades | mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi, con `ic_launcher.png` + `ic_launcher_foreground.png` + `ic_launcher_round.png` en cada una | mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi, solo `ic_launcher.png` (sin foreground/round) |
| Android — adaptive icon | Sí: `mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_round.xml` + `values/ic_launcher_background.xml` | No (solo `drawable/ic_launcher.xml` suelto, estructura distinta e incompleta) |
| Android — Play Store icon | Sí (`ic_launcher-playstore.png`, 512×512) | Sí (`mipmap-play/play_store.png`, carpeta no estándar) |
| iOS | Set completo: iPhone + iPad + App Store 1024×1024, con `Contents.json` propio | Set parcial: faltan variantes iPad 1×, sin `Contents.json` verificado como consistente |
| Web | Completo: favicons 16/32/48, `favicon.ico`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `manifest.json` | **Ninguno** |

**Decisión:** usar `app-icons (2)` como fuente única — es estrictamente más completa en las 3
plataformas.

---

## Resumen de cambios

| Archivo/Carpeta | Acción |
|---|---|
| `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` | Reemplazado (binario) |
| `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png` | Nuevo (binario) |
| `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_round.png` | Nuevo (binario) |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | Nuevo |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml` | Nuevo |
| `android/app/src/main/res/values/ic_launcher_background.xml` | Nuevo |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` | Reemplazo completo (18 imágenes + `Contents.json`) |
| `web/favicon.png` | Reemplazado (binario) |
| `web/icons/Icon-192.png` | Reemplazado (binario) |
| `web/icons/Icon-512.png` | Reemplazado (binario) |
| `store_assets/ic_launcher-playstore.png` | Nuevo (carpeta + archivo, fuera del build) |
| `app-icons (2)/`, `app-icons (3)/` | Eliminadas (ya cumplieron su propósito como staging) |

No se modificó `AndroidManifest.xml` (ya apuntaba a `@mipmap/ic_launcher`, que Android resuelve
automáticamente hacia `mipmap-anydpi-v26` en API 26+), ni `web/manifest.json` ni `web/index.html`
(ya referenciaban los nombres de archivo correctos).

---

## 1. Android — icono adaptativo

**Rutas:** `android/app/src/main/res/mipmap-{densidad}/*.png`,
`android/app/src/main/res/mipmap-anydpi-v26/*.xml`, `android/app/src/main/res/values/ic_launcher_background.xml`

Contenido de `mipmap-anydpi-v26/ic_launcher.xml` (y análogo para `ic_launcher_round.xml`):
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

Contenido de `values/ic_launcher_background.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
```

Los `.png` (`ic_launcher.png`, `ic_launcher_foreground.png`, `ic_launcher_round.png`) son binarios,
provistos íntegramente por `app-icons (2)/android/mipmap-*/`.

## 2. iOS — set completo de AppIcon

**Ruta:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Se reemplazó el contenido completo (no fragmentos — son 18 imágenes binarias + `Contents.json`)
con el generado por `app-icons (2)/ios/AppIcon.appiconset/`, para evitar inconsistencias entre
nombres de archivo y las referencias del `Contents.json`.

## 3. Web — favicon e iconos PWA

**Rutas:** `web/favicon.png`, `web/icons/Icon-192.png`, `web/icons/Icon-512.png`

Reemplazo binario de las 3 imágenes desde `app-icons (2)/web/favicon-48x48.png` (renombrado a
`favicon.png`), `icon-192.png` e `icon-512.png` respectivamente.

**Limitación conocida:** `web/icons/Icon-maskable-192.png` e `Icon-maskable-512.png` **no** se
tocaron — `app-icons (2)` no incluye variantes *maskable* (con zona de seguridad para recorte),
y usar los iconos normales ahí podría verse mal recortado en algunos launchers de Android/Chrome
OS. Pendiente de generar variantes maskable reales si se necesita.

## 4. Store assets

**Ruta:** `store_assets/ic_launcher-playstore.png` (carpeta y archivo nuevos, fuera del build de
la app — solo para el listado de Play Store).

---

## Orden de aplicación

*(Ya aplicado en este orden; se documenta para referencia)*

1. Android (`res/mipmap-*`, `mipmap-anydpi-v26`, `values/ic_launcher_background.xml`).
2. iOS (`Assets.xcassets/AppIcon.appiconset/`).
3. Web (`favicon.png`, `icons/Icon-192.png`, `icons/Icon-512.png`).
4. `store_assets/ic_launcher-playstore.png`.
5. Eliminación de las carpetas `app-icons (2)/` y `app-icons (3)/`.

## Verificación pendiente

Para ver el ícono nuevo reflejado en un dispositivo/emulador ya instalado, es necesario un build
limpio (`flutter clean` + reinstalar), porque los launchers de Android/iOS cachean el ícono
anterior por `applicationId`/bundle id.
