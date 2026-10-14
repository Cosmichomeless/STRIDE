# Guía de publicación en la App Store

Lo que se hizo para publicar STRIDE 1.0, en orden, con lo que falló y cómo se resolvió. Sirve de lista de comprobación para la próxima app o la próxima versión. Los textos de la ficha están en [STORE_LISTING.md](STORE_LISTING.md), las notas para el revisor en [APP_REVIEW.md](APP_REVIEW.md) y las imágenes y sus scripts en [app-store/](app-store/README.md).

Nada de esto lleva claves en el repositorio. La clave de la API de App Store Connect (`.p8`) vive en `~/.appstoreconnect/private_keys/` y no se commitea nunca.

## Qué se hace en la web y qué por API

| Paso | Web de App Store Connect | API / herramientas |
| --- | --- | --- |
| Crear la app (nombre, SKU, idioma principal, bundle ID) | Sí | No |
| Declaración de privacidad ("Datos no recopilados") | **Solo web** | No |
| Declaración de comerciante (DSA, UE) | **Solo web** | No |
| Declaración de dispositivo médico regulado | **Solo web** (la API no la expone) | No |
| Encabezado de la ficha y resultados de búsqueda (imágenes) | **Solo web**, una por idioma | No |
| Textos por idioma, subtítulos, palabras clave, URLs | Sí | Sí |
| Capturas de pantalla | Sí | Sí |
| Precio, disponibilidad, categorías, clasificación por edad | Sí | Sí |
| Asociar el build, derechos de contenido, contacto y notas de revisión | Sí | Sí |
| Enviar a revisión | Sí | Sí (`tools/submit_review.py`) |

## 1. Requisitos previos (una sola vez)

1. Cuenta de Apple Developer de pago y su **Team ID** (en `project.yml` como `DEVELOPMENT_TEAM`).
2. **Bundle ID** registrado con las capacidades que usa la app (aquí HealthKit). Sin la capacidad en el App ID, la firma automática falla.
3. La app creada en App Store Connect: nombre, **SKU**, idioma principal (aquí español de España) y bundle ID.
4. **Clave de la API** en *Usuarios y acceso › Integraciones*. Se necesita el rol Admin para publicar todo; anota el Key ID y el Issuer ID y descarga el `.p8` (solo se puede descargar una vez).
5. Un **icono de 1024 px sin transparencia** en `Assets.xcassets`.
6. Páginas públicas de **política de privacidad** y **soporte** (aquí GitHub Pages desde `docs/`). Comprueba que devuelven 200.

## 2. Preparar el proyecto

- `MARKETING_VERSION` (la versión visible, `1.0`) y `CURRENT_PROJECT_VERSION` (el número de build, que debe subir en cada subida).
- `DEVELOPMENT_TEAM` en `project.yml`; después `xcodegen generate`.
- Claves de permisos en el Info.plist con su texto traducido (`InfoPlist.xcstrings`).
- **Trampa de HealthKit:** con el entitlement `com.apple.developer.healthkit`, App Store Connect rechaza la subida si falta `NSHealthShareUsageDescription`, aunque la app no lea nada. Se añadió con un texto que lo dice claramente.
- Cifrado: la app no usa cifrado fuera de lo exento; el build quedó sin cifrado no exento y no hubo que responder a la pregunta.
- Pasa los tests antes de archivar.

## 3. Archivar y subir el build

Todo desde la terminal, con firma automática (las credenciales de la cuenta están en Xcode):

```bash
xcodegen generate

xcodebuild archive -project STRIDE.xcodeproj -scheme STRIDE -configuration Release \
  -destination generic/platform=iOS -archivePath build/STRIDE.xcarchive \
  -allowProvisioningUpdates

xcodebuild -exportArchive -archivePath build/STRIDE.xcarchive \
  -exportOptionsPlist ExportOptionsUpload.plist -exportPath build/export \
  -allowProvisioningUpdates
```

`ExportOptionsUpload.plist` (con `destination = upload` el export sube el build directamente; con `export` solo genera el `.ipa`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>teamID</key><string>TU_TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
<key>destination</key><string>upload</string>
<key>uploadSymbols</key><true/>
</dict></plist>
```

Cuidado: puede haber certificados de otras personas en el llavero; usa solo los de tu equipo.

Después, App Store Connect procesa el build unos minutos. Espera a que esté en `VALID` y se vea en TestFlight antes de asociarlo. El icono tarda un poco más en aparecer.

## 4. Textos por idioma

Para cada idioma: nombre, subtítulo, descripción, palabras clave y URL de soporte; y la URL de la política de privacidad en la información de la app. Límites: nombre 30, subtítulo 30, palabras clave 100 caracteres. Todo el texto está en [STORE_LISTING.md](STORE_LISTING.md).

- El nombre debe ser único en la tienda de cada país. Si "STRIDE" está cogido, ASC lo rechaza o pide cambiarlo; por eso hay variantes (en-US "STRIDE Run GPS", fr y de "STRIDE: Run Tracker"). Comprueba el nombre final de cada idioma tras el envío.
- La versión 1.0 no lleva "Novedades" (`whatsNew`); a partir de la 1.1 sí.

## 5. Capturas

- Tamaño: 1320x2868 (iPhone 6.9"). La API las clasifica como `APP_IPHONE_67`. Se suben 4 por idioma, sin transparencia.
- Se generan con `ScreenshotWalkthroughTests` en un simulador de 6.9" con la barra de estado fija a las 9:41 (`simctl status_bar override`) y un idioma por pasada (`TEST_RUNNER_SHOTS_LANG`). Procedimiento exacto en [app-store/README.md](app-store/README.md).
- Revisa cada PNG antes de subirlo: sin diálogos de permiso, sin estados de carga, sin datos personales.
- Se subieron con el MCP `asc` (`upload_screenshot`). Comprueba que todas quedan en `COMPLETE`.

## 6. Encabezado y resultados de búsqueda

Son imágenes opcionales de la ficha y **solo se suben en la web**, por idioma. Ruta en App Store Connect: la app y su versión › **Product Page Information** › **Header and Search Results**; allí se elige el elemento y se sube el archivo (o se escoge uno ya subido en **Asset Library**). Si la imagen sirve para los dos usos (la de 5244x2950), se marca **Use header asset in search results**. **Preview** muestra el resultado por dispositivo, orientación e idioma. En la página de la versión, elige el idioma en el desplegable y arrastra la imagen. Si solo arrastras una vez, queda en el idioma que tuvieras seleccionado; cambia de idioma y repite.

Los scripts `make_header.py` y `make_search.py` las generan en los seis idiomas (tamaños en [app-store/README.md](app-store/README.md)). Para otro idioma, añade su texto en la tabla `TEXT` de ambos.

## 7. Datos de la app (por API o web)

| Campo | Valor en STRIDE |
| --- | --- |
| Precio | Gratis (punto de precio base `10000`, territorio base EE. UU.) |
| Disponibilidad | Todos los países y regiones (175) |
| Categorías | Salud y forma física; secundaria Deportes |
| Clasificación por edad | 4+ (todas las respuestas en "ninguno") |
| Derechos de contenido | No usa contenido de terceros (`DOES_NOT_USE_THIRD_PARTY_CONTENT`) |
| Copyright | 2026 David Rodríguez |
| Publicación | Automática tras la aprobación (`AFTER_APPROVAL`) |

## 8. Declaraciones que solo se hacen en la web

1. **Privacidad de la app** (*Privacidad de la app*): "Datos no recopilados" y **publicar**.
2. **Comerciante (DSA)**: *Permisos y reglamentos de App Store › Reglamento de Servicios Digitales*. Para un proyecto personal sin ánimo de lucro, se indica que no se es comerciante (botón **Editar** si ya salía como comerciante).
3. **Dispositivo médico regulado**: en la barra lateral, **General › App Information**, y en **App Store Regulations & Permits** pulsa **Declare Regulated Medical Device**. Para una app de running, **No** y **Save**. Es obligatoria si la app se vende en la UE/EEE, Reino Unido o EE. UU. y su categoría principal o secundaria es Salud y forma física o Médica. Requiere rol de titular de la cuenta o Admin. Si falta, el envío falla (ver errores). Fuente: [Declare regulated medical device status](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status/).

## 9. Información para el revisor

- Contacto: nombre, email y teléfono (el teléfono solo en App Store Connect, no en el repositorio).
- Sin cuenta de demostración si la app no tiene inicio de sesión.
- Notas: explican por qué se usa `UIBackgroundModes: location`, cuándo se pide cada permiso y cómo probarlo (pasos para el simulador). Base en [APP_REVIEW.md](APP_REVIEW.md). Si no se adjunta vídeo, dilo y explica cómo reproducirlo.

## 10. Revisión final y envío

1. Asocia el build a la versión.
2. Repasa: textos y capturas de todos los idiomas, build `VALID`, URLs, precio, edad, privacidad, DSA, dispositivo médico.
3. Envía. Por API:

```bash
export ASC_KEY_ID=...  ASC_ISSUER=...
python3 docs/app-store/tools/submit_review.py <APP_ID> <VERSION_ID>
```

El script crea (o reutiliza) la *review submission*, añade la versión y la envía. Si falla por una validación, corrige lo que diga el error y vuélvelo a lanzar: reutiliza la submission abierta.

Los identificadores se consultan con `GET /v1/apps/<id>/appStoreVersions`. `tools/asc_api.py` es un cliente mínimo: `python3 asc_api.py GET /v1/apps`.

Estado esperado tras el envío: `WAITING_FOR_REVIEW`.

## 11. Errores que aparecieron

| Error | Causa | Solución |
| --- | --- | --- |
| La subida del build se rechazaba | Faltaba `NSHealthShareUsageDescription` con el entitlement de HealthKit | Añadir la clave con un texto honesto y subir de nuevo (build nuevo) |
| `409 STATE_ERROR.ENTITY_STATE_INVALID` al añadir la versión a la submission, con `CANNOT_SUBMIT_MISSING_REGULATED_MEDICAL_DEVICE_APP_DECLARATION` | Falta declarar si es un dispositivo médico regulado | Declararlo en la web (No) y reintentar |
| Quedó una *review submission* vacía tras el error | El script la crea antes de añadir la versión | `submit_review.py` ya la reutiliza; si no, cancelarla en la web |
| Pantalla de DSA decía "comerciante" | Estado por defecto distinto del real | Editarlo en la web a no comerciante |
| `400` al listar submissions con `fields[reviewSubmissions]=submitted` | Ese campo no es válido ahí | Listar sin `fields` |

## 12. Después del envío

- La revisión suele tardar 1–2 días. Apple escribe por correo y en *Resolution Center*; se responde allí.
- Al aprobarse, se publica sola (`AFTER_APPROVAL`).
- **Baja de permisos la clave de la API** (o revócala) cuando no la necesites: una clave Admin puede cambiar precios o borrar la app. Crea otra con rol *App Manager* para el día a día.

## Para una versión nueva (1.1, 1.2…)

1. Sube `MARKETING_VERSION` y `CURRENT_PROJECT_VERSION`; archiva y sube el build (sección 3).
2. Crea la versión nueva en App Store Connect (o por API) y escribe las "Novedades" en cada idioma.
3. Recaptura solo las capturas que cambien (sección 5) y regenera el encabezado y la búsqueda si hace falta.
4. Revisa si cambió algo que afecte a las declaraciones (permisos nuevos, datos recopilados, notas del revisor).
5. Asocia el build y envía (secciones 10 y 12).
