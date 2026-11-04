<p align="center"><img src="Resources/Icon/AppIcon-preview.png" width="128" height="128" alt="OpenNotch Music"></p>

# OpenNotch Music

**Un reproductor open source para el notch de tu Mac.**

Controla Spotify desde una interfaz nativa, compacta y animada. Desarrollado con SwiftUI y AppKit, sin dependencias externas. La aplicación aparece como **Notch Music** en macOS.

**Código abierto · Licencia MIT · macOS 14+ · Apple Silicon**

[Descargar v0.5.0](https://github.com/Auky216/open-notch-music/releases/download/v0.5.0/OpenNotch-Music-0.5.0-macOS-arm64.zip) · [Versiones](https://github.com/Auky216/open-notch-music/releases) · [Reportar un problema](https://github.com/Auky216/open-notch-music/issues)

## Qué incluye

- Carátula e indicador de audio en la vista compacta.
- Título, artista, álbum, progreso y controles en la vista expandida.
- Reproducción, pausa, anterior, siguiente, volumen, aleatorio y repetición.
- Vista expandida de 480 puntos de ancho, sin fila de estado de audio.
- Tres estilos de isla: negro uniforme, degradado intenso según la carátula y Liquid Glass.
- Barras de audio blancas o adaptadas al color de la canción, independientes del estilo del fondo.
- Volumen con porcentaje temporal, respuesta visual y un tick háptico distinto al de apertura, cada diez puntos y en los extremos.
- Transición continua con resorte y apertura al acercar el cursor, incluida la zona de la cámara.
- Respuesta háptica opcional en trackpads compatibles.
- Panel configurado para acompañar a otras apps en pantalla completa, con recuperación al cambiar de espacio.
- Una sola isla integrada con el notch. Al abrirse, cubre temporalmente los iconos que queden detrás; al cerrarse, vuelve a dejar esa zona libre.
- Visualizador opcional que responde al audio real de Spotify.
- Selección de pantalla, visibilidad, apertura con cursor e inicio con la sesión.
- Compatibilidad con Reducir movimiento y controles con etiquetas de accesibilidad.
- Icono propio minimalista; [fuente vectorial y notas de diseño](Resources/Icon/DESIGN.md).

Spotify sigue reproduciendo el audio. OpenNotch Music muestra su estado y envía los controles a la app de escritorio. No necesitas una cuenta de desarrollador de Spotify ni configurar claves de su API web.

## Elegir la apariencia

En **Ajustes → Apariencia** puedes cambiar el estilo y el color de las barras. Se aplican al instante en la vista compacta y expandida y se guardan entre sesiones.

- **Normal · negro:** fondo negro uniforme. Es el modo predeterminado.
- **Degradado de la canción:** color dominante de la carátula con un degradado intenso; las carátulas monocromáticas usan tonos grises. El color se calcula una vez al cambiar la imagen, sobre una muestra de 32 × 32 píxeles.
- **Liquid Glass:** material nativo de Apple en macOS 26 o posterior, aplicado a toda la isla. En macOS 14 y 15 utiliza un material translúcido compatible. Con Reducir transparencia, utiliza un fondo opaco. La cámara física del Mac permanece negra.

Las barras pueden permanecer **blancas** o usar un color **adaptado a la canción** en cualquiera de los tres modos. Su movimiento sigue respondiendo al audio real de Spotify cuando el visualizador está habilitado.

## Descargar e instalar

1. Descarga el ZIP desde [Releases](https://github.com/Auky216/open-notch-music/releases).
2. Descomprímelo y mueve **Notch Music.app** a Aplicaciones.
3. Abre Spotify y reproduce una canción.
4. Abre Notch Music, acerca el cursor al notch y pulsa **Conectar**. macOS puede solicitar permiso de Automatización para controlar Spotify.
5. Opcionalmente, activa **Visualizador con audio real** en Ajustes para usar las barras de audio de la vista compacta.

La versión descargable es una **compilación preliminar para Apple Silicon**, con firma local ad hoc. Todavía no cuenta con firma Developer ID ni notarización de Apple; macOS puede bloquear su apertura. También puedes compilarla desde el código fuente. La versión no se ha validado en Intel.

El icono de la barra de menús permite abrir el reproductor, conectar Spotify, mostrar u ocultar el panel, abrir ajustes y salir. El atajo propuesto es **Control + Opción + Espacio**, sujeto a que otra app o el sistema no lo tenga registrado.

Si tienes otra app que usa el notch, ciérrala durante el uso para evitar paneles superpuestos.

## Audio y privacidad

El visualizador requiere **macOS 14.2 o posterior** y permiso de audio del sistema. Analiza cuatro bandas de frecuencia mediante un tap limitado a los procesos de Spotify.

- El análisis se realiza localmente.
- No usa el micrófono ni captura la pantalla.
- No guarda ni envía el audio.
- Sin señal o sin permiso las barras permanecen quietas.
- Responde a la energía del audio; no calcula BPM.

El audio se toma de Spotify de escritorio en este Mac. Spotify web y la reproducción remota mediante Spotify Connect no están validados. Las carátulas se descargan de la URL proporcionada por Spotify. No hay servidor propio ni analíticas.

## Letras y karaoke

El karaoke oficial de Spotify no está integrado. La [referencia pública de Spotify](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track) no ofrece un endpoint de letras o karaoke, y el diccionario de automatización de la app de macOS tampoco los expone. Spotify confirmó la [ausencia de una API pública de letras](https://community.spotify.com/t5/Spotify-for-Developers/Update-endpoint-for-lyrics/td-p/5355493).

Para cantar con las letras disponibles en Spotify, abre su app y pulsa el icono de letras de la parte inferior, como indica su [ayuda oficial](https://support.spotify.com/us/article/lyrics/). Su disponibilidad depende de la canción y el dispositivo.

## Compilar

Requisitos: macOS 14 o posterior y Xcode con las herramientas de Swift y el SDK de macOS.

```sh
git clone https://github.com/Auky216/open-notch-music.git
cd open-notch-music
./scripts/build.sh
```

La app se genera en `dist/Notch Music.app`. El script compila en modo release, copia los recursos y firma localmente el paquete con el permiso de Apple Events. El icono ya está incluido; no se generan imágenes durante la ejecución de la app.

## Pruebas

```sh
swift test --disable-sandbox --build-system native
```

La suite comprueba progreso, valores inválidos y redondeo de volumen, tiempos, continuidad del resorte, respuesta del analizador a frecuencias y silencio, nivel nativo de la ventana, continuidad de la silueta, límites de la respuesta háptica de volumen, persistencia de apariencia y extracción del color dominante. El nivel de superposición se asigna después de configurar el panel flotante para evitar que AppKit lo reduzca de nuevo.

Para probar el panel real con datos de demostración, cierra primero la instancia normal:

```sh
"dist/Notch Music.app/Contents/MacOS/NotchMusic" --verify-animations "$PWD/dist/qa"
for estilo in normal albumGradient liquidGlass; do
  swift scripts/check-frames.swift "$PWD/dist/qa/$estilo"
done
```

La prueba exporta fotogramas e informes de apertura, cierre, inversión, movimiento reducido y comportamiento del cursor para cada estilo. Comprueba además la transparencia fuera de la silueta; la opacidad interior se exige solo para los dos modos opacos. El material nativo de cristal también se revisa en la app real, porque una captura fuera de pantalla no reproduce por completo el compositor de macOS. La sensación háptica requiere una prueba humana con un trackpad compatible.

Vista previa con datos ficticios:

```sh
"dist/Notch Music.app/Contents/MacOS/NotchMusic" --render-preview "$PWD/dist/preview.png"
```

## Rendimiento

- El análisis de audio se detiene en pausa, al ocultar el panel y al apagar la pantalla.
- La vista expandida se desmonta al cerrar.
- Los eventos de Spotify disparan actualizaciones; las consultas de respaldo se espacian según el estado: 2 segundos abierto/reproduciendo, 4 compacto/reproduciendo, 8 en pausa y 12 sin pista.
- Las carátulas se reducen a 320 píxeles y su caché admite 12 imágenes, con un límite de coste de 8 MiB.
- La animación ejecuta su temporizador solo durante las transiciones y se adapta a la frecuencia de la pantalla.
- El respaldo de detección del cursor trabaja con menor frecuencia lejos del notch.

Las mediciones puntuales no garantizan el mismo consumo en todos los equipos. El consumo aumenta al animar y analizar audio. Los diagnósticos opcionales se escriben únicamente si se inicia la app con sus argumentos de prueba.

## Estado del proyecto

Versión actual: **0.5.0**, en desarrollo. Ver [CHANGELOG.md](CHANGELOG.md).

Probada localmente en Apple Silicon con macOS 26.6.2 y Spotify 1.3.6.1921. Quedan por validar Intel, otros equipos y versiones, monitores externos, reposo prolongado, otros escenarios de Spaces y cuentas de Spotify diferentes. Apple Music, archivos, AirDrop, Pomodoro, portapapeles, calendario, búsqueda y letras son posibles mejoras futuras.

Se aceptan issues y pull requests. Consulta [CONTRIBUTING.md](CONTRIBUTING.md).

## Licencia

Código y diseño propio disponibles bajo la [licencia MIT](LICENSE). Proyecto independiente, sin afiliación con Apple ni Spotify; sus marcas pertenecen a sus respectivos propietarios.
