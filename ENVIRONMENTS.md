# Guía de Entornos y Configuración Dinámica (Flavors)

¡Bienvenido al proyecto! Este aplicativo ha sido orquestado bajo los rigurosos estándares de **Clean Architecture y los Principios S.O.L.I.D.** 

Por razones de seguridad y abstracción, **NUNCA guardamos URLs de APIs, contraseñas, o Tokens quemados (hardcoded) explícitamente en el código de nuestros Repositorios.** Todo se inyecta dinámicamente en tiempo de compilación.

---

## 1. El Emisor: `environment.dart`
Toda la recepción de variables se centraliza en un único archivo:
`lib/core/constants/environment/environment.dart`

Si necesitas que la app aprenda una nueva variable secreta (Ej: Llave de Google Maps), debes abrir ese archivo y agregarla utilizando estrictamente `String.fromEnvironment`. 

El código fuente de toda la aplicación consume las constantes generadas en esa clase. Ningún archivo está autorizado a adivinar manualmente la configuración del entorno.

---

## 2. Cómo compilar y ejecutar (Vía Terminal)
Si estás operando o diagnosticando la aplicación desde la terminal, jamás ejecutes un simple `flutter run`. Dependiendo hacia qué base de datos quieras apuntar, debes inyectar el entorno explícitamente:

- **Desarrollo (backend quesivo-api local):**
  `flutter run --dart-define=ENV=dev`
  - Emulador Android: sin más — `API_URL` default `http://10.0.2.2:3000` apunta al localhost del host.
  - Dispositivo físico: `--dart-define=API_URL=http://<ip-lan-del-pc>:3000` (el backend debe escuchar en `0.0.0.0` o la LAN).

- **Pruebas y QA (Staging):**
  `flutter run --dart-define=ENV=stg --dart-define=API_TOKEN=<tu-token-stg>`

- **Generar Instalador Final Absoluto (Producción):**
  `flutter build appbundle --dart-define=ENV=prod --dart-define=API_TOKEN=<tu-token-prod>`

---

## 3. Cómo usar Visual Studio Code (Opción Recomendada)
Para no escribir la inyección completa en consola diariamente, automatizamos el arranque a través del archivo `.vscode/launch.json`.

**Paso a paso para el uso diario:**
1. Ve a la pestaña lateral izquierda de **"Ejecución y Depuración"** (Run and Debug).
2. En la parte superior, verás un menú desplegable.
3. Elige el perfil donde deseas ejecutar la aplicación:
   - 🚀 `Solid DEV (Entorno Local)`
   - 🛠️ `Solid STG (Servidor Pruebas)`
   - 🔥 `Solid PROD (Modo Release)`
4. Presiona el botón verde de Play o "F5". El IDE se encargará tras bambalinas de llamar al compilador e insertarle exactamente las variables correspondientes contenidas en el JSON.

### 3.1 Las variables de entorno del SO (configuración única por máquina)

`launch.json` **está versionado en git — nunca escribas un token real ahí.** Por eso los perfiles no contienen valores: usan la sintaxis `${env:...}` de VS Code, que se resuelve contra las variables de entorno del sistema operativo en el momento de ejecutar.

| Variable de entorno | Perfil que la consume |
|---|---|
| `API_TOKEN_DEV` | 🚀 Solid DEV (Entorno Local) |
| `API_TOKEN_STG` | 🛠️ Solid STG (Servidor Pruebas) |
| `API_TOKEN_PROD` | 🔥 Solid PROD (Modo Release) |

**Cómo crearlas en Windows (PowerShell, una sola vez por máquina):**

```powershell
[Environment]::SetEnvironmentVariable('API_TOKEN_DEV', 'tu-token-real', 'User')
[Environment]::SetEnvironmentVariable('API_TOKEN_STG', 'tu-token-stg', 'User')
[Environment]::SetEnvironmentVariable('API_TOKEN_PROD', 'tu-token-prod', 'User')
```

- `'User'` guarda la variable solo para tu usuario de Windows; no requiere admin ni afecta otras cuentas.
- **Cierra y reabre VS Code después de crearlas**: el IDE hereda las variables del entorno en el momento en que arrancó, no las relee en caliente.
- Verificación rápida: `[Environment]::GetEnvironmentVariable('API_TOKEN_DEV', 'User')` debe devolver tu token.
- Alternativa gráfica: `Win + R` → `sysdm.cpl` → *Opciones avanzadas* → *Variables de entorno* → *Variables de usuario* → *Nueva*.
- Si una variable no existe, `${env:...}` se resuelve vacío → el bootstrap reporta `API Token Inyectado: (vacío)`. Falla visible, no silenciosa.

**Por qué se hace así (y no con `.env` ni valores en el JSON):**

1. El token real **nunca toca un archivo del repo** → es imposible commitearlo por accidente desde `launch.json`.
2. No se usa `.env` porque viaja como texto plano dentro del APK/IPA y además es el archivo que más se filtra a git por descuido (este repo lo ignora preventivamente en `.gitignore`).
3. Renovar un token = actualizar la variable del SO; el archivo versionado no cambia, así que `git status` jamás muestra un secreto en diff.
4. El mismo patrón escala a CI/CD sin cambios: el pipeline inyecta los valores desde su vault de secretos directo en el comando `flutter build` — ningún archivo intermedio.

---

## 4. Beneficios Arquitectónicos de esta decisión
1. **Open/Closed Principle (OCP):** Puedes crear 20 entornos nuevos u 80 variables secretas extra en tu máquina, y la lógica de enrutamiento o repositorios jamás sufrirá alteraciones. La inyección es agnóstica a la arquitectura.
2. **Seguridad mejorada (con límites conocidos):** a diferencia de archivos texto planos `.env`, los valores `--dart-define` viajan compilados dentro del binario. ⚠️ Ojo: igualmente son **extraíbles del APK/IPA** con herramientas de ingeniería inversa — son más difíciles de leer que un `.env`, no imposibles. Por eso `API_TOKEN` solo debe usarse para keys **no sensibles** (IDs de cliente, keys públicas acotadas); ningún secreto real puede vivir en el cliente, y la autorización fuerte siempre la da el JWT por usuario desde el secure storage.
