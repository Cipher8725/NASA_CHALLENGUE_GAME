# NaSA-GAME — «Mataron a Houston: Atte.: NASA» (Niños Astronautas Sin Autorización)

Juego 3D en Godot 4.7.2 para el desafío **Build a Junior Astronaut Mission Trainer** del
NASA Space Apps Challenge 2026. Entrena a jóvenes de 9 a 15 años en las tareas de una misión:
sobrevivir en una base lunar administrando recursos, armar el rover Perseverance, despegar en el
Apolo 8 y estudiar en una biblioteca con fuentes de la NASA.

## Cómo ejecutarlo

0. **Packs de modelos de terceros (obligatorio).** Por sus licencias, estos packs no se suben al
   repositorio y deben copiarse en `assets/` antes de abrir el proyecto (ver `ai_assets/LICENSES.md`):
   `Molten Maps SciFi Asset Pack` (Moltenbolt, CC0), `KayKit_Space_Base_Bits_1.0_FREE`
   (Kay Lousberg, CC0) y `Planets_Asteroids_FREE_SAMPLE`. Comprueba con `bash tools/check_assets.sh`.
1. Abre el proyecto con **Godot 4.7.2** (`project.godot`).
2. Ejecuta la escena principal (`scenes/main_menu.tscn`).
3. Pruebas automáticas: `godot --headless --path . res://tests/<nombre>_test.tscn`.

## Jugar sin Godot / Play without Godot

Descarga `NaSA-GAME_Windows.zip`, descomprímelo y abre `NaSA-GAME.exe` (Windows 10/11, 64 bits).
/ Download `NaSA-GAME_Windows.zip`, unzip it and run `NaSA-GAME.exe` (Windows 10/11, 64-bit).

## Novedades para el jugador

- **Tutoriales paso a paso** en cada parte (menú, Base Lunar, cada minijuego, taller del rover, despegue,
  biblioteca y carnet): iluminan lo que explican y tienen «Siguiente» y «Saltar tutorial».
- **ESC = pausa**: continuar, cómo jugar, idioma, volumen de música y efectos, volver al menú.
- **Sonido y música** propios en todo el juego.
- **Medallas** (bronce, plata, oro) en Base Lunar, Taller del Rover, Despegue y Biblioteca, visibles en
  «Mi carnet», y **Certificado de Astronauta Junior** al completar Base, Rover y Despegue (se puede guardar
  como imagen).

## Idioma / Language

El juego está en **español e inglés**. En el menú principal, el botón de arriba a la derecha cambia el
idioma (se guarda para la próxima vez). / The game is in **Spanish and English**: use the button at the
top right of the main menu to switch (the choice is saved).

## Módulos

| Módulo | Escena |
|---|---|
| Base lunar (oxígeno, energía, agua, escudo y comida) | `scenes/main.tscn` |
| Armado del rover Perseverance | `scenes/rover_workshop.tscn` |
| Despegue del Apolo 8 en 3D | `scenes/simulacion_despegue_3d.tscn` |
| Biblioteca (11 libros) | `scenes/biblioteca.tscn` |
| Carnet de astronauta | `scenes/card_editor.tscn` |

## Datos de la NASA usados

Ningún dato se inventa: cada uno está en un archivo con su fuente y su fecha de descarga. Lo que es
regla de juego está marcado como «aproximado (juego)» dentro del archivo.

| Recurso | Qué dato usamos | Dónde aparece en el juego | Archivo |
|---|---|---|---|
| RadLab (NASA OSDR) | Dosis de radiación medida en la ISS por DosTel, 24 h del 1/4/2022 (≈250–290 µGy/día, picos de ~700 µGy/h) | El escudo de la Base lunar se gasta según el perfil real de ese día; aviso de radiación alta; dato al final de la misión; libro «El clima del espacio» | `resources/radiacion/radlab_iss.json` |
| DONKI (NASA CCMC, vía NASA Open APIs) | 22 erupciones solares reales clase M y X (nov. 2025 – mar. 2026) con fecha, clase, región e ID | Emergencia «tormenta solar» de la Base lunar; libro «El clima del espacio» | `resources/radiacion/donki_eventos.json` |
| NASA OSDR: OSD-745 | Lechuga roja cultivada en el huerto Veggie de la ISS, cosecha a los 33 días, comida segura | Minijuego del huerto (comida); libro «Tu cuerpo en el espacio» | `resources/hidroponia/cultivos.json` |
| NASA OSDR: OSD-780 y OSD-655 | Mizuna cultivada en la ISS (2019): luz 90:10 y 50:50, cosecha a los 35 días, error real de fertilizante | Minijuego del huerto (luz roja o azul, +15 % energía con azul); libro «Tu cuerpo en el espacio» | `resources/hidroponia/cultivos.json` |
| Agencia Espacial Canadiense (CSA) | Producción de alimentos: menús de 1900–3200 calorías, Tomatosphere | Datos del huerto; libro «Tu cuerpo en el espacio» | `resources/hidroponia/cultivos.json` |
| NASA SP-4029 / Apollo 8 Mission Report | Tiempos, alturas y velocidades del ascenso del Apolo 8 | Simulación de despegue | `resources/apolo8/ascenso.json` |
| NASA 3D Resources | Modelos del Perseverance y del Saturno V | Taller del rover y despegue | `ai_assets/models/` |
| science.nasa.gov / jpl.nasa.gov | Materiales y función de las 16 piezas del Perseverance; récord de 45,22 km (11/10/2026) | Fichas y título del taller | `ai_assets/models/perseverance/piezas_perseverance.json` |
| NASA Image and Video Library (NASA Open APIs) | 6 fotos reales de Mastcam-Z del Perseverance con fecha, sol y crédito | Foto que aparece al terminar de armar el rover | `ai_assets/perseverance_fotos/fotos.json` |

Recursos del desafío que **no** se usan: Mars Trek (la base está en la Luna, no en Marte).

## Valores de juego (simplificaciones declaradas)

- La misión de la Base lunar dura 180 s; las velocidades de consumo de oxígeno, energía, agua y comida
  (`resources/default_mission.tres`) son de juego, no tasas reales de una tripulación.
- El escudo usa el perfil real de RadLab comprimido: 180 s de juego = 24 h medidas en la ISS.
- El daño de cada tormenta solar según su clase y el agua o energía que gasta el huerto son reglas de juego
  (marcadas como «aproximado» en sus JSON).
- En el huerto, 1 día real de cultivo = 0,5 s de juego.
- Los números de los paneles de la cabina 3D del Apolo 8 son decorativos.
