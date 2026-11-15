# Rover Perseverance — modelo 3D oficial dividido en piezas

## De dónde sale

- **Modelo original:** "Mars 2020 Perseverance Rover" de **NASA 3D Resources**
  (NASA/JPL-Caltech).
  https://github.com/nasa/NASA-3D-Resources/tree/master/3D%20Models/Mars%202020%20Perseverance%20Rover
- **Uso:** el material de la NASA en general no tiene derechos de autor. Se puede
  usar en proyectos educativos siempre que no se dé a entender que la NASA
  respalda el juego y que no se use su logo como marca propia. Dentro del juego se
  muestra el crédito "Modelo 3D: NASA/JPL-Caltech (NASA 3D Resources)".
- **No se inventó geometría.** No se usó IA generativa (Hunyuan3D, Meshy, etc.):
  todas las piezas son el modelo oficial, solo separado en partes.

## Qué se le hizo al modelo

1. Se descomprimió la geometría (el original usa compresión Draco, que **Godot no
   puede abrir**) con `gltf-transform`.
2. En Blender 5.3 se desplegó el mástil usando la **animación que trae el propio
   modelo** (el brazo queda guardado, como cuando el rover viaja).
3. Se agruparon todas las mallas del modelo en **16 piezas** con nombre propio y se
   separaron las ruedas y la suspensión en izquierda, derecha y centro (diferencial).
4. Se exportó a GLB sin Draco y con texturas JPEG, listo para Godot 4.7.2.

## Archivos

| Archivo | Qué es |
|---|---|
| `perseverance_ensamblado.glb` | El rover completo; cada pieza es un nodo con su nombre. El Taller del Rover separa las piezas en la mesa al empezar y usa estas posiciones como el lugar donde encaja cada una. |
| `piezas/*.glb` | Las 16 piezas sueltas, cada una centrada en su origen. |
| `iconos/*.png` | Imagen de cada pieza (render del modelo oficial) para las tarjetas. |
| `piezas_perseverance.json` | Fuente de verdad de los textos: nombre en español e inglés, descripción, dato real, relación con la misión, instrucción del procedimiento y orden de armado. |
| `perseverance_vista.png` | Render del rover completo. |

Los textos del juego se generan desde el JSON en `resources/rover_perseverance.tres`.

## Las 16 piezas (orden de armado)

1. Suspensión izquierda · 2. Suspensión derecha · 3. Diferencial ·
4. Ruedas izquierdas · 5. Ruedas derechas · 6. Cuerpo (con MOXIE dentro) ·
7. Sistema de muestras · 8. Radar RIMFAX · 9. Batería nuclear MMRTG ·
10. Antena de alta ganancia · 11. Antenas UHF y de baja ganancia ·
12. Mástil de sensores · 13. Cabeza (SuperCam y Mastcam-Z) · 14. Brazo robótico ·
15. Torreta (taladro, SHERLOC y WATSON) · 16. PIXL

## Fuentes de los datos

- NASA Science — Rover components: https://science.nasa.gov/mission/mars-2020-perseverance/rover-components/
- NASA — Ruedas y suspensión: https://mars.nasa.gov/mars2020/spacecraft/rover/wheels
- JPL — MOXIE completa su misión: https://www.jpl.nasa.gov/news/nasas-oxygen-generating-experiment-moxie-completes-mars-mission/
- Science News — Instrumentos de Perseverance: https://www.sciencenews.org/?p=3089471
- NASA Tech Briefs — PIXL, RIMFAX, SHERLOC, SuperCam, WATSON: https://www.techbriefs.com/component/content/article/tb/stories/blog/37042
- PDS Analyst's Notebook (Washington University) — Instrumentos Mars 2020: https://an.rsl.wustl.edu/help/Content/About%20the%20mission/M20/M20%20mission.htm
