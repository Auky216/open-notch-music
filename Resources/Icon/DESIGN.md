# Notch Music · icono 0.4.1

Concepto: una silueta de notch con tres bandas de audio, centrada sobre una base blanco perla. Sin letras ni marcas de terceros. El acabado tiene profundidad sutil y contraste alto; la geometría sigue siendo legible en tamaños pequeños.

Se revisaron las pautas oficiales y los iconos instalados de Música y TV como referencias de jerarquía y proporción. El diseño es propio y no reproduce sus símbolos. El formato entregado es un icono estático ICNS, compatible con la app actual; no es un icono dinámico de Icon Composer.

Fuente: [Apple Human Interface Guidelines — App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons/).

- `AppIcon.svg`: geometría editable.
- `AppIcon.png`: exportación de 1024 píxeles con transparencia exterior.
- `AppIcon-preview.png`: vista previa de 256 píxeles.
- `../AppIcon.icns`: recurso empaquetado, con resoluciones de 16 a 1024 píxeles.

Regenerar el recurso desde la raíz del proyecto:

```sh
swift scripts/make-icon.swift .build/MinimalIcon.iconset
iconutil -c icns .build/MinimalIcon.iconset -o Resources/AppIcon.icns
```

El icono se genera durante la preparación; no añade animaciones ni renderizado periódico al ejecutar la app.
