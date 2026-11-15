class_name RoverPieceData
extends Resource

## Datos de una pieza del rover para el Taller del Rover.
##
## Cada pieza corresponde a un nodo del modelo 3D ensamblado
## (`res://ai_assets/models/perseverance/perseverance_ensamblado.glb`).
## Los textos están pensados para niños de 7 a 12 años y salen de fuentes
## públicas de la NASA (ver `ai_assets/models/perseverance/CREDITOS.md`).

## Identificador estable de la pieza (también es el nombre del archivo .glb suelto).
@export var id: StringName = &""
## Nombre del nodo dentro del modelo ensamblado.
@export var node_name: String = ""
## Nombre en español que ve el jugador.
@export var nombre: String = ""
## Nombre en inglés, como aparece en los documentos de la NASA.
@export var nombre_en: String = ""
## Para qué sirve la pieza, en una o dos frases.
@export_multiline var descripcion: String = ""
## De qué está hecha la pieza (material real, con fuente en piezas_perseverance.json).
@export_multiline var material: String = ""
## Por qué la pieza es importante para el rover.
@export_multiline var importancia: String = ""
## Un dato real y curioso para la tarjeta informativa.
@export_multiline var dato: String = ""
## Cómo se relaciona la pieza con los recursos de la base (energía, oxígeno, comunicación…).
@export_multiline var conexion_mision: String = ""
## Paso del procedimiento de armado, escrito como una instrucción corta.
@export_multiline var instruccion: String = ""
## Posición en el orden de armado: 1 se coloca primero.
@export var orden: int = 0
## Imagen de la pieza sola (render del modelo oficial).
@export var icono: Texture2D
