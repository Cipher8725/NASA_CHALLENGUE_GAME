# NaSA-GAME — Sprites de Biblioteca

43 PNG, incluidas las tres maquetas de referencia.

- menu/ — Fondo limpio, panel, botones principales, botones para las opciones de juego e iconos.
- biblioteca/ — Fondo con tres estantes vacíos, seis portadas recortadas de la maqueta, marco de nivel y botón de regreso.
- lector/ — Fondo de la sala, libro abierto con transparencia, páginas izquierda y derecha, textura de papel, dos ilustraciones de referencia, botones e iconos.
- referencia.png en cada carpeta muestra la composición propuesta.

Los fondos de estantería y lector son panorámicos (1672 × 470). Puedes enmarcarlos en una interfaz 1280 × 720 con una zona superior de título y una inferior de navegación, o ajustar el encuadre según la escena. Los fondos y el libro en blanco se recrearon a partir de las maquetas. Los botones e iconos se redibujaron en el mismo estilo.

En Godot usa TextureRect para los fondos y el libro, y TextureButton para los estados normal, hover, pressed y disabled. Superpón los títulos de interfaz con Label y el texto editable de cada página con RichTextLabel. Las seis portadas conservan sus títulos como parte de la imagen.
