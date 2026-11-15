class_name ResourceBubbles
extends Control

## Indicador de recurso en forma de fila de burbujas.
##
## Cada burbuja vale `100 / bubble_count` % del recurso. Las burbujas llenas
## se dibujan enteras; la que se está gastando se encoge y se aclara, y las
## vacías quedan solo como contorno. Así el niño ve el recurso "irse
## gastando" burbuja a burbuja en vez de leer una barra.

## Número de burbujas de la fila.
@export var bubble_count: int = 10
## Color de relleno de las burbujas (el color del recurso).
@export var bubble_color: Color = Color(0.31, 0.76, 0.97, 1)
## Separación horizontal entre burbujas (píxeles).
@export var spacing: float = 5.0

## Fracción del recurso que queda (0..1).
var _ratio: float = 1.0

## Actualiza el valor mostrado y redibuja.
func set_values(current: float, maximum: float) -> void:
	var new_ratio: float = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	if is_equal_approx(new_ratio, _ratio):
		return
	_ratio = new_ratio
	queue_redraw()

func _draw() -> void:
	if bubble_count <= 0:
		return
	# El diámetro sale del ancho disponible y nunca supera el alto del control.
	var diameter: float = minf((size.x - spacing * float(bubble_count - 1)) / float(bubble_count), size.y)
	var radius: float = diameter * 0.5
	var cy: float = size.y * 0.5
	var filled: float = _ratio * float(bubble_count)
	for i: int in bubble_count:
		var center: Vector2 = Vector2(radius + float(i) * (diameter + spacing), cy)
		# Cuánto queda de esta burbuja concreta (0 = vacía, 1 = llena).
		var fill: float = clampf(filled - float(i), 0.0, 1.0)
		# Hueco de fondo y contorno, siempre visibles.
		draw_circle(center, radius, Color(0.02, 0.03, 0.06, 0.75))
		draw_arc(center, radius - 1.0, 0.0, TAU, 24, Color(bubble_color, 0.55), 2.0, true)
		if fill <= 0.0:
			continue
		# La burbuja se encoge por área (sqrt) para que el gasto se vea lineal.
		var r: float = (radius - 3.0) * sqrt(fill)
		var col: Color = bubble_color
		col.a = lerpf(0.55, 1.0, fill)
		draw_circle(center, r, col)
		# Brillo pequeño arriba a la izquierda: aspecto de burbuja.
		draw_circle(center + Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.45 * fill))
