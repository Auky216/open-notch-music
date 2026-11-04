# Historial de cambios

## 0.4.3 — 2026-11-04

- Elimina la fila «Ritmo en vivo» y sus otros estados de la vista expandida. El visualizador compacto y su ajuste siguen disponibles.
- Reduce el reproductor abierto de 548 × 298 a 480 × 252 puntos en una pantalla con zona superior de 38 puntos, manteniendo una sola isla y todos sus controles.
- Añade porcentaje temporal, respuesta del icono de altavoz y énfasis del deslizador al ajustar el volumen. Respeta Reducir movimiento.
- Usa el patrón háptico de cambio de nivel para volumen, distinto al de apertura, con pasos de diez puntos, extremos, histéresis y límite de frecuencia.
- Redondea el volumen a puntos enteros y mantiene el valor local mientras Spotify confirma el ajuste para evitar saltos visuales. Compensa una sola vez el desfase de un punto de su automatización, con espera limitada en segundo plano.
- Documenta la limitación del karaoke oficial: no está disponible mediante la API pública ni la automatización de Spotify para macOS.
- Verificación local: diez pruebas, diez escenarios de interacción de la isla y treinta fotogramas de apertura y cierre. Comprobación del ajuste de volumen con Spotify; la sensación física háptica requiere un trackpad compatible.

## 0.4.2 — 2026-11-03

- Corrige el orden de configuración del panel: `isFloatingPanel` restablecía el nivel a 3 después de asignar el nivel de superposición 26. Ahora el nivel se establece al final y se comprueba al restaurar el panel.
- Conserva una única silueta de isla dinámica que se ensancha desde el borde superior y cubre temporalmente los iconos situados detrás.
- Recuperación de visibilidad después de las transiciones de espacios con verificaciones durante 1,5 segundos.
- Añade pruebas del nivel real de AppKit y de una sola silueta continua durante la expansión.
- Diagnósticos opcionales con versión, proceso y nivel de ventana para distinguir una ventana ordenada sobre el escritorio de una superposición efectiva.

## 0.4.1 — 2026-11-03

Primera publicación open source de OpenNotch Music.

- Reproductor nativo de Spotify con estados compacto y expandido.
- Metadatos, carátula, progreso y controles de reproducción.
- Visualizador opcional basado en el audio real de Spotify.
- Transiciones continuas, apertura mediante cursor y respuesta háptica opcional.
- Controles bajo la barra de menús y compatibilidad comprobada con Brave en pantalla completa.
- Ajustes de pantalla, visibilidad e inicio con la sesión.
- Reducción del trabajo en pausa, caché de carátulas limitada y consultas adaptativas.
- Icono minimalista propio con fuente vectorial incluida.
- Código y recursos propios publicados con licencia MIT.

La app descargable es preliminar, para Apple Silicon y con firma local ad hoc; todavía no está notarizada para distribución pública.
