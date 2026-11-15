@tool
class_name SlidingDoor
extends Node3D

## Puerta corrediza de la base: la hoja sube y se esconde en el marco.
##
## Dos usos, según `required_access_level`:
##  * 0 → PUERTA AUTOMÁTICA: se abre sola cuando el jugador entra en `%DetectArea`
##    y se cierra cuando sale.
##  * 1 o más → PUERTA RESTRINGIDA: no se abre sola. El jugador se acerca al
##    lector (`%ReaderArea`) y pulsa la tecla de interactuar (E) para pasar su
##    carnet. Si su nivel de acceso alcanza, se abre; si no, muestra el motivo.
##
## TAMAÑO AJUSTABLE (como escalar en Blender): cambia `door_width`, `door_height`
## y `door_depth` en el Inspector y el modelo, las colisiones, el sensor, el
## letrero y el lector se acomodan solos, también en el editor.
## Si el techo es bajo, usa `slide_direction` = IZQUIERDA o DERECHA para que la
## hoja se esconda de lado en vez de subir.
##
## Las colisiones del marco y de la hoja están en la escena (.tscn); el script
## ajusta su tamaño y desactiva la colisión de la hoja mientras está abierta.

signal opened
signal closed
signal access_granted(card: AstronautCard)
signal access_denied(reason: String)

enum Slide { UP, LEFT, RIGHT }

## Medidas del modelo original (metros). Sirven de base para escalar.
const BASE_SIZE: Vector3 = Vector3(1.7, 2.2, 0.3)
const BASE_POST_X: float = 0.735
const BASE_POST_WIDTH: float = 0.23
const BASE_TOP_Y: float = 2.075
const BASE_TOP_HEIGHT: float = 0.25
const BASE_LEAF: Vector3 = Vector3(1.26, 1.96, 0.1)
const BASE_LEAF_CENTER: Vector3 = Vector3(0.0, 0.98, -0.05)
## Distancia que recorre la hoja hacia un lado, en unidades del modelo original.
const BASE_SIDE_TRAVEL: float = 1.3
const MIN_SIZE: float = 0.3

@export_group("Tamaño (ajustable)")
## Ancho total del marco (metros). Original: 1,7 m.
@export_range(0.6, 6.0, 0.05, "suffix:m") var door_width: float = 1.7:
	set(value):
		door_width = maxf(value, MIN_SIZE)
		_apply_size()
## Alto total del marco (metros). Original: 2,2 m.
@export_range(1.0, 6.0, 0.05, "suffix:m") var door_height: float = 2.2:
	set(value):
		door_height = maxf(value, MIN_SIZE)
		_apply_size()
## Grosor del marco (metros). Original: 0,3 m.
@export_range(0.05, 1.5, 0.01, "suffix:m") var door_depth: float = 0.3:
	set(value):
		door_depth = maxf(value, 0.05)
		_apply_size()
## Hacia dónde se esconde la hoja: ARRIBA (necesita techo alto) o a un LADO (techo bajo).
@export var slide_direction: Slide = Slide.UP
## Si está activo, la hoja sube exactamente su propia altura y se ignora `open_height`.
@export var auto_open_height: bool = true
@export_group("")

## 0 = automática. 1 o más = nivel de carnet necesario para abrir.
@export var required_access_level: int = 0
## Cuánto sube la hoja al abrirse (metros).
@export var open_height: float = 1.9
## Segundos que tarda en abrirse o cerrarse.
@export var move_time: float = 0.8
## Segundos que espera abierta después de que el jugador se aleja.
@export var close_delay: float = 1.0
## Nombre del nodo de la hoja dentro del modelo 3D.
@export var leaf_node_name: String = "HojaPuerta"
## Ruta del carnet a revisar (se puede cambiar en las pruebas).
@export var card_path: String = AstronautCard.SAVE_PATH

var _leaf: Node3D
var _leaf_closed_pos: Vector3 = Vector3.ZERO
var _is_open: bool = false
var _bodies_near: int = 0
var _player_at_reader: bool = false
var _granted: bool = false
var _tween: Tween
var _close_timer: SceneTreeTimer

@onready var _model: Node3D = %Model
@onready var _detect_area: Area3D = %DetectArea
@onready var _leaf_collision: CollisionShape3D = %LeafCollision
@onready var _status: Label3D = get_node_or_null("%StatusLabel") as Label3D
@onready var _reader_area: Area3D = get_node_or_null("%ReaderArea") as Area3D

func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	_leaf = _model.find_child(leaf_node_name, true, false) as Node3D
	if _leaf == null:
		push_warning("SlidingDoor: no se encontró la hoja '%s' en el modelo." % leaf_node_name)
	else:
		_leaf_closed_pos = _leaf.position
	_detect_area.body_entered.connect(_on_detect_body_entered)
	_detect_area.body_exited.connect(_on_detect_body_exited)
	if _reader_area:
		_reader_area.body_entered.connect(_on_reader_body_entered)
		_reader_area.body_exited.connect(_on_reader_body_exited)
	_show_status(_idle_text())

# --- API pública ---

func is_open() -> bool:
	return _is_open

func is_restricted() -> bool:
	return required_access_level > 0

## Escala del modelo respecto a su tamaño original.
func get_size_scale() -> Vector3:
	return Vector3(door_width / BASE_SIZE.x, door_height / BASE_SIZE.y, door_depth / BASE_SIZE.z)

## Espacio libre que necesita la hoja para esconderse (metros).
## ARRIBA: altura libre sobre el marco. LADO: ancho libre junto al marco.
func get_required_clearance() -> float:
	var k: Vector3 = get_size_scale()
	if slide_direction == Slide.UP:
		return _up_travel_local() * k.y
	return BASE_SIDE_TRAVEL * k.x

## Cambia el tamaño desde código (por ejemplo, para encajar en un hueco de pared).
func set_door_size(width: float, height: float, depth: float = door_depth) -> void:
	door_width = width
	door_height = height
	door_depth = depth

## Intenta abrir con un carnet. Devuelve true si se concedió el acceso.
func try_card(card: AstronautCard) -> bool:
	if not is_restricted():
		open_door()
		return true
	if card == null:
		_deny(tr("SIN CARNET\nCrea tu carnet en el menú"))
		return false
	if not card.can_open(required_access_level):
		_deny(tr("ACCESO DENEGADO\nSe necesita nivel %d (%s)") % [required_access_level, tr(AstronautCard.RANKS[mini(required_access_level, AstronautCard.RANKS.size() - 1)])])
		return false
	_granted = true
	_show_status(tr("ACCESO CONCEDIDO\n%s · Nivel %d") % [card.nombre, card.nivel_acceso])
	access_granted.emit(card)
	open_door()
	return true

func open_door() -> void:
	if _is_open:
		return
	_is_open = true
	_leaf_collision.set_deferred("disabled", true)
	_animate_leaf(_leaf_closed_pos + _open_offset_local())
	opened.emit()

func close_door() -> void:
	if not _is_open:
		return
	_is_open = false
	_granted = false
	_leaf_collision.set_deferred("disabled", false)
	_animate_leaf(_leaf_closed_pos)
	_show_status(_idle_text())
	closed.emit()

# --- Detección del jugador ---

func _on_detect_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_bodies_near += 1
	if not is_restricted():
		open_door()

func _on_detect_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_bodies_near = maxi(_bodies_near - 1, 0)
	if _bodies_near == 0:
		_schedule_close()

func _on_reader_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_at_reader = true
		if not _is_open:
			_show_status(tr("ZONA RESTRINGIDA\nPulsa E para pasar tu carnet"))

func _on_reader_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_at_reader = false
		if not _is_open:
			_show_status(_idle_text())

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if is_restricted() and _player_at_reader and not _is_open and event.is_action_pressed("interact"):
		try_card(AstronautCard.load_saved(card_path))

# --- Ayudas ---

func _schedule_close() -> void:
	if close_delay <= 0.0 or not is_inside_tree():
		close_door()
		return
	_close_timer = get_tree().create_timer(close_delay)
	_close_timer.timeout.connect(func() -> void:
		if _bodies_near == 0:
			close_door())

func _animate_leaf(target: Vector3) -> void:
	if _leaf == null:
		return
	if _tween:
		_tween.kill()
	if move_time <= 0.0 or not is_inside_tree():
		_leaf.position = target
		return
	_tween = create_tween()
	_tween.tween_property(_leaf, "position", target, move_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Recorrido de la hoja en unidades del modelo original (antes de escalar).
func _up_travel_local() -> float:
	if auto_open_height:
		return BASE_LEAF.y - 0.02
	return open_height / maxf(get_size_scale().y, 0.001)

func _open_offset_local() -> Vector3:
	match slide_direction:
		Slide.LEFT:
			return Vector3(-BASE_SIDE_TRAVEL, 0.0, 0.0)
		Slide.RIGHT:
			return Vector3(BASE_SIDE_TRAVEL, 0.0, 0.0)
	return Vector3(0.0, _up_travel_local(), 0.0)

## Ajusta modelo, colisiones, áreas, letrero y lector al tamaño elegido.
func _apply_size() -> void:
	if not is_inside_tree() and not is_node_ready():
		return
	var k: Vector3 = get_size_scale()
	var model: Node3D = get_node_or_null("Model") as Node3D
	if model:
		model.scale = k
	_fit_box("FrameBody/LeftPost", Vector3(-BASE_POST_X * k.x, BASE_SIZE.y * 0.5 * k.y, 0.0), Vector3(BASE_POST_WIDTH * k.x, door_height, door_depth))
	_fit_box("FrameBody/RightPost", Vector3(BASE_POST_X * k.x, BASE_SIZE.y * 0.5 * k.y, 0.0), Vector3(BASE_POST_WIDTH * k.x, door_height, door_depth))
	_fit_box("FrameBody/Top", Vector3(0.0, BASE_TOP_Y * k.y, 0.0), Vector3(door_width, BASE_TOP_HEIGHT * k.y, door_depth))
	_fit_box("LeafBody/LeafCollision", BASE_LEAF_CENTER * k, BASE_LEAF * k)
	var detect_size: Vector3 = Vector3(maxf(3.0, door_width + 1.3), door_height + 0.2, maxf(4.0, door_depth + 3.7))
	_fit_box("DetectArea/DetectShape", Vector3(0.0, detect_size.y * 0.5, 0.0), detect_size)
	var label: Node3D = get_node_or_null("StatusLabel") as Node3D
	if label:
		label.position = Vector3(0.0, door_height + 0.75, door_depth * 0.5 + 0.1)
	var reader_x: float = door_width * 0.5 + 0.3
	var reader: Node3D = get_node_or_null("CardReader") as Node3D
	if reader:
		reader.position = Vector3(reader_x, 1.0, door_depth * 0.5 + 0.05)
	_fit_box("ReaderArea/ReaderShape", Vector3(reader_x, 1.1, door_depth * 0.5 + 0.85), Vector3(1.6, 2.2, 1.8))
	if _leaf and not _is_open:
		_leaf.position = _leaf_closed_pos

func _fit_box(path: String, center: Vector3, size: Vector3) -> void:
	var col: CollisionShape3D = get_node_or_null(path) as CollisionShape3D
	if col == null:
		return
	var box: BoxShape3D = col.shape as BoxShape3D
	if box == null:
		return
	if not box.resource_local_to_scene:
		box = box.duplicate() as BoxShape3D
		box.resource_local_to_scene = true
		col.shape = box
	box.size = size
	col.position = center

func _deny(reason: String) -> void:
	_show_status(reason)
	access_denied.emit(reason)

func _idle_text() -> String:
	if is_restricted():
		return tr("ZONA RESTRINGIDA\nNivel %d · Usa el lector") % required_access_level
	return ""

func _show_status(text: String) -> void:
	if _status:
		_status.text = text
