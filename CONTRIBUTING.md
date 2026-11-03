# Contribuir a OpenNotch Music

Gracias por ayudar a mejorar la app. Puedes abrir un issue o enviar un pull request.

## Preparar el entorno

Necesitas macOS 14+ y Xcode con las herramientas de Swift. El visualizador real requiere macOS 14.2+. El proyecto usa Swift Package Manager y frameworks del sistema; no tiene dependencias externas.

```sh
./scripts/build.sh
swift test --disable-sandbox --build-system native
```

## Reportar problemas

Incluye la versión de macOS y de Spotify, el modelo o arquitectura del Mac, la versión de la app y los pasos para reproducir el problema. Para problemas de pantalla completa o monitores, describe también la disposición de pantallas.

Revisa las capturas y los informes antes de adjuntarlos: pueden incluir nombres de canciones o información sobre otras apps. No publiques credenciales ni datos personales.

## Enviar cambios

- Abre una rama para el cambio y explica el comportamiento esperado en el pull request.
- Mantén el foco en una mejora o corrección concreta.
- Respeta Reducir movimiento, las etiquetas de accesibilidad y los permisos opcionales.
- Para cambios de animación o geometría, revisa también los fotogramas intermedios y el contorno.
- Evita nuevas dependencias si los frameworks del sistema cubren la necesidad.
- Añade pruebas cuando comprueben un comportamiento relevante y corre las verificaciones relacionadas con tu cambio.

Al enviar una contribución aceptas que se distribuya con la licencia MIT del proyecto.
