@tool
class_name MedalIcon
extends Control

## Dibuja una medalla (cinta + disco con estrella) del color de su nivel:
## gris (sin medalla), bronce, plata u oro. Se usa en el carnet y en el certificado.

@export_range(0, 3) var medal: int = 0:
	set(value):
		medal = clampi(value, 0, 3)
		queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var color: Color = PlayerProgress.medal_color(medal)
	var radius: float = minf(w, h) * 0.34
	var center: Vector2 = Vector2(w * 0.5, h - radius - 2.0)
	# Cinta: dos franjas azul y roja que bajan hasta el disco.
	var ribbon_w: float = radius * 0.55
	var top: float = 0.0
	var ribbon_color_a: Color = Color(0.15, 0.3, 0.7) if medal > 0 else Color(0.22, 0.24, 0.3)
	var ribbon_color_b: Color = Color(0.8, 0.15, 0.15) if medal > 0 else Color(0.26, 0.28, 0.34)
	draw_colored_polygon(PackedVector2Array([Vector2(center.x - ribbon_w * 1.6, top), Vector2(center.x - ribbon_w * 0.2, top),
		Vector2(center.x + ribbon_w * 0.4, center.y - radius * 0.6), Vector2(center.x - ribbon_w * 0.4, center.y - radius * 0.4)]), ribbon_color_a)
	draw_colored_polygon(PackedVector2Array([Vector2(center.x + ribbon_w * 0.2, top), Vector2(center.x + ribbon_w * 1.6, top),
		Vector2(center.x + ribbon_w * 0.4, center.y - radius * 0.4), Vector2(center.x - ribbon_w * 0.4, center.y - radius * 0.6)]), ribbon_color_b)
	# Disco con borde y estrella.
	draw_circle(center, radius, color.darkened(0.35))
	draw_circle(center, radius * 0.86, color)
	draw_circle(center, radius * 0.66, color.lightened(0.12))
	var star: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var angle: float = -PI * 0.5 + i * PI / 5.0
		var r: float = radius * (0.52 if i % 2 == 0 else 0.22)
		star.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(star, color.darkened(0.3) if medal > 0 else color.lightened(0.15))
