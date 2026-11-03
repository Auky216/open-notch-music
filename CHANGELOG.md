# Historial de cambios

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
