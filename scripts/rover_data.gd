class_name RoverData
extends Resource

## Configuración completa de un rover para el Taller del Rover.
##
## Guarda el modelo 3D, la lista de piezas y todos los números del minijuego,
## para no dejar valores sueltos dentro de los scripts (ver AGENTS.md).

## Nombre del rover que se muestra en pantalla.
@export var nombre: String = ""
## Línea corta debajo del nombre.
@export var subtitulo: String = ""
## Texto de crédito que debe verse en pantalla (origen del modelo 3D).
@export var credito: String = ""
## Modelo ensamblado: cada pieza es un nodo hijo con el nombre de `RoverPieceData.node_name`.
@export var modelo: PackedScene
## Piezas del rover. El orden de armado lo define `RoverPieceData.orden`.
@export var piezas: Array[RoverPieceData] = []

@export_group("Mesa de trabajo")
## Radio (en metros) del arco donde se reparten las piezas sueltas alrededor del rover.
@export var radio_mesa: float = 4.2
## Ángulo total (en grados) del arco de la mesa, centrado frente a la cámara.
@export var angulo_mesa: float = 200.0
## Altura (en metros) a la que se levanta una pieza mientras se arrastra.
@export var altura_arrastre: float = 0.5
## Distancia (en metros) a su lugar para que una pieza encaje al soltarla.
@export var distancia_encaje: float = 0.9
## Segundos que tarda una pieza en moverse sola (encajar o volver a la mesa).
@export var duracion_movimiento: float = 0.35
## Color de la silueta que muestra dónde va la siguiente pieza (modo guiado).
@export var color_silueta: Color = Color(0.3, 0.85, 1.0, 0.35)

@export_group("Estrellas")
## Errores máximos para ganar 3 estrellas.
@export var errores_para_3_estrellas: int = 0
## Errores máximos para ganar 2 estrellas (con más errores se gana 1).
@export var errores_para_2_estrellas: int = 2

## Devuelve las piezas ordenadas según su orden de armado.
func get_piezas_en_orden() -> Array[RoverPieceData]:
	var ordenadas: Array[RoverPieceData] = piezas.duplicate()
	ordenadas.sort_custom(func(a: RoverPieceData, b: RoverPieceData) -> bool: return a.orden < b.orden)
	return ordenadas
