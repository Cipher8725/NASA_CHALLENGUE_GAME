class_name CardBarcode
extends Control

## Dibuja un código de barras decorativo a partir del número del carnet.
## Mismo número → mismas barras, así cada carnet tiene su propio código.

@export var code: String = "":
	set(value):
		code = value
		queue_redraw()
@export var bar_color: Color = Color(0.06, 0.08, 0.12, 1)
## Ancho (en píxeles) de la barra más delgada.
@export var unit: float = 2.0

func _draw() -> void:
	if code.is_empty():
		return
	var bits: PackedInt32Array = PackedInt32Array()
	for ch: String in code:
		var value: int = ch.unicode_at(0)
		for i: int in 7:
			bits.append((value >> i) & 1)
	var x: float = 0.0
	var i: int = 0
	while x < size.x and i < bits.size() * 4:
		var bit: int = bits[i % bits.size()]
		var width: float = unit * (1.0 + float(bit) * 1.5)
		if i % 2 == 0:
			draw_rect(Rect2(x, 0.0, width, size.y), bar_color)
		x += width
		i += 1
