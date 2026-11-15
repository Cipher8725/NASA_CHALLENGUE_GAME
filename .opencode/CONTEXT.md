# Estado del Proyecto: NASA Space Apps - Junior Astronaut Mission Trainer

## 1. Resumen General

Juego de simulación y supervivencia mediante administración de recursos en
**Godot 4.7.2** para el reto "Junior Astronaut Mission Trainer". El jugador
administra cuatro recursos vitales (oxígeno, energía, agua y estructura)
durante una misión de 180 segundos dentro de un hábitat espacial 3D, reparando
las consolas del hábitat mientras las colisiones ambientales erosionan los
sistemas.

- **Motor**: Godot 4.7.2 (`H:\Godot V4.7.2\Godot_v4.7.2-stable_win64_console.exe`)
- **Lenguaje**: GDScript con tipado estricto (decisión del arquitecto, AGENTS.md §2)
- **Física**: Jolt Physics 3D
- **Renderizador**: `gl_compatibility`
- **Resolución**: 1280x720, landscape

## 2. ¿Qué se hizo?

### Hito 1 — Saneamiento del proyecto (Fase 0)

- Reorganización de `.opencode/skills/`: las 22 skills de `Open-Code-Godot-Studio`
  estaban en una ruta con directorio oculto (`.opencode/skills/Open-Code-Godot-Studio/.opencode/skills/`)
  y **no se autocargaban**. Se movieron a `.opencode/skills/<nombre>/SKILL.md`
  y ahora las 34 skills (12 de `Godot-Skills` + 22 del Studio) están activas.
- Normalización de `godot-class-name-checker` a `SKILL.md` con frontmatter válido
  (se reconstruyó en UTF-8 tras detectarse corrupción de caracteres).
- `.opencode/CONTEXT.md` movido a la ruta que exige `AGENTS.md` §9 (antes estaba
  en `.opencode/skills/CONTEXT.md`).
- `rules/`, `hooks/`, `docs/`, `mcp.json`, `settings.json` y `setup-mcp.*`
  promovidos a `.opencode/`; `design/gdd/` a la raíz; `OPENCODE.md` a la raíz.
- Reescrita `scenes/habitat.tscn` (antes `Habitat.tscn`): corregidos el UID
  malformado (`1234567890-...` → UIDs reales `uid://...`), el `load_steps`
  incorrecto, la doble instancia del `GameManager`, el nodo `AmbientLight`
  (WorldEnvironment sin `environment`) y la ausencia total de cámara.
- Reescrito `scripts/game_manager.gd` (antes `GameManager.gd`, obsoleto):
  `class_name GameManager`, `static var instance` + `get_instance()`,
  máquina de estados de misión, emisión de señales a 10 Hz, persistencia JSON.
- `project.godot`: escena principal, Autoload `Game`, mapa de entradas.

### Hito 2 — Bucle jugable completo (Fases 1-3)

- `scripts/habitat_player.gd` + `scenes/player.tscn`: `CharacterBody3D` con
  `CapsuleMesh`, cámara de tercera persona sobre `SpringArm3D`, `Area3D` de
  interacción con `SphereShape3D`, salto, gravedad y ratón capturado.
- `scripts/resource_console.gd` + `scenes/console.tscn`: consola por recurso con
  `Label3D` y material propio; se instancian 4 en el hábitat.
- `scripts/mission_hud.gd` + `scenes/hud.tscn`: HUD con 4 `ProgressBar`, valores
  numéricos, cronómetro, puntuación, alertas y panel de resultado. Observa
  señales; nunca modifica el estado.
- `scripts/emergency_system.gd` + `scenes/emergency_system.tscn`: generador de
  micrometeoritos, sobrecargas, caídas de presión y fugas de agua.
- `scripts/mission_config.gd` + `resources/default_mission.tres`: configuración
  data-driven (sin números mágicos).
- `scripts/mission_controller.gd` + `scenes/main.tscn`: orquestación, cuenta
  atrás y reinicio con `R`.
- `scripts/habitat.gd`: Registro y consulta de las consolas del hábitat.

### Hito 3 — Calidad y verificación

- Suite de 4 pruebas automatizadas en `tests/` (54 comprobaciones en total):
  `functional_test` (24), `interaction_test` (8), `simulation_test` (13),
  `asset_collision_test` (9 sobre 64 mallas / 537 pares).
- MCP de Godot **configurado y conectado** (`opencode.json`), con 14 tools
  operativas (`godot_run_project`, `godot_update_project_uids`, etc.).
- Skill `godot-unix-timestamp-fix` corregida: `OS.get_unix_time()` no existe en
  4.7.2 → `Time.get_unix_time_from_system()`.
- Tablas de `anchors_preset` corregidas en 3 skills tras verificarlas contra el
  motor (los valores publicados eran erróneos: `8`=CENTER, `12`=BOTTOM_WIDE).
- `engine-reference/godot/` actualizado a 4.7.2 con los hallazgos verificados.
- `design/gdd/game-concept.md` rellenado con el concepto de diseño real.

### Hito 4 — Control de versiones y assets 3D

- **Repositorio Git reparado y commit inicial creado** (`3f704e5`, rama `main`):
  - Eliminado el submódulo fantasma: `.opencode/skills/Godot-Skills` estaba en
    el índice como gitlink (modo `160000`) sin `.gitmodules`. Al clonar, el
    compañero recibía **0 de 34 skills**. Verificado con un clon real.
  - `.gitignore` corregido: `*.gd.uid` **no** se ignora (requisito de Godot
    4.4+; verificado que Godot regenera UIDs distintos si faltan).
  - `core.autocrlf=input` configurado (recomendación de Godot para Windows).
  - Identidad Git: `Cesar <flixian2@gmail.com>` (a nivel de repo, no global).
  - **Git LFS** configurado para `.glb`, `.png`, `.fbx`, `.obj`, audio y fuentes
    (antes del primer commit, como exige la documentación de Godot).
- **Assets 3D integrados** (fin del greyboxing del entorno):
  - Set curado de 16 modelos Molten Maps (CC0) + 2 de fondo espacial en
    `res://ai_assets/`, renombrados en `snake_case`.
  - `scenes/habitat_decor.tscn` con 25 baldosas, 20 paredes, 4 luces de techo
    y 10 props → 64 mallas en total.
  - `scenes/console.tscn` usa ahora `command_console.glb` real (escala 0,55).
  - Test `asset_collision_test.gd` que valida la colocación de los assets.
- **Packs de terceros retirados del proyecto** a la boveda
  `H:\GodotProyects\GodotProyects 4.7.2\nasa-asset-vault\` (130 MB),
  por licencia (dos packs prohíben redistribuir) y por tamaño.
  Los `.blend` (96 MB) se eliminaron: sin Blender son inservibles y Godot 4.7
  no los importa.
- `ai_assets/LICENSES.md` y `docs/ASSETS.md` documentan origen y licencias.

### Hito 5 — Estación espacial con los packs in situ (2026-11-12)

- **Los packs vuelven a `assets/` y se usan in situ** (orden del arquitecto:
  no moverlos). Se eliminaron las copias de `ai_assets/habitat/` y
  `ai_assets/space/`, que quedaron sin uso: las escenas ahora referencian
  `res://assets/Molten Maps SciFi Asset Pack/...`,
  `res://assets/KayKit_Space_Base_Bits_1.0_FREE/...` y
  `res://assets/Planets_Asteroids_FREE_SAMPLE/...`.
- **`scenes/station_platform.tscn`** (nuevo): cubo gris de 60 m (placeholder,
  material aislado en `resources/station_platform_material.tres`), pasarela y
  módulos laterales de Molten Maps, y decorado exterior de KayKit (depósitos
  de carga, contenedores apilados, camión, paneles solares, plataforma de
  aterrizaje con lander y farolas).
- **`scenes/habitat_decor.tscn` reconstruido** con piezas reales: 25 baldosas
  de suelo, 4 franjas de peligro, 20 paneles de pared (3 ventanales
  `Wall_Glass_Clear` al +Z y 2 puertas), 21 baldosas de techo + 4 luminarias y
  22 props (generador, baterías, literas, tubo criogénico, hidroponía,
  comedor, orrery, plantas, tuberías, aires acondicionados, pantallas y un
  monitor grande).
- **`scenes/habitat.tscn`**: instancia la plataforma y el interior, coloca las
  4 consolas en z = -7.85, añade 4 luces omni interiores y el fondo espacial
  (planeta Verdant World a escala 140 y asteroide). El sol se reorientó para
  iluminar la cara del planeta que mira al módulo; se añadió una luz de
  relleno sin sombras y tonemap ACES para contener los blancos.
- **Bug de física corregido**: las colisiones de las paredes laterales estaban
  sin rotar y cubrían media habitación (el jugador quedaba atrapado dentro de
  un sólido). Ahora están rotadas 90° sobre Y en x = ±9.6, con
  `BoxShape3D_wall` de `(20, 4, 0.74)`, coincidiendo con la cara interior de
  los paneles visuales.
- **Tests**: `asset_collision_test` actualizado (100 mallas, 911 pares; ignora
  el subárbol `StationPlatform` y los grupos `Floor`/`Ceiling`) y nuevo
  `tests/physics_test.tscn`, que con raycasts y `test_move` verifica que el
  centro de la sala es transitable, las 4 paredes y el suelo bloquean y el
  punto de aparición está libre.
- **Verificación real**: import + 5 suites (`functional`, `interaction`,
  `simulation`, `asset_collision`, `physics`) → `TODO OK`; además se
  renderizaron capturas del juego para revisar ventanal, consolas y exterior.
- **Limpieza**: `tools/restore_assets.sh` (obsoleto) sustituido por
  `tools/check_assets.sh`; `.gitignore` excluye los 3 packs por licencia y
  tamaño; `docs/ASSETS.md` y `ai_assets/LICENSES.md` actualizados.

### Hito 6 — Minijuegos de reparación (oxígeno y energía) (2026-11-12)

- Las reparaciones de **oxígeno y energía ya no son instantáneas**: al pulsar
  `E` en su consola se abre un **minijuego** con cuenta atrás. El agua y la
  estructura se siguen reparando al instante (aún sin minijuego).
- **Minijuego del oxígeno** (`scenes/ui/minigame_oxygen.tscn`): una aguja
  recorre una barra de presión y hay que **pulsar el botón** (ratón o ESPACIO)
  mientras la aguja está dentro de la zona verde. Acierto = +presión y +tiempo;
  fallo = −presión y −tiempo. La zona se estrecha al avanzar.
- **Minijuego de energía** (`scenes/ui/minigame_cables.tscn`): hay que
  **conectar 4 cables** con su conector (misma letra, conectores barajados).
  Una conexión incorrecta penaliza el tiempo y la presión. Las líneas
  conectadas se dibujan con `scripts/cable_wire_layer.gd`.
- **Arquitectura**:
  - `scripts/repair_minigame.gd` (`RepairMinigame`) es la base común:
    temporizador, progreso, resultado y puntos de extensión `_setup()`,
    `_update_visuals()` y `_handle_action_input()`.
  - `scripts/repair_minigame_manager.gd` (`RepairMinigameManager`, un
    `CanvasLayer` en el grupo `repair_minigames`) abre el minijuego que
    corresponde a cada recurso, bloquea el control del jugador y aplica la
    reparación en el `GameManager` al terminar.
  - El registro de minijuegos vive en `_scene_for()`: para añadir uno nuevo
    (agua, estructura, o mover las consolas cuando se amplíe el mapa) basta
    con registrar su escena y su script.
- **Jugador**: `set_input_enabled()` bloquea movimiento, salto e interacción
  mientras hay un minijuego abierto y libera el ratón (`MOUSE_MODE_VISIBLE`).
  Escape cancela la reparación; `R` no reinicia la misión con un minijuego
  abierto.
- **Grupos usados**: `player`, `mission_hud` y `repair_minigames`. Ojo: en
  Godot 4 los grupos van en la **cabecera del nodo**
  (`[node name="X" type="Y" groups=["grupo"]]`), no como propiedad aparte.
- **Tests**: nuevo `tests/minigame_test.tscn` (mecánica de ambos minijuegos +
  integración con la consola) y `tests/interaction_test.gd` reescrito para el
  nuevo flujo. Suite completa: 6 pruebas, todas en verde.

### Hito 7 — Módulos de habitación (2026-11-12)

- **9 módulos nuevos** en `scenes/rooms/`, construidos con piezas de Molten
  Maps (in situ, sin tocar ninguna escena existente):
  `room_cafeteria`, `room_quarters`, `room_generator`, `room_control`,
  `room_hydroponics`, `room_medbay`, `room_briefing`, `room_storage` y
  `corridor_module`.
- **Convención de módulos** (documentada en `scenes/rooms/README.md`):
  - Origen = centro de la zona de suelo; suelo de -4..+4 (8×8) o -2..+2 (8×4).
  - Paredes **por fuera** del suelo, centradas en `x/z = ±4.37` (`±2.37` en
    8×4); cara interior en `±4.00`.
  - **Puerta siempre en la pared −Z** (panel en `x = -2`), para encadenar
    módulos en filas separadas por pasillos.
  - Techo a `y = 4`; las luminarias cuelgan en `y = 3.66` (sin z-fighting).
  - Un `OmniLight3D` por luminaria (`y = 3.45`) con el tono de cada sala.
  - Colisión invisible en el nodo `Collision`: suelo + un tramo por panel; la
    puerta se hace con dos tramos para dejar un hueco de 1,6 m.
- **Trampa de la rejilla**: el `Transform3D` de un `.tscn` se interpreta en
  **filas**, así que una rotación de 90° invierte el desplazamiento del modelo.
  Varias piezas del pack tienen el origen descentrado (`Command_Console` va de
  `z = -1.73` a `3.15`, `Bunk_Double_Grey` de `x = -1.25` a `0.75`): hay que
  colocar midiendo la AABB real, no suponiendo que el modelo está centrado.
- **Tests**: nuevo `tests/room_collision_test.tscn` que instancia los 9
  módulos, valida su estructura y comprueba que ningún mueble se solapa con
  otro (AABB, umbral 0,05 m³). La suite completa queda en 7 pruebas.
- `scenes/rooms/rooms_preview.tscn` coloca los 9 módulos en fila para
  compararlos (no forma parte del juego).
- **Pendiente de decisión del arquitecto**: los módulos todavía no se
  instancian en el mapa; falta que indique dónde y con qué orientación.

### Hito 8 — Módulos IMG_ recreados desde `assets/IMG/` (2026-11-12)

- **8 módulos nuevos** en `scenes/rooms/`, recreados a partir de las fotos de
  referencia de `assets/IMG/` (renders del pack Molten Maps):
  `IMG_vestibulo` (6bDelJ), `IMG_sala_de_mando` (pGXT9C),
  `IMG_sala_del_generador` (PjBOyt), `IMG_enfermeria` (9tMILo),
  `IMG_criotanque` (bK2PlK), `IMG_cuartos` (DnG84u),
  `IMG_sala_de_reuniones` (S4lJ0w) y `IMG_sala_del_orrery` (vnoCXw).
- Misma convención que el Hito 7 (origen en el centro, paredes fuera, puerta
  en −Z, techo a y = 4, omni por luminaria, colisión invisible).
- **Dos criterios de colocación** que quedaron fijados:
  - Las franjas de peligro (`Hazard_Floor_1`) van en el nodo `Floor`: son
    superficie de apoyo, igual que las baldosas.
  - Las escaleras (`Ramp_Grey`) son piezas de 4 × 4 m con paredes propias, así
    que van **fuera** del módulo, junto al ventanal, como en las fotos.
- `tests/room_collision_test.tscn` valida ahora **17 módulos** (9 + 8) en
  total: estructura mínima + cero solapes.
- Las 8 escenas se generaron con un script temporal (fuera del repo) para
  mantener la estructura idéntica entre módulos; los `.tscn` resultantes son
  los que quedan versionados.

### Hito 9 — Módulos ampliados a 20 × 20 m (2026-11-12)

- **Todos los módulos de habitación pasan a 20 × 20 m**, con la **misma retícula
  que el módulo de habitat** (`scenes/habitat_decor.tscn`):
  - Suelo: 5 × 5 baldosas de 4 m con centros en −8, −4, 0, 4, 8 (−10..+10).
  - Paredes: 5 paneles de 4 m por lado centrados en ±9,6 (cara interior ±9,23);
    la puerta (`Wall_With_Door_Grey`) en la pared sur, en x = 0.
  - Techo: 21 baldosas + 4 luminarias en (±4, ±4); 8 luminarias en las salas
    técnicas. Luminarias en y = 3,66 y omni en y = 3,45.
  - Colisión: caja de suelo (20 × 0,4 × 20) y una por panel; la puerta con
    dos tramos para dejar un hueco de 1,6 m.
- **MobiliarioAmpliado** en los 17 módulos: ~90 mallas por habitación (el
  módulo de habitat tiene ~110), con más muebles y repartidos por los 400 m².
- **Excepción**: `corridor_module` pasa a 8 × 8 m (dos tramos de
  `Corridor_Boundary_4x8` del pack) porque su función es conectar, no alojar.
- Nuevas reglas de colocación que quedaron fijadas:
  - Los **paneles de pared comparten grupo** en el test: en las esquinas se
    solapan entre sí por diseño (igual que en habitat).
  - Las **piezas cerradas** (tramos de pasillo) van en el nodo `Shell` y el
    test las ignora: su AABB engloba el módulo y daría solapes falsos.
  - Las **lostas grandes de suelo** (`Floor_Command_Large`,
    `Floor_Medbay_Large`) van en el nodo `Floor` como decals (son 8 × 8 m y no
    cubren un módulo de 20 × 20 m).
- `rooms_preview.tscn` actualizado a 22 m de separación entre módulos.

### Hito 10 — Accesibilidad, primera persona y salas nuevas (2026-11-12)

- **Accesibilidad (el bug del "muro invisible")**: las colisiones del hábitat
  eran **cajas de 20 m** que cerraban las puertas. Ahora `scenes/habitat.tscn`
  tiene **una caja por panel de pared** y las puertas se parten en **dos
  tramos** (hueco de 1,6 m).
  - Doors del hábitat: oeste (z = 0), este (z = 0) y norte (x = 0).
  - Puertas nuevas en las salas: cuartos (norte y este), sala de reuniones
    (norte), enfermería (este) y sala del generador (oeste).
- **Nuevo test `tests/station_access_test.gd`**: recorre toda la estación y
  comprueba que el paso de cada puerta está libre y que por detrás hay 8 m de
  espacio abierto. Es la red de seguridad del bug de las puertas.
- **Cámara en primera persona**: `scenes/player.tscn` ya no tiene
  `CameraPivot` ni `SpringArm3D`; la `Camera3D` cuelga de la cabeza (y = 1,6) y
  las mallas del cuerpo y la cabeza se ocultan. El mouse gira el cuerpo (yaw) y
  la cámara (pitch).
- **Salas nuevas** (20 × 20 m) encadenadas al norte de la estación:
  `cuartos → pasillo → sala de reuniones → pasillo → enfermería → pasillo →
  hidroponía` (a 102 m del centro). Al oeste, la **sala del generador** enlaza
  con la **nueva sala de oxígeno** (`scenes/rooms/room_oxigeno.tscn`), que
  contiene el panel de control de oxígeno.
  - Criterio: dos salas de 20 m **no pueden solaparse**, así que se encadenan
    en línea con pasillos intermedios.
- **Paneles de consola reubicados**:
  - Oxígeno → en la sala de oxígeno (`room_oxigeno.tscn`).
  - Escudo radioactivo → **dentro del generador**, invisible pero
    interactuable (`ResourceConsole.panel_visible = false` oculta el modelo, la
    etiqueta y el cuerpo sólido).
- **Sistema "Estructura" → "Escudo radioactivo"**: `RESOURCE_STRUCTURE` pasa a
  `RESOURCE_SHIELD` (&"shield"), con `max_shield` y `shield_decay_rate` en
  `MissionConfig`, y la etiqueta del HUD y de la consola.
- La suite queda en **8 pruebas**: `functional`, `interaction`, `simulation`,
  `asset_collision`, `physics`, `minigame`, `room_collision` y
  `station_access` (todas en verde).

### Hito 11 — Cielo espacial, regolita lunar/marciana y HUD infantil (2026-11-13)

- **Cielo realista y sobrio** (`resources/sky_space_material.tres`):
  `PanoramaSkyMaterial` con panorámica equirectangular 2:1 de 2048×1024. Sustituye
  al `ProceduralSkyMaterial` anterior. La imagen se generó con IA (API de Layer,
  `flux-3-image`) y se procesó con `tools/process_ai_textures.py`.
  - Sin costura horizontal: mitad izquierda = imagen, mitad derecha = su reflejo.
  - Variación de brillo periódica (una sola onda por vuelta) para disimular la
    simetría del reflejo y desvanecido en los polos (las estrellas no se estiran
    en el cenit/nadir).
- **Regolita lunar** en el cubo base (`resources/station_platform_material.tres`):
  albedo + normal, `uv1_scale = 12` (una baldosa cada 5 m en un cubo de 60 m).
- **Regolita marciana** en todos los suelos interiores
  (`resources/mars_ground_material.tres` + `scripts/regolith_floor.gd`):
  - El pack modela el suelo como baldosas sueltas; en vez de tocar 257 nodos, el
    script del nodo `StationInterior` recorre los contenedores `Floor` /
    `FloorTiles` (incluidas las salas instanciadas) y asigna `material_override`.
  - Material **triplanar en espacio de mundo** (`uv1_triplanar`), así la textura
    es continua entre baldosas, salas y pasillos.
  - Un `@export var enabled` lo revierte al suelo original del pack.
- **Cristal de las ventanas** (`resources/window_glass_material.tres` +
  `scripts/window_glass.gd` en el nodo `Walls`): el `Wall_Glass_Clear.glb` del
  pack trae el cristal tintado (alfa 0.45) y en Compatibility no hay transmisión,
  así que se veía como un panel azul opaco. El script sustituye **solo** la
  superficie cuyo material se llama "... Glass" (el marco se respeta) por un
  material `transparency = ALPHA` + `shading_mode = UNSHADED` con alfa 0.10: deja
  ver el espacio y no se "enciende" con las lámparas del techo.
- **HUD "para niños" (7-12 años)**: `scenes/hud.tscn` reconstruido con tarjetas
  redondeadas, un color por recurso (oxígeno azul, energía amarilla, agua verde
  azulada, escudo violeta), etiquetas de 19 px, cuenta atrás de 46 px, avisos en
  "píldora" y panel de resultado con "Pulsa R para volver a jugar".
  `scripts/mission_hud.gd` muestra **tiempo restante** (no transcurrido) y lo
  colorea en ámbar a 30 s y rojo a 10 s; la etiqueta de estado cambia de color
  según `MissionState`. Los 15 nombres únicos (`%`) se mantienen.
- **Ajuste de luz**: el ambiente pasó de `ambient_light_source = SKY` (negro) a
  color `(0.42, 0.52, 0.78)` con energía `0.5`, `tonemap_exposure = 0.95`, sol
  `1.05`, relleno `0.3` y lámparas interiores `1.15`: las paredes ya no salen
  lavadas ni negras.
- **Bug corregido en `scenes/station_platform.tscn`**: los 4 paneles solares
  declaraban `parent="SolarArray"` (ruta relativa a la raíz) en vez de
  `parent="Exterior/SolarArray"`; Godot los descartaba con
  `WARNING: Parent path './SolarArray' ... has vanished`. Ya aparecen.
- **Texturas fuera de 4K/Full HD**: cielo 2048×1024 y suelos 1024² (normales
  512²), en **WebP** (q95 cielo, q90/q92 suelos; 1,69 MB en total). El JPEG
  producía bloques de 8×8 px visibles al ampliar el cielo en pantalla.
  - Los `.import` llevan `compress/mode = 0`, `detect_3d/compress_to = 0` y
    `mipmaps/generate = true`: Godot no las recomprime a VRAM al usarlas en 3D.
- Suite de 8 pruebas + `--headless --import` en verde tras los cambios.

### Hito 12 — Suelo sin regolita y plataforma a la medida del hábitat (2026-11-13)

- **Bug corregido: todo el suelo del hábitat se veía con regolita ("Marte").**
  El nodo `StationInterior` de `scenes/habitat_decor.tscn` tenía
  `floor_material = moon_ground_material.tres`, así que `RegolithFloor`
  sobrescribía **257 mallas** con la textura triplanar, incluidas las franjas de
  peligro `Hazard_Floor_1` (de ahí los manchones blancos: las rayas amarillas y
  negras se perdían). Ahora:
  - `StationInterior` lleva `enabled = false` y ya no tiene `floor_material`; se
    eliminó el `ext_resource` de `moon_ground_material.tres`.
  - El suelo muestra el **material original del pack Molten Maps**
    (`Floor_Tile_Metal` y las baldosas propias de cada sala), franjas de peligro
    incluidas.
  - `scripts/regolith_floor.gd`, `resources/moon_ground_material.tres` y
    `resources/mars_ground_material.tres` se conservan **reservados** y
    documentados para un futuro nivel lunar/marciano: no se cargan en el juego.
- **`resources/station_platform_material.tres` ya no usa textura**: pasó de
  regolita lunar (albedo + normal, `uv1_scale = 12`) a material sólido
  (`resource_name = "StationPlatformMetal"`, `albedo_color` gris
  `(0.42, 0.44, 0.48)`, `metallic = 0.15`, `roughness = 0.92`). **Ninguna
  textura de regolita se carga en el juego**, ni lunar ni marciana.
- **`scenes/station_platform.tscn` redimensionado**: de un cubo de 60 m a un
  `BoxMesh` de **84 × 60 × 160 m** centrado en `(0, -30.15, 37)`. La cara
  superior sigue en `y = -0.15` (las baldosas ocupan `y = -0.14 .. 0.01`, sin
  z-fighting) y la huella `x -42..42 · z -43..117` cubre con ~4 m de margen el
  AABB real del interior (`x -37,95..37,44 · z -37,62..111,8`), que incluye la
  hilera de salas del norte hasta hidroponía.
- **Decorado exterior recolocado** (medido con intersecciones de AABB): antes
  había piezas enterradas dentro de salas, porque el complejo creció hacia el
  norte en los hitos 7-10. Nuevo reparto, solo en zonas libres:
  - Balcón `ViewDeck` al borde **sur** (`z = -40,5`, barandillas a `-42,9`);
    antes estaba delante del ventanal norte, que hoy ocupa `room_quarters`.
  - `SideModules` en el ala oeste `(-33 / -27,5, -0.15, 40)`.
  - Patio de carga al sur: `CargoDepot_A (-12,-34)`, `CargoDepot_B (-4,-36)`,
    `CargoStack_0..3 (5/9, -34/-30)`, `SpaceTruck (13,-25)`.
  - Planta solar al suroeste (`x = -38`, `z = -40/-37,3/-34,6/-31,9`).
  - `Outpost` en el oeste-norte `(-24, -0.15, 60)`.
  - Plataforma de aterrizaje, lander y farolas sin cambios al este (`z = 15/19`).
  - Zonas libres documentadas en la cabecera de `station_platform.tscn`.
- **Verificación**: script de diagnóstico (ya eliminado) confirmó
  `TEXTURAS REGOLITA EN USO: 0` y `SOLAPES DECORADO/SALAS: 0`; capturas
  interiores (baldosas metálicas del pack + franjas de peligro) y vistas cenital
  y oblicua con todas las salas sobre la plataforma.
- **Tests**: se corrigió la cabecera de `tests/asset_collision_test.gd` (hablaba
  del "cubo de 60 m"). Suite de 9 pruebas + `--headless --import` en verde.
- **Ruido conocido (no es regresión)**: en `--headless` el renderizador dummy
  emite `ERROR: Parameter "material" is null.`
  (`material_storage.cpp:264`). Se reprodujo con escenas aisladas y con el menú
  solo (sin emitirlo), y no afecta a ninguna prueba: es del renderizador dummy,
  no del proyecto.

### Hito 13 — Menú principal (2026-11-14)

- **La escena de arranque pasó a ser el menú**: `project.godot` tiene
  `run/main_scene="res://scenes/main_menu.tscn"`. El menú (`scripts/main_menu.gd`,
  `scenes/main_menu.tscn`) tiene dos pantallas en el mismo archivo: inicio
  (`%MainPanel`, botón `%StartButton`) y selector de destino (`%LevelPanel`,
  `%MoonButton`, `%MarsButton`, `%BackButton`). Solo el nivel Luna está activo
  (`LEVEL_MOON = "res://scenes/main.tscn"`); Marte se ve pero está desactivado
  (`LEVEL_MARS = ""`).
- **Test**: `tests/menu_test.gd` comprueba que la escena de arranque es el menú,
  que el selector abre y cierra y que Marte sigue desactivado.
- El juego (`scenes/main.tscn` + `GameManager`) no cambia: el menú solo cambia
  de escena.

### Hito 14 — Puertas que se abren solas (2026-11-14)

- **Puerta corredera con dos hojas** (`scenes/DoorAnim.tscn`): las hojas se
  deslizan en X con la animación `Open` (0,45 s). El script
  `scripts/animated_door.gd` (`class_name AnimatedDoor`) mide la distancia
  horizontal al jugador (grupo `player`) y **abre a 3,5 m o menos** y **cierra
  al alejarse**.
- **Cierre en reversa**: se usa una sola animación. El cierre es la misma
  animación reproducida al revés (`play(nombre, 0.0, -1.0, false)`), así que no
  hay dos animaciones que sincronizar y una interrupción a mitad no produce
  saltos. Detalle de Godot 4.7: hay que **pasar la velocidad en la llamada a
  `play()`**; si se deja el valor por defecto, una animación ya terminada no
  vuelve a reproducirse (verificado con un script de sonda).
- **Sin colisión**: la puerta no tiene `CollisionShape3D`. Se abre antes de que
  llegue el jugador, así que nunca le cierra el paso y el test de accesibilidad
  (`station_access_test`) sigue viendo el hueco libre.
- **Colocación**: 26 puertas en las 17 habitaciones de `scenes/rooms/` (26 huecos
  reales) y 3 en el módulo central (`scenes/habitat_decor.tscn`: norte, oeste y
  este). Todas bajo el nodo `Walls` de su sala, centradas en el hueco del panel
  `Wall_With_Door_Grey` (hueco real: **1,39 m de ancho × 2,06 m de alto**,
  medido sobre el `.glb` del pack). Transform de instancia: escala
  `(1.6, 2.0, 1.0)` y `y = 1.0` (la hoja apoya en el suelo y llega al dintel).
- **Nombre de las mallas de la puerta**: `Wall With Door Grey_A` / `_B`. El test
  de colisiones agrupa las mallas por el nombre del nodo de malla, así que con
  ese nombre la puerta cae en el mismo grupo que el panel del pack y su solape
  (intencionado: la puerta va dentro del hueco) no se reporta como error.
- **Verificación**: script temporal (ya eliminado) comprobó en las 18 escenas que
  las 46 puertas están centradas en su panel y apoyan en el suelo, y que en el
  hábitat las 20 puertas montadas abren y cierran con el jugador cerca/lejos.
  Suite de 9 pruebas en verde.

### Hito 15 — Taller del Rover, puertas a medida y carnet con foto (2026-11-14, rama `feat/rover-puertas-carnet`)

- **Taller del Rover** (`scenes/rover_workshop.tscn`, `scripts/rover_workshop.gd`):
  ensamblaje del Perseverance (modelo oficial NASA 3D Resources dividido en 16
  piezas, `ai_assets/models/perseverance/`). Modos guiado y evaluación; la
  evaluación con 2+ estrellas sube el carnet a nivel 2. Datos de cada pieza
  (material, importancia, instrumentos, fuentes) en `piezas_perseverance.json`
  → `resources/rover_perseverance.tres`. Las 6 ruedas también sueltas en `ruedas/`.
- **Puertas corredizas** `SlidingDoor` (`scenes/doors/auto_door.tscn` y
  `restricted_door.tscn`, distintas de `DoorAnim`): `@tool`, tamaño ajustable en
  el Inspector (ancho/alto/grosor, apertura arriba o de lado). La restringida pide
  carnet de nivel 2 en el lector (tecla E). Script de Blender a medida en
  `tools/blender/`.
- **Carnet** (`AstronautCard`, `scenes/card_editor.tscn`): avatar o foto real
  (cabina con cámara `CameraServer`, cuenta 3-2-1, casco opcional, o subir foto).
  Foto solo en `user://carnet_foto.png`.
- Pruebas: `doors_test`, `rover_workshop_test`.

### Hito 16 — Menú "Nasa Space 2", Biblioteca y Simulación de despegue (2026-11-14)

- **Menú nuevo** con los sprites del paquete "Nasa Space 2"
  (`ai_assets/ui/menu/`, posiciones en `resources/menu_posiciones_1280x720.json`):
  JUGAR (abre el panel "Menú de juego"), BIBLIOTECA, SALIR y "Mi carnet".
  Panel: Base lunar (`main.tscn`), Armado del rover (taller), Simulación de
  despegue y Exploración lunar (desactivada, "Próximamente": `LEVEL_EXPLORATION = ""`).
  Todo dentro de `%Screen` (1280 × 720 centrado). Botones = `TextureButton` con
  variantes hover/pressed/disabled generadas a partir del PNG.
- **Biblioteca** (`scenes/biblioteca.tscn`, `scripts/library.gd`, `class_name Library`):
  9 libros (Básico / Intermedio / Avanzado) desde `resources/biblioteca/catalogo.json`,
  creados a partir de `%BookTemplate` en las posiciones de la maqueta. Lector de
  libro abierto: 3 dobles páginas (portada | pág. 1, pág. 2 | pág. 3, fuentes | fin),
  Anterior/Siguiente, flechas del teclado y Escape. Al terminar algunos libros
  ofrecen "Practicar" (rover → taller, despegue → simulación).
- **Simulación de despegue del Apolo 8** (`scenes/simulacion_despegue.tscn`,
  `scripts/launch_simulation.gd`, `class_name LaunchSimulation`): cabina con 4
  vistas (Q/E o flechas), ventanas transparentes (`ai_assets/apolo8/cabina_*.png`)
  con el cielo de `resources/shaders/cielo_despegue.gdshader` detrás (tapadas
  hasta soltar la torre de escape; azul → negro → estrellas → borde de la Tierra).
  Saturno V por piezas (`ai_assets/apolo8/etapas/`) que se sueltan. Altura,
  velocidad y horas de cada maniobra reales de la tabla de ascenso NASA SP-4029
  (`resources/apolo8/ascenso.json`). El reloj espera la orden del jugador en cada
  maniobra; si tarda más de `late_limit_real` la "computadora" la hace (error).
  Estrellas por errores. `step(delta)` permite probar sin tiempo real.
- Pruebas nuevas: `library_test`, `launch_simulation_test`; `menu_test` reescrito.

### Hito 17 — Simulación de despegue en 3D y paquete "Nasa Space 2" completo (2026-11-14)

- **Despegue 3D** (`scenes/simulacion_despegue_3d.tscn`, `scripts/launch_simulation_3d.gd`,
  `class_name LaunchSimulation3D extends LaunchSimulation`): reutiliza toda la lógica
  y la interfaz de la versión 2D (reloj, maniobras, errores, estrellas, telemetría
  real) mediante ganchos (`_update_visuals`, `_on_stage_dropped`, `_on_reset`,
  `_on_stage_jolt`, `_set_view`). El menú abre esta versión; la 2D sigue en
  `MainMenu.LAUNCH_SCENE_2D`.
- **Mundo 3D**: el cohete queda en el origen y el mundo se mueve. `%EarthPivot`
  baja `R + 7,6 m + altura real` y gira `alcance/R` (alcance real de SP-4029).
  Cohete vertical hasta 12 s y luego inclinado según `inclinacion_deg` (aproximada).
  Saturno V oficial (NASA 3D Resources) en 6 piezas a escala real
  (`ai_assets/models/saturno_v/`); al soltarse cada pieza se `reparent` a `%World`
  y cae. Fuego (`fuego_motor.gdshader`, conos aditivos) solo en la etapa que empuja;
  la S-IC se enciende a T−6,6 s. Humo `CPUParticles3D` con `local_coords`.
- **Cámaras**: exterior (`%ExteriorPivot`, arrastrar con el ratón, rueda = zoom) y
  cabina (`%CockpitCamera`, tecla C). **Importante (renderer gl_compatibility):**
  con `far` = 20 000 km no se dibuja nada; se usa `far = 4 000 000` y `near = 0.5`.
- **Cabina 3D**: 4 `QuadMesh` con `panel_cabina.gdshader` y las fotos del paquete;
  el vidrio transparente deja ver el mundo 3D; `covered` tapa las ventanas hasta
  soltar la torre de escape.
- **Paquete completo**: originales en `ai_assets/nasa_space_2/` y guía archivo por
  archivo en `docs/GUIA_NASA_SPACE_2.md`. Textos de los libros en
  `resources/biblioteca/libros/*.md`.
- Prueba nueva: `launch_simulation_3d_test`.

## 3. ¿Cómo se hizo?


### Arquitectura

```
scenes/main.tscn  (Node3D + mission_controller.gd)
├── Habitat       → instancia de scenes/habitat.tscn
│   ├── WorldEnvironment + SunLight + FillLight
│   ├── Floor / WallBack / WallFront / WallLeft / WallRight  (StaticBody3D + CollisionShape3D)
│   ├── StationPlatform → scenes/station_platform.tscn (bloque de 84 × 160 m + pasarela + exterior KayKit)
│   ├── Interior        → scenes/habitat_decor.tscn (suelo, paredes, techo y props)
│   ├── ConsoleOxygen / ConsoleEnergy / ConsoleWater / ConsoleStructure → scenes/console.tscn
│   ├── InteriorLights  → 4 OmniLight3D (uno por luminaria del techo)
│   └── SpaceBackdrop   → planeta Verdant World + asteroide
├── Player        → instancia de scenes/player.tscn (CharacterBody3D)
├── EmergencySystem → instancia de scenes/emergency_system.tscn (Node + Timer)
├── UILayer (CanvasLayer)
│   └── HUD       → instancia de scenes/hud.tscn (Control)
└── RepairMinigames (CanvasLayer, layer 10)
    └── (minijuego abierto) → scenes/ui/minigame_oxygen.tscn | minigame_cables.tscn
```

### Patrón de acceso al estado global

`GameManager` se registra como Autoload con el nombre **`Game`** y como clase
con `class_name GameManager`. Godot prohíbe que un `class_name` coincida con el
nombre de un Autoload (*"hides an autoload singleton"*), de ahí la separación.

El acceso **no** usa el identificador global `Game`, sino
`GameManager.get_instance()`, por dos motivos:

1. Las herramientas MCP ejecutan el motor con `--script`, modo en el que los
   identificadores de Autoload **no se registran** (`Compile Error: Identifier
   not found: Game`). Con `get_instance()` esas herramientas funcionan.
2. `get_instance()` tiene respaldo: si la variable estática aún no se publicó,
   busca el nodo del Autoload en el árbol.

`get_instance()` es **seguro en cualquier momento**: el inicializador de un
miembro de clase se ejecuta al construir el nodo (antes del `_ready()` del
Autoload), por lo que el acceso diferido es obligatorio en scripts que lo
necesiten durante el arranque.

### Flujo de señales (observador, nunca controlador)

```
GameManager (emite)                          Consumidores (observan)
─────────────────────────────────────        ──────────────────────────────────
resource_changed ──────────────────────────→ MissionHud (actualiza las 4 barras)
resource_critical ─────────────────────────→ MissionHud (alerta "nivel crítico")
resource_depleted ─────────────────────────→ MissionHud (alerta) + fail_mission()
resource_restored ────────────────────────→ MissionHud (confirmación)
emergency_triggered ───────────────────────→ MissionHud (alerta de emergencia)
mission_state_changed ─────────────────────→ MissionHud (etiqueta de estado)
mission_failed / mission_completed ───────→ MissionHud (panel de resultado)
```

`MissionHud` **nunca** modifica el estado: solo lee y refleja (regla de
`.opencode/rules/gameplay.md`).

### Capas de física (collision layer / mask)

| Objeto | Layer | Mask |
|--------|-------|------|
| Suelo y paredes (StaticBody3D) | 1 | 1 |
| Jugador (CharacterBody3D) | 2 | 1 |
| Consola (Area3D) | 4 | 0 |
| Área de interacción del jugador (Area3D) | 0 | 4 |

Así el `Area3D` del jugador detecta las consolas (`area_entered`) sin que el
cuerpo físico del jugador interfiera con ellas.

### Decaimiento y notificaciones

El decaimiento se aplica de forma continua en `_physics_process(delta)` (nunca
con números por frame), pero la señal `resource_changed` se emite a **10 Hz**
(`NOTIFICATION_HZ`) para no generar 240 señales por segundo. Los estados
`resource_critical` y `resource_depleted` son **transiciones de borde**
(`_critical_latched` / `_depleted_latched`), no estados continuos.

### Persistencia

`user://nasa_save_%d.json` con `JSON.stringify`. Marca de tiempo con
`Time.get_unix_time_from_system()` (verificado: `OS.get_unix_time()` ya no
existe en 4.7.2).

### Materiales aplicados por script (cristal y regolita reservada)

Cambiar a mano cientos de `material_override` en el `.tscn` es frágil, así que
dos scripts de un solo propósito hacen el trabajo al arrancar:

| Script | Nodo | Qué hace |
|--------|------|----------|
| `scripts/regolith_floor.gd` (`RegolithFloor`) | `StationInterior` de `habitat_decor.tscn` | **Desactivado** (`enabled = false` desde el Hito 12): no toca el suelo. Si se activa, recorre `Floor`/`FloorTiles` y pone la regolita de `floor_material` (triplanar de mundo) |
| `scripts/window_glass.gd` (`WindowGlass`) | `Walls` de `habitat_decor.tscn` | Sustituye solo las superficies de material "... Glass" por cristal transparente |

Ambos siguen el mismo patrón: `@export var enabled` para volver al estado
original del pack, `@export var <material>` para cambiar el material sin tocar
código, un contador `get_applied_*_count()` para las pruebas y un `print` único en
`_ready()` para verificar en el log.

### 4. ¿Qué hay que hacer?

### Pendiente inmediato (siguiente hito)

0. **Exploración lunar**: crear su escena y asignarla en `MainMenu.LEVEL_EXPLORATION`
   (el botón se activa solo). **Probar la cámara del carnet** en el equipo de la
   demo (Windows); si no hay cámara, queda "Subir una foto".

1. ~~**Textura del cubo de la estación**~~ → **resuelto en el Hito 12**: el
   bloque base usa un material sólido sin texturas
   (`resources/station_platform_material.tres`) y la regolita quedó reservada
   para el futuro nivel marciano. Si se quiere detalle en la plataforma, crear un
   `.tres` nuevo (nada de regolitas en el nivel lunar actual).
2. **Audio**: alarmas de recurso crítico, impacto de emergencia y confirmación
   de reparación. Usar `AudioStreamPlayer` definido en las escenas.
3. **Assets finales del jugador**: el astronauta sigue siendo una cápsula
   (`CapsuleMesh`). **Decisión actual: dejarlo así** (no hay modelo de
   astronauta en los packs). Si se quiere cambiar, usar Meshy
   (`MESHY_API_KEY`) y guardar el resultado en `res://ai_assets/`.
4. **Niveles adicionales**: segunda misión con distinta dificultad y más
   consolas, cargando una `MissionConfig` distinta.
5. **Remoto Git**: crear el repositorio en GitHub y añadirlo como `origin`
   (`git remote add origin <url>` + `git push -u origin main`). Pendiente de
   decisión del arquitecto: el repositorio debe ser **privado** mientras
   contenga assets con licencias restrictivas.

### Pendiente secundario

6. **Entrada de guardado/carga en el HUD**: botones `F5` (guardar) y `F9`
   (cargar) con la API `save_game` / `load_game` ya implementada.
7. **Sonido y música ambiental** del hábitat.
8. **Tutorial**: cartel inicial que explique los controles (WASD, ratón, `E`, `R`).
9. **Estadísticas de sesión**: tiempo total y misiones completadas, ya
   disponibles vía `get_missions_completed()`.
10. **Exportación**: crear `export_presets.cfg` para Windows/Linux.
11. **Minijuegos de agua y estructura**: replicar el patrón de oxígeno y
    energía cuando el arquitecto amplíe el mapa e indique las ubicaciones
    exactas de las nuevas consolas (o de los paneles de repairing).
12. **Colocar los módulos de `scenes/rooms/` en el mapa**: están listos y
    verificados, pero el arquitecto tiene que indicar dónde va cada uno y con
    qué orientación (la puerta mira siempre a −Z).
13. **Dos huecos de puerta de `room_quarters` sin paso real**: los paneles
    `Wall_South_5` (ala este) y `Wall_South_6` (ala oeste) son huecos de puerta
    visual, pero su pared sigue siendo maciza en `Collision` (no están partidos
    en dos tramos). Ahora tienen puerta animada (Hito 14), pero el paso sigue
    cerrado: hay que partir su colisión como en el resto de salas si van a
    conectar con otra habitación.

### Deuda técnica conocida

12. `scripts/mission_hud.gd` actualiza cronómetro y puntuación cada fotograma en
    `_process`. Es aceptable, pero puede pasar a 10 Hz igual que los recursos.
13. La skill `godot-console` menciona `--check-only` con `--script`; ese modo no
    registra Autoloads, así que solo sirve para scripts sin dependencias de
    Autoload (o usando `get_instance()`).
14. Los `.glb` de Molten Maps referencian sus texturas PNG por UID: **cada
    `.glb` debe permanecer junto a su PNG** (mismo nombre base). Por eso los
    packs se usan completos desde `assets/` y no se copian archivos sueltos.
15. Los tres packs de `assets/` **no están en Git** (licencias y ~136 MB). Al
    clonar hay que colocarlos y ejecutar `bash tools/check_assets.sh` antes de
    importar; sin ellos las escenas no cargan.
16. Los minijuegos son deliberadamente sencillos (el arquitecto los mejorará
    después): el de oxígeno es mantener la presión en una franja y el de cables solo 4
    conexiones fijas. La dificultad está en los `@export` de cada script.
17. **`tests/room_collision_test.gd` no está comprobando nada**: usa
    `mesh_instance.visible_in_tree`, que es una propiedad de `CanvasItem`
    (2D). En `MeshInstance3D` (3D) lanza `SCRIPT ERROR: Invalid access to
    property or key 'visible_in_tree'` y la malla nunca llega a la lista, así
    que el test sale en verde sin detectar ningún solape. En 3D la propiedad
    equivalente es `visible`. Hay que corregirlo y volver a pasar el test: puede
    destapar solapes reales en las habitaciones.

## 5. ¿Cómo hay que hacerlo?

### Reglas de implementación (obligatorias)

- **Tipado estricto** en todos los `.gd`: variables, parámetros y retornos.
  Sin excepciones (AGENTS.md §2, `.opencode/rules/gdscript.md`).
- **Nodos estructurales siempre en `.tscn`**: `CollisionShape3D`, `Camera3D`,
  `Timer`, `MeshInstance3D`, `Area3D`, `SpringArm3D`. Prohibido crearlos en
  `_ready()` (reglas del Studio + `coding-standards.md`).
- **La UI observa, la lógica decide**: el HUD se conecta a señales; el
  `GameManager` nunca conoce al HUD.
- **Todo valor ajustable es `@export` o un `Resource`** (`MissionConfig`).
  Sin números mágicos.
- **Toda lógica dependiente del tiempo usa `delta`**.
- **Acceso al gestor**: `GameManager.get_instance()`, nunca `Game.<algo>()`.
- **Verificar siempre contra el binario**: `--headless --import` para compilar y
  `opencode mcp list` / `godot_run_project` para el runtime. Ante la duda de si
  una API existe en 4.7.2, consultarla con
  `ClassDB.class_has_method("Clase", "metodo", true)`.

### Procedimiento de verificación (el que se usó)

```powershell
$godot = "H:\Godot V4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$root  = "H:\GodotProyects\GodotProyects 4.7.2\na-sa-game"

# 1. Importar / compilar (detecta errores de parseo)
& $godot --headless --path $root --import

# 2. Suite de pruebas (OJO: --quit-after cuenta iteraciones, no segundos)
& $godot --headless --path $root --quit-after 20000 "res://tests/functional_test.tscn"
& $godot --headless --path $root --quit-after 20000 "res://tests/interaction_test.tscn"
& $godot --headless --path $root --quit-after 20000 "res://tests/simulation_test.tscn"
& $godot --headless --path $root --quit-after 2000  "res://tests/asset_collision_test.tscn"
& $godot --headless --path $root --quit-after 2000  "res://tests/physics_test.tscn"
& $godot --headless --path $root --quit-after 20000 "res://tests/minigame_test.tscn"
& $godot --headless --path $root --quit-after 3000  "res://tests/room_collision_test.tscn"

# 3. Juego principal
& $godot --headless --path $root --quit-after 5
```

> `--quit-after N` cuenta **iteraciones del bucle**, no segundos. En headless las
> iteraciones pasan muy rápido, así que hace falta un valor alto (20000) para
> que los temporizadores reales (cuenta atrás de 3 s) lleguen a dispararse.

### Pipeline de texturas IA (`tools/process_ai_textures.py`)

1. Generar las imágenes crudas con la API de Layer (`LAYER_API_KEY`) en una
   carpeta temporal; **nunca** dentro del proyecto sin procesar.
2. `python tools/process_ai_textures.py --raw <carpeta> --out ai_assets/textures`
   - recorta 8 px del borde (artefactos del generador),
   - hace los suelos repetibles con **fundido cruzado circular**
     (`O = A·I + (1−A)·desplazada(I)`, banda del 20 %); el mosaico especular
     también cierra sin costura pero deja cráteres en rombo,
   - deriva las normales con Sobel circular (convención OpenGL, +Y arriba),
   - guarda en **WebP** (cielo q95, albedo q90, normales q92).
3. Tras el primer `--headless --import`, comprobar que cada `.webp.import` tenga
   `compress/mode = 0`, `detect_3d/compress_to = 0` y `mipmaps/generate = true`.
   Si `detect_3d` vale 1, Godot recomprime la textura a VRAM al usarla en 3D y
   aparecen bloques.
4. Los recursos (`resources/*.tres`) referencian `res://ai_assets/textures/...`.

### Patrón para añadir un recurso nuevo

1. Añadir la constante `StringName` en `GameManager` (`RESOURCE_*`).
2. Añadir su capacidad, tasa de decaimiento y getters en `MissionConfig`.
3. Añadir el `ProgressBar` + `Label` en `scenes/hud.tscn` con
   `unique_name_in_owner = true`.
4. Reflejarlo en `MissionHud._on_resource_changed` y en
   `MissionHud._update_resource_bar`.
5. Crear la consola correspondiente en `scenes/habitat.tscn` con su color.
6. Extender `tests/functional_test.gd` y `tests/simulation_test.gd`.

### Workflow de la skill `godot-gdscript`

La skill recomienda **no generar `.tscn` a mano** y usar MCP
(`godot_create_scene` + `godot_add_node` + `godot_save_scene`). Para el MCP
funciona, la ruta de la herramienta debe ser **relativa** (`.`), porque concatena
`res://` a la ruta recibida y una ruta absoluta produce `res://H:\...`.

### Control de versiones (reglas del proyecto)

- **Conventional commits** (lo valida el hook `validate-commit.sh`):
  `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `perf:`, `build:`,
  `ci:`, `style:`, `revert:`.
- **Nunca versionar** los `.uid` como ignorados: Godot 4.4+ los exige. Si
  faltan, se regeneran con valores distintos y se rompen las referencias
  `uid://` de las escenas.
- **Git LFS** para binarios (`.glb`, `.png`, `.fbx`, audio, fuentes). El
  `.gitattributes` ya está configurado.
- **Packs de terceros**: se usan **in situ** desde `assets/` y **no se
  versionan** (ver `.gitignore`). Dos licencias prohíben redistribuirlos y
  entre los tres suman ~136 MB. `ai_assets/` solo guarda las licencias y, en el
  futuro, los recursos generados por APIs. Antes de importar, comprobar el
  entorno con `bash tools/check_assets.sh`.
- **Verificar el clon** tras cambios en la estructura del repo:
  ```powershell
  git clone --no-hardlinks . <destino-temporal>
  # comprobar que llegan las skills, los .uid y los assets (LFS)
  ```

### Hito 18 — Escala uniforme de puertas AutoDoor (2026-11-14)

- Todas las puertas `AutoDoor` en las 17 habitaciones de `scenes/rooms/` han sido escaladas a **X: 1.145, Y: 1.369, Z: 1.0**, coincidiendo con la escala de referencia de `IMG_sala_del_generador.tscn`.
- Se modificaron **20 puertas** en 16 escenas (`IMG_sala_de_mando`, `IMG_cuartos`, `IMG_criotanque`, `IMG_enfermeria`, `IMG_sala_del_orrery`, `room_cafeteria`, `room_briefing`, `IMG_vestibulo`, `room_storage`, `IMG_sala_de_reuniones`, `room_hydroponics`, `room_medbay`, `room_generator`, `room_oxigeno`, `room_control`, `room_quarters`).
- Las 4 puertas con rotación (puertas en paredes este/oeste/norte: `room_briefing` Door_West_2, `IMG_vestibulo` Door_East_2, `room_medbay` Door_East_2, `room_quarters` Door_South_5 y Door_South_6) mantuvieron su rotación aplicando la escala sobre la matriz de rotación existente.
- No se modificó ningún otro nodo ni propiedad.

### Hito 19 — Cabina del Apolo 8 con modelos 3D de Hunyuan 3D (2026-11-14)

- Tres piezas 3D generadas con Hunyuan 3D (versión internacional, 3d.hunyuanglobal.com) desde
  imágenes de referencia "intermedias" (realistas pero sin choque con el estilo del juego):
  `ai_assets/models/cabina_apolo8/panel_principal_3d.glb` (2,30 m), `escotilla_3d.glb` (1,24 m)
  y `dsky_3d.glb` (0,62 m, escala 1,35 en escena). Datos en `cabina_apolo8.json`.
- Optimizadas con `tools/blender/hunyuan_optimizar.py`: 50k → 12–24k triángulos, texturas
  4096 → 1024/2048, origen centrado, tamaño en metros. Las texturas se exportan en PNG: con JPEG
  exportado desde Blender, Godot 4.7.2 no cargaba la textura base (modelo blanco).
- Colocadas como hijos de los paneles de `%Cabin` en `simulacion_despegue_3d.tscn`
  (PanelPrincipal3D, Escotilla3D, DSKY3D); `CabinLight` más fuerte (1,6) para que se lean.
  El DSKY va girado 180° porque el panel derecho mira hacia dentro con su −Z.
- Test: `launch_simulation_3d_test` comprueba que los tres modelos están en la cabina.
  Capturas: `docs/capturas/cabina_3d_hunyuan_*.png`.

### Hito 20 — Recursos de la NASA y la CSA (2026-11-15)

- **Radiación real (RadLab + DONKI).** `scripts/radiation_data.gd` (`RadiationData`, estático) lee
  `resources/radiacion/radlab_iss.json` (DosTel en la ISS, 1/4/2022, perfil de 24 h) y
  `resources/radiacion/donki_eventos.json` (22 erupciones M y X reales). El escudo se gasta con
  `shield_decay_rate × tasa(hora)/tasa_media` (180 s = 24 h, aproximado). Nueva emergencia
  `GameManager.EMERGENCY_SOLAR_STORM` (`tormenta_solar`): `EmergencySystem` elige una erupción real y
  llama a `GameManager.trigger_solar_flare()`; la severidad sale de la clase (C < M < X, tabla en el
  JSON). El HUD avisa la tormenta con su clase y fecha de DONKI, avisa los picos de RadLab y muestra un
  dato real al terminar la misión. Prueba: `tests/radiation_test.tscn`.
- **Comida y huerto (OSDR + CSA).** Quinto recurso `GameManager.RESOURCE_FOOD` (`max_food`,
  `food_decay_rate` en `MissionConfig`), barra COMIDA en `scenes/hud.tscn`, consola `ConsoleFood` en
  `scenes/rooms/room_hydroponics.tscn`. Minijuego `scenes/ui/minigame_hydroponics.tscn` +
  `scripts/minigame_hydroponics.gd` (`HydroponicsMinigame`): elegir luz roja 90:10 o azul 50:50
  (VEG-04), regar con ESPACIO (gasta agua) y mantener la humedad hasta los días reales de cosecha
  (lechuga 33, mizuna 35). La luz gasta energía (azul +15 %). Datos: `resources/hidroponia/cultivos.json`
  (OSD-745, OSD-780, OSD-655 y CSA). Prueba: `tests/hydroponics_test.tscn`.
- **Biblioteca: 11 libros.** «Tu cuerpo en el espacio» (Intermedio, OSDR + CSA) y «El clima del
  espacio» (Avanzado, DONKI + RadLab). Portadas nuevas con el mismo marco
  (`tools/portadas/make_covers.py`). La estantería tiene una cuarta columna (x 942).
- `README.md` con la tabla «Datos de la NASA usados».
- Nota: OSD-655 trata de la mizuna de VEG-04 (análisis de elementos y antioxidantes), no de estrés
  fisiológico humano.
- Pendiente: DONKI se descargó solo hasta el 14/3/2026 (límite de DEMO_KEY); con una clave gratuita de
  api.nasa.gov se puede completar el año. Fotos reales del Perseverance para el taller: pendiente.

### Hito 21 — Techo transitable y paneles solares en la sala del generador (2026-11-15)

- `scenes/rooms/IMG_sala_del_generador.tscn`, todo dentro del `StaticBody3D` `Collision`:
  - `ServiceStairs` (`ConvexPolygonShape3D` en cuña) con la **misma transformación literal** que
    `Props/ServiceStairs` (`Ramp_Grey.glb`, fuera del muro este). La malla sube 4 m en ~3,7 m
    (~47°, más que los 45° por defecto de `floor_max_angle`), así que la base de la cuña se alarga
    0,6 m hacia fuera (~41°) y por arriba entra 0,4 m en el techo.
  - `RoofShape`: caja 19,94 × 0,2 × 19,94 con la cara superior a 4,01 m. El borde **debe coincidir**
    con lo alto de la rampa (x = 9,97): con 20 m sobresalía 3 cm y el jugador se atascaba en la esquina.
  - 17 paneles `KayKit .../gltf/solarpanel.gltf` (escala 3, como en `station_platform.tscn`) en
    `Ceiling/SolarPanels`, uno por baldosa opaca del techo; las claraboyas de cristal y la franja
    z = -2 (llegada de la rampa) quedan libres. Cada panel tiene su `BoxShape3D` 2,7 × 1,1 × 1,35.
- Verificado con un `CharacterBody3D` real (`scenes/player.tscn`) moviéndose a 4 m/s: sube la rampa
  y cruza el techo a y = 4,01. `physics_test` y `asset_collision_test` en verde. `station_access_test`
  baja de 2 a 1 fallo (el techo pone el dintel que faltaba sobre la puerta sur del generador; queda el
  de `RoomHydroponics/Wall_South_2`, ya existente).
- Ojo: en los `.tscn` el `Transform3D(...)` no se puede transponer a mano; copiar el del nodo visual.

### Hito 22 — Sin plantas en el suelo y AutoDoor en la sala principal (2026-11-15)

- **Plantas retiradas**: se eliminaron las 23 instancias de `Plant_1.glb` (todas en el suelo, y = 0)
  y su `ext_resource` en `scenes/habitat_decor.tscn` (3) y en las salas que instancia:
  `IMG_sala_del_generador` (1), `IMG_vestibulo` (2), `IMG_sala_de_mando` (4), `room_quarters` (2),
  `room_oxigeno` (2), `room_briefing` (4), `room_medbay` (1), `room_hydroponics` (3).
  `corridor_module` no tenía. Ninguna tenía colisión propia.
- **Sala principal (`habitat_decor.tscn`)**: `Door_West`, `Door_North` y `Door_East` pasan de
  `scenes/DoorAnim.tscn` a `scenes/doors/auto_door.tscn` con la escala estándar 1,145 × 1,369 × 1 y la
  rotación de su panel `Wall_With_Door_Grey`. `DoorAnim.tscn` ya no se usa en ninguna escena.
- `tests/asset_collision_test.gd`: las mallas bajo `Walls/Door_*` comparten grupo con el panel de la
  puerta (el solape puerta/hueco y marco/hoja es intencionado).
- Tests: `doors_test`, `physics_test`, `functional_test`, `interaction_test` y `asset_collision_test` en
  verde; `station_access_test` mantiene solo el fallo previo de `RoomHydroponics/Wall_South_2`.

### Hito 23 — Minijuego de oxígeno por presión sostenida y colisión en los adornos (2026-11-15)

- **Minijuego de oxígeno rehecho** (`scripts/minigame_oxygen.gd`, `scenes/ui/minigame_oxygen.tscn`):
  mantener ESPACIO/ENTER o el botón (`button_down`/`button_up`) sube la presión a `pump_rate`
  (0,55/s); siempre se escapa a `leak_rate` (0,22/s); cada pulsación da un toque de `pump_per_press`.
  La zona verde (ancho 0,14, centro aleatorio entre 0,6 y 0,8) hay que mantenerla `hold_required`
  = 2,5 s; fuera de ella la estabilidad baja ×1,5. Llegar al 100 % abre la válvula: presión a 0,3 y
  −2 s. La barra de la fila (antes «PRESIÓN») se llama «ESTABLE» y muestra `hold_time/hold_required`;
  el `RepairGauge` dibuja la presión como aguja. API para pruebas: `step(delta)`, `set_pumping()`,
  `set_pressure()`, `get_pressure()`, `get_target_center()`, `is_in_zone()`, `get_overpressures()`.
  `tests/minigame_test.gd` e `interaction_test.gd` actualizados (ya no existen `set_needle`/`get_hits`).
- **Colisión en todos los adornos**: cada escena (`habitat_decor` y las 9 salas que instancia, incluido
  `corridor_module`) tiene un `StaticBody3D` `PropsCollision` (capa 1) con una `BoxShape3D` por nodo
  de `Props`, ceñida a la AABB de su malla (132 cajas; las formas de igual tamaño se comparten).
  `ServiceStairs` se excluye: ya tiene su cuña. Generado midiendo las AABB en Godot; si se mueve un
  adorno hay que mover también su caja (mismo nombre en `PropsCollision`).
- `Display_Right` de la sala principal tapaba media puerta este (z 0,2–1,8): movida a z = 3.
- Tests en verde: functional, interaction, physics, doors, minigame, radiation, hydroponics,
  asset_collision y room_collision. `station_access_test`: solo el fallo previo de `RoomHydroponics`.

### Hito 24 — Domo de Meshy, energía solar, corto circuito y misión sin límite (2026-11-15)

- **Domo** (`scenes/station_dome.tscn` + `scripts/station_dome.gd`, instanciado en `habitat.tscn` en
  (0, 0, 37)): modelo de Meshy `ai_assets/models/domo/domo_estacion.glb` (generado con
  `tools/generar_domo_meshy.py saldo|generar`; costó ~30 de 100 créditos). Es un casquete esférico:
  el anillo del suelo mide el 82 % del ancho máximo y en +z tiene un arco que entra hasta el 72 %.
  Escala del nodo `Model`: 161 × 50 × 273 m → anillo del suelo de 132 × 224 m. Colisión: una
  `ConcavePolygonShape3D` (30 044 triángulos, `backface_collision`) creada en `_ready()` con los
  vértices YA escalados (Godot no admite escala no uniforme en formas cóncavas). Vidrio translúcido
  (copia del material de Meshy con alfa 0,16 y `CULL_DISABLED`); el brillo sigue al escudo.
  El modelo tiene huecos sin vidrio arriba (> 20 m, inalcanzables).
- **Plataforma**: el bloque base de `station_platform.tscn` pasa de 84 × 160 a 170 × 282 m (malla
  y colisión, mismo centro z = 37).
- **Energía**: `energy_decay_rate = 0` (sin descarga) y la emergencia `sobrecarga_energia` ya no se
  programa. Los paneles solares cargan `solar_charge_rate` = 0,3/s (0→100 en ~5,5 min). La energía
  está en `GameManager.NON_FATAL_RESOURCES`: llegar a 0 no hace perder la partida.
- **Corto circuito** (`GameManager.EMERGENCY_SHORT_CIRCUIT`, en la rotación de `EmergencySystem`):
  energía a 0, sin carga solar y oxígeno ×`short_circuit_oxygen_multiplier` (2) hasta repararlo.
  Señal `short_circuit_changed`. Se repara con el minijuego de cables: `RepairMinigameManager`
  llama a `repair_short_circuit()` antes de reponer la energía.
- **Consola de ENERGÍA** movida de `habitat.tscn` al interior del generador
  (`IMG_sala_del_generador/ConsoleEnergy`, `panel_visible = false`): se pulsa E junto a la máquina.
  Sustituye a la antigua consola invisible del escudo.
- **Consola del DOMO** (`scenes/dome_console.tscn`, hereda de `console.tscn`; `scripts/dome_console.gd`,
  `DomeConsole extends ResourceConsole`, recurso `shield`): en el sitio del antiguo escritorio
  decorativo de la sala del generador (6, 0, -6). `GameManager.divert_energy_to_dome()` pasa TODA
  la energía al escudo (× `dome_transfer_efficiency`); señal `energy_diverted_to_dome`. No hace nada
  sin energía, con corto circuito o con el escudo lleno.
- **Misión sin límite**: `MissionConfig.endless_mission = true`. No hay victoria por tiempo; el HUD
  muestra el tiempo aguantado. `mission_duration` (180 s) queda como ciclo del perfil de radiación
  de RadLab (`get_mission_progress()` usa `fposmod`).
- Tests: nuevo `tests/dome_energy_test.tscn` (30 comprobaciones, incluida una consulta física de las
  522 colisiones de la estación contra la cáscara del domo). `simulation_test` cambia la ruta de
  victoria por la de supervivencia. `asset_collision_test` ignora `StationDome`. Capturas en
  `docs/capturas/hito24_domo_*.png` (`tools/capturas/capturar_domo.tscn`).
- Fallos previos que siguen: `station_access_test` (dintel de `RoomHydroponics`) y `menu_test`
  (`CardButton`, por cambios sin commit en `scenes/main_menu.tscn` anteriores a este hito).

---
*Actualizado: 2026-11-15 — Hito 24 (domo, energía solar, corto circuito y misión sin límite) completado.*

### Hito 25 — Minimapa y HUD rediseñado (2026-11-15)
- `ai_assets/IMG/Map/minimapa_habitat.png`: minimapa cenital de `scenes/habitat_decor.tscn` (9 salas con nombre, pasillos sin nombre), generado por `tools/generate_minimap.py` a partir de las posiciones de la escena (14 px/m, origen de mundo (-44.7637, -44.6178)). El script puede además pedir texturas por sala a la API de Layer (clave en `API.txt`); aún no se ha podido ejecutar porque el proxy bloquea `api.app.layer.ai`.
- HUD (`scenes/hud.tscn`, `scripts/mission_hud.gd`): arriba a la izquierda solo OXÍGENO, ENERGÍA y ESCUDO como burbujas que se gastan (`scripts/resource_bubbles.gd`, clase `ResourceBubbles`) + porcentaje. AGUA y COMIDA bajan a la esquina inferior izquierda como texto "NOMBRE  NN%". La barra de ayuda pasa al centro inferior.
- Minimapa circular abajo a la izquierda (`scripts/hud_minimap.gd`, clase `HudMinimap`): el `Panel` Frame recorta con `clip_children`; la imagen se desplaza para que la posición real del jugador (grupo `player`) quede en el centro; norte arriba y flecha que gira con el jugador.
- Escala de la UI al 97 % (`MissionHud.UI_SCALE`), reajustada al cambiar el tamaño de la ventana.
- Si se mueve una sala en `habitat_decor.tscn`, hay que regenerar el minimapa (`python tools/generate_minimap.py . --no-api`) y, si cambia el origen, actualizar `map_origin` en `hud_minimap.gd`.


### Hito 26 — Domo con 3 niveles y aviso de corto circuito (2026-11-15)
- `GameManager.divert_energy_to_dome(fraction = 1.0)`: desvía solo una fracción de la energía actual.
- Consola del domo (`scripts/dome_console.gd`): al pulsar E abre `scenes/ui/dome_energy_panel.tscn` (`scripts/dome_energy_panel.gd`, clase `DomeEnergyPanel`) en la capa `RepairMinigames`, con 3 niveles: BAJO 25 %, MEDIO 50 %, MÁXIMO 100 % (`level_fractions`, editable). Se elige con el ratón o con 1/2/3; Esc cancela. Cada botón muestra la energía que se gasta y el escudo que se gana. `divert_level(n)` aplica un nivel sin panel (lo usa `tests/dome_energy_test.gd`, actualizado para los 3 niveles).
- Corto circuito: aviso fijo rojo parpadeante en el HUD (`%ShortCircuitBanner`) con la sala donde está la consola de energía (calculada con `HudMinimap.room_name_at`) y la sala en la que está el jugador; si ya ha llegado, se lo dice. El minimapa marca el destino con un punto parpadeante o una flecha roja en el borde (`HudMinimap.set_target/clear_target`). Todo desaparece al reparar.
- `HudMinimap.ROOMS` repite los centros de las salas de `habitat_decor.tscn`: si se mueve una sala, actualizar también esa tabla.

### Hito 27 — Juego en dos idiomas: español e inglés (2026-11-15)
- Autoload `Lang` (`scripts/localization.gd`): el español es el texto original y la CLAVE; el diccionario `EN` (≈320 textos) se registra como traducción "en" en el `TranslationServer`. El idioma se guarda en `user://settings.cfg`. `project.godot`: `internationalization/locale/fallback="es"` (si no, Godot caería al inglés). En modo headless (tests) siempre español.
- Menú principal: botón `LanguageButton` arriba a la derecha (muestra el OTRO idioma: "ENGLISH" / "ESPAÑOL"). Los botones del menú tienen el texto dibujado en la imagen: las versiones en inglés están en `ai_assets/ui/menu/en/` (mismo nombre de archivo) y `MainMenu._apply_language_textures()` las cambia.
- Los `Label`/`Button`/`Label3D` de las escenas se traducen solos. Los textos con formato usan `tr("...")` en los scripts (antes de aplicar `%`). Datos traducidos: eventos del Apolo 8 (`LaunchSimulation._translate_data`), cultivos (nombre y lugar), nombres de piezas del rover (`nombre_en`), salas del minimapa (imagen `ai_assets/IMG/Map/en/minimapa_habitat.png`).
- Sin traducir (contenido, no UI): texto de los libros de la Biblioteca, fichas de las piezas del rover (material, importancia, dato) y portadas.
- Para añadir un texto: escribirlo en español (escena o `tr()`) y añadir su traducción en `Lang.EN`.

### Hito 28 — Pausa en la Base Lunar (2026-11-15)
- `scenes/ui/pause_menu.tscn` + `scripts/pause_menu.gd` (clase `PauseMenu`), instanciado en `scenes/main.tscn` dentro de `PauseLayer` (CanvasLayer, capa 20, `process_mode` ALWAYS).
- Esc o P (acción nueva `pause_game`) pausan con `get_tree().paused = true`: se congelan GameManager (recursos, reloj, puntos), emergencias, jugador y cuenta atrás inicial (`create_timer(..., false)`). No se puede pausar con un minijuego/panel del domo abierto ni con la misión terminada.
- Botones: CONTINUAR, REINICIAR MISIÓN y VOLVER AL MENÚ PRINCIPAL. Al volver al menú se llama a `GameManager.abort_mission()` (nuevo) para que el autoload no siga consumiendo recursos; `_mission_run` invalida la cuenta atrás de una misión abandonada.

### Hito 29 — Tierra a escala real y Sol visible en el hábitat (2026-11-15)
- `scenes/habitat.tscn` / `SpaceBackdrop`: el planeta `Verdant_World` (140× de escala, ~36° del cielo) se sustituye por `Earth`, una esfera con `resources/shaders/tierra.gdshader` (océanos, continentes, nubes y brillo de atmósfera) de radio 46,4 m a 2 800 m: 1,9° de diámetro aparente, lo mismo que la Tierra vista desde la Luna. Inclinada 23,4°.
- Nuevo `Sun`: esfera emisiva (HDR, energía 12) de radio 14 m a 3 000 m (0,53°, como el Sol real) colocada en la dirección de la que viene `SunLight`, más un halo billboard aditivo (`resources/shaders/sol_halo.gdshader`, nodo `Sun/SunHalo`). El entorno activa `glow` (umbral HDR 1,3) para el resplandor.
- La cámara del jugador usa `far` por defecto (4 000 m): si se alejan la Tierra o el Sol hay que subirlo.

### Hito 30 — Biblioteca en inglés y Tierra más grande (2026-11-15)
- Biblioteca: con el juego en inglés, `Library.localize_catalog()` empareja por `id` el catálogo español con `resources/biblioteca/catalogo_en.json` y toma título, páginas, fuentes y portada. El `nivel` sigue en español (lo usa la estantería) y se muestra traducido (Básico → Beginner); el texto de la actividad ("Practicar: …") se traduce con `Lang`.
- `catalogo_en.json` y `libros/library_en.md`: se añadieron los 2 libros que faltaban en inglés (Your Body in Space, Space Weather); ahora están los 11. Su `portada` apunta a `ai_assets/ui/biblioteca/portadas/en/<id>.png`: portadas con el título en inglés (generadas a partir de las originales).
- Hábitat: la Tierra pasa de radio 46,4 m (1,9°, tamaño real) a 130 m (~5,3°) para verse mejor.

> Hitos que siguen: del parche de Alaitz (PArcheTutorial), integrados en el Hito 31.

*Actualizado: 2026-11-15 — Hito 25 (tutoriales paso a paso) completado.*

### Hito 31 — Fusión del parche de Alaitz (PArcheTutorial) (2026-11-15)
Se unió `PArcheTutorial/PARA_CESAR_NaSA-GAME` (+ `parche_tutoriales`, que ya estaba incluido) con fusión de 3 vías (`git merge-file`, base 51368ab o 66dd8a1 si el archivo no existía), conservando lo nuestro y añadiendo lo suyo:
- **Suyo, añadido**: tutoriales paso a paso (`GuideOverlay`, `scenes/ui/guide_overlay.tscn`, `tutorial.tscn`) en menú, Base Lunar, minijuegos, taller, despegue, biblioteca y carnet; sonido y música (autoload `Audio` = `scripts/audio_manager.gd`, `assets/audio/`); medallas y certificado (`PlayerProgress`, `MedalIcon`, `scenes/certificate.tscn`, "Mi carnet" vuelve al menú); minijuegos 3D (`OxygenStation3D`, `PowerPanel3D`, `HydroponicsGarden3D`, modelos en `ai_assets/models/minijuegos/`); selector 3D/2D del despegue; `locale/en.po` (669 textos) registrado en `[internationalization]`; imágenes `*_en.png`; `GameSettings` (`user://ajustes.cfg`).
- **Nuestro, conservado**: sistema de idioma `Lang` (+ `localization_api.gd` = clase `Localization` que delega en `Lang` para su código), HUD con burbujas/minimapa/agua y comida abajo, domo con 3 niveles, alerta de corto circuito, oxígeno por presión sostenida (ahora con el puesto 3D, sonidos y tutorial adaptado), sin plantas en el suelo, consolas de energía/domo en el generador, misión sin fin, Tierra y Sol.
- **Pausa unida**: autoload `Pause` (`scenes/ui/pause_menu.tscn`, `scripts/pause_menu.gd`): Esc o P en base, taller y despegue; Continuar, Cómo jugar, Reiniciar misión (solo base), idioma (vía `Lang`), volumen, Volver al menú (abandona la misión con `abort_mission`) y aviso de medalla. No se abre con minijuego/panel del domo abiertos, durante un tutorial ni con la misión terminada. Se quitó `PauseLayer` de `main.tscn`.
- **Ajustes de unión**: tutorial de la base reescrito para nuestro HUD (burbujas, minimapa, consola del domo) y para la misión sin fin; en misión sin fin la medalla de la base se da al fallar según el tiempo aguantado (`PlayerProgress.medal_for_survival`: 3/6/10 min); `game_manager.gd` une `RESOURCE_NAMES` (suyo) con corto circuito/domo/`abort_mission` (nuestros).
- Los `.uid` de scripts que ya existían se mantienen (los suyos traían otros); los nuevos traen los suyos. La carpeta `PArcheTutorial/` queda como referencia y se puede borrar.
- Pendiente: abrir en Godot 4.7.2 (que importe) y correr todas las pruebas de `tests/` (no se pudo ejecutar Godot desde la sesión).

### Hito 32 — Arreglo: biblioteca y minijuegos usaban scripts de PArcheTutorial (2026-11-15)
- Causa: la carpeta `PArcheTutorial/` está dentro del proyecto y sus `.gd` declaran los mismos `class_name` (`Library`, `OxygenRepairMinigame`, `CableRepairMinigame`, `HydroponicsMinigame`, `CardEditor`, `LaunchSimulation`, `RoverWorkshop`, `AnimatedDoor`). Godot registró esas clases apuntando a las copias del parche, así que la biblioteca y los minijuegos cargaban código que no corresponde a sus escenas y fallaban.
- Arreglo: `PArcheTutorial/.gdignore` (Godot ya no escanea esa carpeta) y se corrigieron las 8 rutas en `.godot/global_script_class_cache.cfg`. Además se quitó el UID inválido de `auto_door.tscn` en `IMG_sala_del_generador.tscn` (avisaba al cargar la base).
- Regla: no dejar copias de scripts del proyecto dentro de `res://` sin un `.gdignore` (o fuera del proyecto).

### Hito 33 — Colisiones y textura de la plataforma exterior (2026-11-15)
- `scenes/station_platform.tscn` (no existe una escena "Space_Station"; es la plataforma/cubo bajo la estación): cada uno de los 25 objetos (pasarelas, barandillas, módulos laterales, depósitos, cajas, camión, paneles solares, puesto, plataforma de aterrizaje, módulo de aterrizaje y luces) tiene ahora `Collision` (StaticBody3D, capa 1) con una caja del tamaño exacto de su malla, calculado leyendo el AABB de cada glTF/GLB (`~/gltf_aabb.py` en la sesión; misma lógica reutilizable).
- `resources/station_platform_material.tres`: el cubo usa la regolita lunar de `ai_assets/textures/moon_regolith.webp` + `moon_regolith_normal.webp` en triplanar con coordenadas de mundo (se repite cada ~8 m sin estirarse).

### Hito 34 — Más luces y pilas de carga en la plataforma exterior (2026-11-15)
- `scenes/station_platform.tscn` / `Exterior`: 14 luces nuevas (`lights.gltf`, escala 3): 2 más en las esquinas de la pista (`PadLight_Back_*`, ahora 4), 5 por el camino este (`PathLight_East_*`, x = 48, z 20–100), 5 por el oeste (`PathLight_West_*`, x = −48, z 30–110) y 2 en el patio de carga (`CargoLight_*`).
- 15 pilas de carga nuevas (`cargo_A_stacked.gltf`, escala 3): el patio sur pasa de 2×2 a 3×3 con 2 pilas encima (`CargoStack_4..8`, `CargoStack_Top_*`) y hay un patio nuevo junto a la pista (`CargoYard_*`, 3×2 + 2 encima).
- Todos con su `Collision` (misma caja que los existentes). Zonas elegidas fuera de salas, pasillos y del borde del domo.

### Hito 35 — Tierra y Sol mucho más grandes (2026-11-15)
- `scenes/habitat.tscn`: `Earth_mesh` radio 2000 m (altura 4000) y `Sun_mesh` radio 1500 m (altura 3000, más segmentos); el halo del Sol (`SunHalo_mesh`) pasa a 9000 × 9000 para seguir rodeándolo. Posiciones sin cambiar (Tierra a ~2 800 m, Sol a ~3 000 m).
- `scenes/player.tscn`: la cámara del jugador pasa a `far = 12000` (antes 4000 por defecto); si no, se recortaba la parte trasera de las esferas.
- Hito 35 (ajuste): Tierra radio 1000 m, Sol radio 650 m, halo 3900 × 3900.

### Hito 36 — Arreglo: el jugador caía fuera del escenario (2026-11-15)
- Causa: en `station_platform.tscn` la `LandingPad` se escaló ×9 en el editor y además su `Collision` (StaticBody3D) y su `Shape` tenían escala ×5 cada uno: la caja de colisión medía ~560 × 110 × 560 m y envolvía toda la estación, así que la física expulsaba al jugador.
- Arreglo: `Collision` y `Shape` de la pista vuelven a escala 1 (la caja ya crece con la escala de la pista). Regla: escalar el objeto, nunca su StaticBody3D/CollisionShape3D.

### Hito 37 — Botón «Mi carnet» de vuelta y tutoriales en todos los modos (2026-11-15)
- `scenes/main_menu.tscn`: se restaura `CardButton` (único `%CardButton`, 160,540 → 422,590, estilo del parche) y su conexión `pressed → _on_card_pressed` (abre `card_editor.tscn`). Sin él, el tutorial del menú fallaba al buscar `%CardButton`.
- `scripts/launch_simulation.gd`: el 2D y el 3D usan ids distintos (`despegue` / `despegue_3d`); antes, jugar uno marcaba el otro como visto.
- `scripts/dome_energy_panel.gd`: tutorial nuevo `consola_domo` (3 pasos) la primera vez que se abre la consola del domo; las teclas 1/2/3/Esc se ignoran mientras el tutorial está abierto. Textos en `locale/en.po`.
- Revisado: base (`base_lunar`), minijuegos, rover, despegue, biblioteca, carnet y menús ya muestran su tutorial la primera vez; todos los `%Nodo` de sus pasos existen en sus escenas.
