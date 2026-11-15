# Guía del paquete "Nasa Space 2" en NaSA-GAME

Todo el contenido del zip **Nasa Space 2** está dentro del proyecto, en `res://ai_assets/nasa_space_2/` (los originales, con su misma estructura), y lo que se usa en el juego está copiado o adaptado en las rutas de abajo. Los 3 zips internos (`biblioteca_estudio.zip`, `menu_botones_con_texto.zip`, `sprites_nasa_game.zip`) no se copiaron porque repiten las mismas carpetas.

## Qué hace cada parte en el juego

| Parte del zip | En el juego | Escena y script |
|---|---|---|
| `menu_botones_con_texto/` + `sprites_nasa_game/menu/fondo.png` | Menú principal: Jugar (abre "Menú de juego"), Biblioteca, Salir, Mi carnet | `scenes/main_menu.tscn`, `scripts/main_menu.gd` |
| `biblioteca_estudio/` + `sprites_nasa_game/biblioteca/` | Biblioteca de estudio: 9 libros en 3 niveles | `scenes/biblioteca.tscn`, `scripts/library.gd` |
| `sprites_nasa_game/lector/` | Lector de libro abierto (Anterior / Siguiente / Cerrar libro, fuentes, botón Practicar) | dentro de `scenes/biblioteca.tscn` (`%Reader`) |
| `apolo_8_referencias/` | Simulación de despegue del Apolo 8: cabina 3D con los 4 paneles y ventanas al mundo 3D; panel del Saturno V | `scenes/simulacion_despegue_3d.tscn`, `scripts/launch_simulation_3d.gd` (versión 2D: `scenes/simulacion_despegue.tscn`) |

## Archivo por archivo

| Archivo del zip | Estado | Dónde / para qué |
|---|---|---|
| `biblioteca_estudio.zip` | Duplicado | Mismo contenido que su carpeta; no se copió |
| `menu_botones_con_texto.zip` | Duplicado | Mismo contenido que su carpeta; no se copió |
| `sprites_nasa_game.zip` | Duplicado | Mismo contenido que su carpeta; no se copió |
| `apolo_8_referencias/cabina_apolo_8.png` | Kit / referencia | Cabina frontal en alta resolución (sin recorte) — `ai_assets/nasa_space_2/apolo_8_referencias/cabina_apolo_8.png` |
| `apolo_8_referencias/cabina_apolo_8_000_frente.png` | En el juego | ai_assets/apolo8/cabina_000_frente.png (ventanas transparentes) → panel frontal de la cabina 3D y de la versión 2D |
| `apolo_8_referencias/cabina_apolo_8_090_derecha.png` | En el juego | ai_assets/apolo8/cabina_090_derecha.png → pared derecha de la cabina |
| `apolo_8_referencias/cabina_apolo_8_180_atras.png` | En el juego | ai_assets/apolo8/cabina_180_atras.png → escotilla (atrás) |
| `apolo_8_referencias/cabina_apolo_8_270_izquierda.png` | En el juego | ai_assets/apolo8/cabina_270_izquierda.png → pared izquierda |
| `apolo_8_referencias/saturn_v.png` | Kit / referencia | Saturno V entero (icono o pantalla de carga) — `ai_assets/nasa_space_2/apolo_8_referencias/saturn_v.png` |
| `apolo_8_referencias/saturn_v_etapas.png` | En el juego | ai_assets/apolo8/etapas/*.png (recortado en 6 piezas) → panel "Saturno V" que suelta etapas |
| `biblioteca_estudio/LEEME.md` | Kit / referencia | Instrucciones originales del paquete — `ai_assets/nasa_space_2/biblioteca_estudio/LEEME.md` |
| `biblioteca_estudio/catalogo.json` | En el juego | resources/biblioteca/catalogo.json (rutas res:// + diagramas + botón "Practicar") |
| `biblioteca_estudio/fondo_biblioteca_1280x720.png` | En el juego | ai_assets/ui/biblioteca/fondo_biblioteca.png → estantería |
| `biblioteca_estudio/fondo_biblioteca_1920x1080.png` | Kit / referencia | Fondo de la estantería en 1920 × 1080 (para pantallas grandes) — `ai_assets/nasa_space_2/biblioteca_estudio/fondo_biblioteca_1920x1080.png` |
| `biblioteca_estudio/vista_previa.png` | Kit / referencia | Vista previa de la estantería montada — `ai_assets/nasa_space_2/biblioteca_estudio/vista_previa.png` |
| `biblioteca_estudio/avanzado/control_mision/libro.md` | En el juego | resources/biblioteca/libros/control_mision.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/avanzado/control_mision/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/control_mision.png → libro en la estantería |
| `biblioteca_estudio/avanzado/exploracion_lunar/libro.md` | En el juego | resources/biblioteca/libros/exploracion_lunar.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/avanzado/exploracion_lunar/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/exploracion_lunar.png → libro en la estantería |
| `biblioteca_estudio/avanzado/trajes_espaciales/libro.md` | En el juego | resources/biblioteca/libros/trajes_espaciales.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/avanzado/trajes_espaciales/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/trajes_espaciales.png → libro en la estantería |
| `biblioteca_estudio/basico/sistema_solar/libro.md` | En el juego | resources/biblioteca/libros/sistema_solar.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/basico/sistema_solar/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/sistema_solar.png → libro en la estantería |
| `biblioteca_estudio/basico/tierra_luna/libro.md` | En el juego | resources/biblioteca/libros/tierra_luna.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/basico/tierra_luna/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/tierra_luna.png → libro en la estantería |
| `biblioteca_estudio/basico/vida_espacio/libro.md` | En el juego | resources/biblioteca/libros/vida_espacio.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/basico/vida_espacio/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/vida_espacio.png → libro en la estantería |
| `biblioteca_estudio/intermedio/despegue_orbita/libro.md` | En el juego | resources/biblioteca/libros/despegue_orbita.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/intermedio/despegue_orbita/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/despegue_orbita.png → libro en la estantería |
| `biblioteca_estudio/intermedio/rover/libro.md` | En el juego | resources/biblioteca/libros/rover.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/intermedio/rover/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/rover.png → libro en la estantería |
| `biblioteca_estudio/intermedio/soporte_vital/libro.md` | En el juego | resources/biblioteca/libros/soporte_vital.md (texto fuente; el juego lee catalogo.json) |
| `biblioteca_estudio/intermedio/soporte_vital/portada.png` | En el juego | ai_assets/ui/biblioteca/portadas/soporte_vital.png → libro en la estantería |
| `menu_botones_con_texto/LEEME.md` | Kit / referencia | Instrucciones originales del paquete — `ai_assets/nasa_space_2/menu_botones_con_texto/LEEME.md` |
| `menu_botones_con_texto/armado_del_rover.png` | En el juego | ai_assets/ui/menu/armado_del_rover.png → "Armado del rover" (Taller del Rover) |
| `menu_botones_con_texto/base_lunar.png` | En el juego | ai_assets/ui/menu/base_lunar.png → "Base lunar" (abre scenes/main.tscn) |
| `menu_botones_con_texto/biblioteca.png` | En el juego | ai_assets/ui/menu/biblioteca.png → botón BIBLIOTECA |
| `menu_botones_con_texto/encabezado_menu_de_juego.png` | En el juego | ai_assets/ui/menu/encabezado_menu_de_juego.png → título del panel |
| `menu_botones_con_texto/esquema_con_panel_1280x720.png` | Referencia | maqueta del menú montado (para comparar) |
| `menu_botones_con_texto/esquema_transparente_1280x720.png` | Referencia | guía de alineación del menú |
| `menu_botones_con_texto/exploracion_lunar.png` | En el juego | ai_assets/ui/menu/exploracion_lunar.png → "Exploración lunar" (desactivado: falta su escena) |
| `menu_botones_con_texto/jugar.png` | En el juego | ai_assets/ui/menu/jugar.png → botón JUGAR del menú (scenes/main_menu.tscn); se generaron _hover, _pressed y _disabled |
| `menu_botones_con_texto/panel_semifondo.png` | En el juego | ai_assets/ui/menu/panel_semifondo.png → fondo del panel "Menú de juego" |
| `menu_botones_con_texto/posiciones_1280x720.json` | En el juego | resources/menu_posiciones_1280x720.json → posiciones exactas de los botones |
| `menu_botones_con_texto/salir.png` | En el juego | ai_assets/ui/menu/salir.png → botón SALIR |
| `menu_botones_con_texto/simulacion_de_despegue.png` | En el juego | ai_assets/ui/menu/simulacion_de_despegue.png → "Simulación de despegue" (versión 3D) |
| `sprites_nasa_game/LEEME.md` | Kit / referencia | Instrucciones originales del paquete — `ai_assets/nasa_space_2/sprites_nasa_game/LEEME.md` |
| `sprites_nasa_game/biblioteca/boton_volver.png` | En el juego | botón "Volver al menú" de la biblioteca |
| `sprites_nasa_game/biblioteca/etiqueta_nivel.png` | En el juego | etiquetas Básico / Intermedio / Avanzado |
| `sprites_nasa_game/biblioteca/fondo.png` | Kit / referencia | Fondo panorámico alternativo de la estantería (1672 × 470) — `ai_assets/nasa_space_2/sprites_nasa_game/biblioteca/fondo.png` |
| `sprites_nasa_game/biblioteca/portada_control_mision.png` | Kit / referencia | Portadas alternativas de la maqueta (la biblioteca usa las 9 de biblioteca_estudio) — `ai_assets/nasa_space_2/sprites_nasa_game/biblioteca/portada_control_mision.png` |
| `sprites_nasa_game/biblioteca/portada_despegue_orbita.png` | Kit / referencia | Portadas alternativas de la maqueta (la biblioteca usa las 9 de biblioteca_estudio) — `ai_assets/nasa_space_2/sprites_nasa_game/biblioteca/portada_despegue_orbita.png` |
| `sprites_nasa_game/biblioteca/portada_exploracion_lunar.png` | Kit / referencia | Portadas alternativas de la maqueta (la biblioteca usa las 9 de biblioteca_estudio) — `ai_assets/nasa_space_2/sprites_nasa_game/biblioteca/portada_exploracion_lunar.png` |
| `sprites_nasa_game/biblioteca/portada_rover.png` | Kit / referencia | Portadas alternativas de la maqueta (la biblioteca usa las 9 de biblioteca_estudio) — `ai_assets/nasa_space_2/sprites_nasa_game/biblioteca/portada_rover.png` |
| `sprites_nasa_game/biblioteca/portada_tierra_luna.png` | Kit / referencia | Portadas alternativas de la maqueta (la biblioteca usa las 9 de biblioteca_estudio) — `ai_assets/nasa_space_2/sprites_nasa_game/biblioteca/portada_tierra_luna.png` |
| `sprites_nasa_game/biblioteca/portada_universo.png` | Kit / referencia | Portadas alternativas de la maqueta (la biblioteca usa las 9 de biblioteca_estudio) — `ai_assets/nasa_space_2/sprites_nasa_game/biblioteca/portada_universo.png` |
| `sprites_nasa_game/biblioteca/referencia.png` | Kit / referencia | Maqueta de referencia de la pantalla — `ai_assets/nasa_space_2/sprites_nasa_game/biblioteca/referencia.png` |
| `sprites_nasa_game/lector/boton_disabled.png` | En el juego | ai_assets/ui/lector/ → estado disabled (Anterior/Siguiente) |
| `sprites_nasa_game/lector/boton_hover.png` | En el juego | ai_assets/ui/lector/ → estado hover de los botones |
| `sprites_nasa_game/lector/boton_normal.png` | En el juego | ai_assets/ui/lector/ → estilo de los botones con texto (lector, simulación, "Mi carnet") |
| `sprites_nasa_game/lector/boton_pressed.png` | En el juego | ai_assets/ui/lector/ → estado pressed de los botones |
| `sprites_nasa_game/lector/diagrama_cohete.png` | En el juego | página "Las etapas" del libro Del despegue a la órbita |
| `sprites_nasa_game/lector/diagrama_orbita.png` | En el juego | página "Alcanzar una órbita" |
| `sprites_nasa_game/lector/fondo.png` | En el juego | ai_assets/ui/lector/fondo.png → sala del lector de libros |
| `sprites_nasa_game/lector/icono_cerrar.png` | En el juego | botón "Cerrar libro" |
| `sprites_nasa_game/lector/icono_derecha.png` | En el juego | botón Siguiente y flecha de vistas |
| `sprites_nasa_game/lector/icono_izquierda.png` | En el juego | botón Anterior y flecha de vistas |
| `sprites_nasa_game/lector/libro_abierto.png` | En el juego | ai_assets/ui/lector/libro_abierto.png → libro abierto del lector |
| `sprites_nasa_game/lector/pagina_derecha.png` | Kit / referencia | Páginas sueltas del libro (para un lector con animación de pasar página) — `ai_assets/nasa_space_2/sprites_nasa_game/lector/pagina_derecha.png` |
| `sprites_nasa_game/lector/pagina_izquierda.png` | Kit / referencia | Páginas sueltas del libro (para un lector con animación de pasar página) — `ai_assets/nasa_space_2/sprites_nasa_game/lector/pagina_izquierda.png` |
| `sprites_nasa_game/lector/referencia.png` | Kit / referencia | Maqueta de referencia de la pantalla — `ai_assets/nasa_space_2/sprites_nasa_game/lector/referencia.png` |
| `sprites_nasa_game/lector/textura_papel.png` | Kit / referencia | Textura de papel repetible (fondos de notas o tarjetas) — `ai_assets/nasa_space_2/sprites_nasa_game/lector/textura_papel.png` |
| `sprites_nasa_game/menu/boton_disabled.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/boton_disabled.png` |
| `sprites_nasa_game/menu/boton_hover.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/boton_hover.png` |
| `sprites_nasa_game/menu/boton_normal.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/boton_normal.png` |
| `sprites_nasa_game/menu/boton_pressed.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/boton_pressed.png` |
| `sprites_nasa_game/menu/fondo.png` | En el juego | ai_assets/ui/menu/fondo_menu.png → fondo del menú |
| `sprites_nasa_game/menu/icono_base.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/icono_base.png` |
| `sprites_nasa_game/menu/icono_cohete.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/icono_cohete.png` |
| `sprites_nasa_game/menu/icono_exploracion.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/icono_exploracion.png` |
| `sprites_nasa_game/menu/icono_jugar.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/icono_jugar.png` |
| `sprites_nasa_game/menu/icono_libro.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/icono_libro.png` |
| `sprites_nasa_game/menu/icono_rover.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/icono_rover.png` |
| `sprites_nasa_game/menu/icono_salir.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/icono_salir.png` |
| `sprites_nasa_game/menu/opcion_juego_disabled.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/opcion_juego_disabled.png` |
| `sprites_nasa_game/menu/opcion_juego_hover.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/opcion_juego_hover.png` |
| `sprites_nasa_game/menu/opcion_juego_normal.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/opcion_juego_normal.png` |
| `sprites_nasa_game/menu/opcion_juego_pressed.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/opcion_juego_pressed.png` |
| `sprites_nasa_game/menu/panel_juego.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/panel_juego.png` |
| `sprites_nasa_game/menu/referencia.png` | Kit / referencia | Kit para nuevas pantallas: botones e iconos sin texto (usar TextureButton + Label) — `ai_assets/nasa_space_2/sprites_nasa_game/menu/referencia.png` |

## Cómo usar el kit en una pantalla nueva

1. **Botón con texto:** `Button` con `theme_override_styles/normal|hover|pressed|disabled` = `StyleBoxTexture` usando `ai_assets/ui/lector/boton_*.png` (márgenes de textura 24 × 18). Así se hicieron los botones de la biblioteca y de la simulación.
2. **Botón de imagen con texto incluido:** `TextureButton` con `ignore_texture_size = true`, `stretch_mode = 0` y las variantes `_hover/_pressed/_disabled` (ver `ai_assets/ui/menu/`). Para crear variantes nuevas se ajusta el brillo del PNG.
3. **Iconos** (`sprites_nasa_game/menu/icono_*.png`, 64 × 64): como `icon` de un `Button` con `expand_icon = true`.
4. **Libros nuevos:** agregar un objeto a `resources/biblioteca/catalogo.json` (id, nivel, titulo, portada, 3 páginas, fuentes; opcional `imagen` por página y `actividad`). Si el nivel tiene 3 libros, el cuarto no entra en el estante: agregar una columna en `Library.SHELF_COLUMNS`.
5. **Exploración lunar:** crear su escena y poner la ruta en `MainMenu.LEVEL_EXPLORATION`; el botón se activa solo.

## Modelos 3D de la simulación

- **Saturno V:** modelo oficial de NASA 3D Resources (`3D Models/Saturn V`), dividido en 6 piezas a escala real (110,6 m): `ai_assets/models/saturno_v/` (script `tools/blender/saturn_split.py`). La 1.ª etapa mide 42,08 m en el modelo (real: 42,1 m).
- **Plataforma y torre roja:** modelo propio simplificado en Blender (`tools/blender/lut.py`), con el estilo de la torre umbilical del Apolo. No se usó el "Mobile Launcher" de NASA 3D Resources porque es el de Artemis (SLS), no el del Apolo.
- **Tierra:** esfera de radio real (6371 km) con shader procedural (`resources/shaders/tierra.gdshader`); cerca de la plataforma hay costa: tierra al oeste y océano Atlántico al este.
- No se usó Hunyuan3D: su página exige iniciar sesión con una cuenta de Tencent, y había modelos oficiales de la NASA para el cohete.
