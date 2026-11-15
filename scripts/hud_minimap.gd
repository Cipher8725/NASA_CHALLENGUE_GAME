class_name HudMinimap
extends Control

## Minimapa circular del HUD.
##
## Muestra la imagen cenital de `res://ai_assets/IMG/Map/minimapa_habitat.png`
## (generada a partir de `scenes/habitat_decor.tscn`) recortada en un círculo
## y desplazada para que la posición REAL del jugador quede siempre en el
## centro. El mapa no gira (norte arriba); la flecha del jugador sí gira con
## su orientación. Observa al jugador, nunca lo modifica.

## Imagen del minimapa.
@export var map_texture: Texture2D
## Coordenada de mundo (x, z) que corresponde al píxel (0, 0) de la imagen.
## Debe coincidir con `tools/generate_minimap.py` (min X/Z de las salas menos el margen).
@export var map_origin: Vector2 = Vector2(-44.7637, -44.6178)
## Píxeles de la imagen por metro de mundo (PPM de `generate_minimap.py`).
@export var pixels_per_meter: float = 14.0
## Escala de dibujo de la imagen dentro del círculo (0.55 ≈ 26 m de diámetro visible).
@export var zoom: float = 0.55
## Color de la flecha del jugador.
@export var player_color: Color = Color(1, 0.85, 0.3, 1)
## Color del marcador de destino (p. ej. el generador durante un corto).
@export var target_color: Color = Color(1, 0.3, 0.25, 1)

## Salas de `habitat_decor.tscn`: nombre y centro (x, z). Todas miden 20 × 20 m.
const ROOMS: Array[Dictionary] = [
	{"name": "MÓDULO CENTRAL", "center": Vector2(0.0, 0.0)},
	{"name": "CUARTOS", "center": Vector2(0.0166, 19.6345)},
	{"name": "SALA DE REUNIONES", "center": Vector2(0.0, 47.0)},
	{"name": "ENFERMERÍA", "center": Vector2(0.0, 74.4)},
	{"name": "HIDROPONÍA", "center": Vector2(0.0, 101.8)},
	{"name": "SALA DEL GENERADOR", "center": Vector2(-27.7637, 7.6104)},
	{"name": "SALA DE OXÍGENO", "center": Vector2(-27.58, -11.59)},
	{"name": "VESTÍBULO", "center": Vector2(27.4181, 0.1327)},
	{"name": "SALA DE MANDO", "center": Vector2(27.4449, -27.6178)},
]
## Medio lado de una sala (m).
const ROOM_HALF_SIZE: float = 10.0

@onready var _map_rect: TextureRect = %MapTexture
@onready var _overlay: Control = %MapOverlay

var _player: Node3D = null
var _has_target: bool = false
var _target: Vector3 = Vector3.ZERO
var _blink_time: float = 0.0

## Nombre de la sala que contiene un punto del mundo ("PASILLO" si ninguna).
static func room_name_at(world: Vector3) -> String:
	for room: Dictionary in ROOMS:
		var c: Vector2 = room["center"]
		if absf(world.x - c.x) <= ROOM_HALF_SIZE and absf(world.z - c.y) <= ROOM_HALF_SIZE:
			return String(room["name"])
	return "PASILLO"

## Marca un destino en el minimapa (punto parpadeante o flecha en el borde).
func set_target(world: Vector3) -> void:
	_target = world
	_has_target = true

## Quita el destino del minimapa.
func clear_target() -> void:
	_has_target = false

## Jugador que sigue el minimapa (null si no hay).
func get_player() -> Node3D:
	return _player

func _ready() -> void:
	if map_texture != null:
		_map_rect.texture = map_texture
		# En inglés se usa la imagen con los nombres de las salas en inglés
		# (misma carpeta, subcarpeta `en/`), si existe.
		if Lang.is_english():
			var english_path: String = map_texture.resource_path.get_base_dir().path_join("en").path_join(map_texture.resource_path.get_file())
			if ResourceLoader.exists(english_path):
				_map_rect.texture = load(english_path) as Texture2D
	_overlay.draw.connect(_draw_overlay)

func _process(delta: float) -> void:
	_blink_time += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null or _map_rect.texture == null:
		return
	# Posición del jugador en píxeles de la imagen (X → derecha, Z → abajo).
	var world: Vector3 = _player.global_position
	var px: Vector2 = (Vector2(world.x, world.z) - map_origin) * pixels_per_meter
	var tex_size: Vector2 = _map_rect.texture.get_size() * zoom
	_map_rect.size = tex_size
	# Desplaza la imagen para que el jugador quede en el centro del círculo.
	_map_rect.position = _map_rect.get_parent_control().size * 0.5 - px * zoom
	_overlay.queue_redraw()

## Dibuja el aro exterior, la marca del norte y la flecha del jugador.
func _draw_overlay() -> void:
	var s: Vector2 = _overlay.size
	var c: Vector2 = s * 0.5
	var radius: float = minf(s.x, s.y) * 0.5
	_overlay.draw_arc(c, radius - 2.0, 0.0, TAU, 64, Color(0.45, 0.72, 1, 0.9), 4.0, true)
	# Marca de norte (arriba).
	var n: Vector2 = c + Vector2(0, -radius + 12.0)
	_overlay.draw_colored_polygon(PackedVector2Array([n + Vector2(0, -7), n + Vector2(-6, 5), n + Vector2(6, 5)]), Color(1, 1, 1, 0.9))
	if _player == null:
		return
	if _has_target:
		_draw_target(c, radius)
	# Dirección hacia la que mira el jugador (-Z local) proyectada en el plano XZ.
	var fwd3: Vector3 = -_player.global_transform.basis.z
	var fwd: Vector2 = Vector2(fwd3.x, fwd3.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector2(0, -1)
	fwd = fwd.normalized()
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var tip: Vector2 = c + fwd * 13.0
	var left: Vector2 = c - fwd * 8.0 + side * 8.0
	var right: Vector2 = c - fwd * 8.0 - side * 8.0
	var back: Vector2 = c - fwd * 3.0
	var arrow: PackedVector2Array = PackedVector2Array([tip, left, back, right])
	_overlay.draw_colored_polygon(arrow, player_color)
	_overlay.draw_polyline(PackedVector2Array([tip, left, back, right, tip]), Color(0.05, 0.05, 0.1, 1), 2.0, true)

## Destino: punto parpadeante dentro del círculo o flecha en el borde.
func _draw_target(c: Vector2, radius: float) -> void:
	var offset: Vector2 = (Vector2(_target.x, _target.z) - Vector2(_player.global_position.x, _player.global_position.z)) * pixels_per_meter * zoom
	var pulse: float = 0.5 + 0.5 * sin(_blink_time * 6.0)
	var col: Color = target_color
	if offset.length() <= radius - 14.0:
		var p: Vector2 = c + offset
		_overlay.draw_circle(p, 6.0 + 6.0 * pulse, Color(col, 0.35))
		_overlay.draw_circle(p, 6.0, col)
		return
	# Fuera del círculo: triángulo en el borde que apunta hacia el destino.
	var dir: Vector2 = offset.normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = c + dir * (radius - 4.0)
	var base: Vector2 = c + dir * (radius - 22.0)
	col.a = lerpf(0.55, 1.0, pulse)
	_overlay.draw_colored_polygon(PackedVector2Array([tip, base + side * 10.0, base - side * 10.0]), col)
