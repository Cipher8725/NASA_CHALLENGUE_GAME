class_name GuideOverlay
extends CanvasLayer

## Tutorial paso a paso que señala partes de la pantalla.
##
## Cada parte del juego (menú, Base Lunar, minijuegos, taller del rover, despegue,
## biblioteca y carnet) lo usa la primera vez que se entra: oscurece la pantalla,
## deja iluminado lo que explica (un botón, una barra o una consola 3D) y muestra una
## tarjeta con "Atrás", "Siguiente" y "Saltar tutorial".
##
## - Cada tutorial tiene un id y se marca como visto en `user://ajustes.cfg` [tutoriales].
## - Con `pause_game` el juego queda en pausa mientras se lee (este nodo sigue procesando).
## - La pausa (ESC → "Cómo jugar") lo vuelve a mostrar con `force = true`.
##
## Un paso es un Dictionary: {"title": String, "text": String (BBCode), "target": opcional}.
## El target puede ser un Control, un Node3D (se proyecta con la cámara activa), un Rect2
## en píxeles de pantalla o un Callable que devuelva cualquiera de esos.

signal finished(skipped: bool)

const SCENE: String = "res://scenes/ui/guide_overlay.tscn"
const SETTINGS_SECTION: String = "tutoriales"
const GROUP: String = "guide_overlay"
## Margen alrededor de lo que se ilumina y tamaño del recuadro de un objeto 3D.
const HOLE_MARGIN: float = 8.0
const NODE3D_BOX: Vector2 = Vector2(150.0, 150.0)
const CARD_GAP: float = 16.0

var _id: String = ""
var _steps: Array[Dictionary] = []
var _index: int = 0
var _pause_game: bool = false
var _paused_before: bool = false
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _hole: Rect2 = Rect2()
var _pulse: float = 0.0

@onready var _shade: Control = %Shade
@onready var _card: PanelContainer = %Card
@onready var _counter: Label = %CounterLabel
@onready var _title: Label = %GuideTitle
@onready var _body: RichTextLabel = %GuideText
@onready var _back: Button = %GuideBack
@onready var _next: Button = %GuideNext
@onready var _skip: Button = %GuideSkip

# --- API estática ---

## Muestra un tutorial si aún no se vio (o siempre con `force`). Devuelve el tutorial o null.
static func start(host: Node, id: String, steps: Array[Dictionary], pause_game: bool = false, force: bool = false) -> GuideOverlay:
	if host == null or not host.is_inside_tree() or steps.is_empty():
		return null
	var tree: SceneTree = host.get_tree()
	if not force and was_seen(id):
		return null
	# En las escenas de prueba no aparecen solos (solo si la prueba los pide con force).
	if not force and tree.current_scene != null and tree.current_scene.scene_file_path.begins_with("res://tests/"):
		return null
	# No se apilan dos tutoriales: si ya hay uno, solo se fuerza el nuevo.
	var current: GuideOverlay = tree.get_first_node_in_group(GROUP) as GuideOverlay
	if current != null:
		if not force:
			return null
		current.close(true)
	var guide: GuideOverlay = (load(SCENE) as PackedScene).instantiate() as GuideOverlay
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(guide)
	guide.setup(id, steps, pause_game)
	return guide

static func was_seen(id: String) -> bool:
	return GameSettings.get_bool(SETTINGS_SECTION, id, false)

static func mark_seen(id: String) -> void:
	GameSettings.set_value(SETTINGS_SECTION, id, true)

## Vuelve a mostrar todos los tutoriales la próxima vez (lo usa el botón del menú y las pruebas).
static func reset_all() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(GameSettings.PATH) == OK and config.has_section(SETTINGS_SECTION):
		config.erase_section(SETTINGS_SECTION)
		config.save(GameSettings.PATH)

## ¿Hay un tutorial abierto ahora mismo?
static func is_active(tree: SceneTree) -> bool:
	return tree != null and tree.get_first_node_in_group(GROUP) != null

## Atajo para escribir un paso.
static func step(title: String, text: String, target: Variant = null) -> Dictionary:
	return {"title": title, "text": text, "target": target}

# --- Instancia ---

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	add_to_group(GROUP)
	_shade.draw.connect(_draw_shade)
	_back.pressed.connect(previous)
	_next.pressed.connect(next)
	_skip.pressed.connect(close.bind(true))
	get_viewport().size_changed.connect(_place)

func setup(id: String, steps: Array[Dictionary], pause_game: bool) -> void:
	_id = id
	_steps = steps
	_index = 0
	_pause_game = pause_game
	_paused_before = get_tree().paused
	_mouse_before = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _pause_game:
		get_tree().paused = true
	_show_step()

func next() -> void:
	if _index >= _steps.size() - 1:
		close(false)
		return
	_index += 1
	_show_step()

func previous() -> void:
	if _index > 0:
		_index -= 1
		_show_step()

## Termina el tutorial (saltado o completo): lo marca como visto y devuelve el juego como estaba.
func close(skipped: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	mark_seen(_id)
	remove_from_group(GROUP)
	if _pause_game:
		get_tree().paused = _paused_before
	Input.set_mouse_mode(_mouse_before)
	finished.emit(skipped)
	queue_free()

func get_step_index() -> int:
	return _index

func get_step_count() -> int:
	return _steps.size()

func get_id() -> String:
	return _id

## Rectángulo de pantalla iluminado en el paso actual (vacío si el paso no señala nada).
func get_highlight() -> Rect2:
	return _hole

func _process(delta: float) -> void:
	_pulse += delta
	# El objetivo puede moverse (cámara 3D, paneles que aparecen): se recalcula cada cuadro.
	var hole: Rect2 = _target_rect(_steps[_index].get("target", null)) if not _steps.is_empty() else Rect2()
	if hole != _hole:
		_hole = hole
		_place()
	_shade.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close(true)
		get_viewport().set_input_as_handled()

func _show_step() -> void:
	var data: Dictionary = _steps[_index]
	_counter.text = tr("TUTORIAL · %d / %d") % [_index + 1, _steps.size()]
	_title.text = str(data.get("title", ""))
	_body.text = str(data.get("text", ""))
	_back.visible = _index > 0
	_next.text = tr("¡Entendido!") if _index == _steps.size() - 1 else tr("Siguiente")
	_hole = _target_rect(data.get("target", null))
	_place()
	_next.grab_focus()
	AudioManager.sfx(&"ui_open", -8.0)

## Ubica la tarjeta junto a lo iluminado (debajo, arriba o a un lado) sin salirse de la
## pantalla. Si lo iluminado es muy grande, elige el lugar que menos lo tape.
func _place() -> void:
	if _card == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_card.reset_size()
	var size: Vector2 = _card.get_combined_minimum_size().max(Vector2(_card.custom_minimum_size.x, 0.0))
	var best: Vector2 = (screen - size) * 0.5
	if _hole.has_area():
		var cx: float = _hole.get_center().x - size.x * 0.5
		var cy: float = _hole.get_center().y - size.y * 0.5
		var margin: float = 8.0
		var candidates: Array[Vector2] = [
			Vector2(cx, _hole.end.y + CARD_GAP),
			Vector2(cx, _hole.position.y - CARD_GAP - size.y),
			Vector2(_hole.end.x + CARD_GAP, cy),
			Vector2(_hole.position.x - CARD_GAP - size.x, cy),
			Vector2((screen.x - size.x) * 0.5, screen.y - size.y - margin),
			Vector2((screen.x - size.x) * 0.5, margin),
			Vector2(margin, screen.y - size.y - margin),
			Vector2(screen.x - size.x - margin, screen.y - size.y - margin),
			Vector2(margin, margin),
			Vector2(screen.x - size.x - margin, margin),
		]
		var best_overlap: float = INF
		for candidate: Vector2 in candidates:
			var clamped: Vector2 = Vector2(
				clampf(candidate.x, margin, maxf(margin, screen.x - size.x - margin)),
				clampf(candidate.y, margin, maxf(margin, screen.y - size.y - margin)))
			var overlap: float = Rect2(clamped, size).intersection(_hole).get_area()
			if overlap < best_overlap - 1.0:
				best_overlap = overlap
				best = clamped
			if overlap <= 0.0:
				break
	best.x = clampf(best.x, 8.0, maxf(8.0, screen.x - size.x - 8.0))
	best.y = clampf(best.y, 8.0, maxf(8.0, screen.y - size.y - 8.0))
	_card.position = best
	_card.size = size

## Sombra con un hueco sobre lo que se explica y un borde dorado que late.
func _draw_shade() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var shade: Color = Color(0.0, 0.01, 0.04, 0.68)
	if not _hole.has_area():
		_shade.draw_rect(Rect2(Vector2.ZERO, screen), shade)
		return
	var h: Rect2 = _hole
	_shade.draw_rect(Rect2(0.0, 0.0, screen.x, h.position.y), shade)
	_shade.draw_rect(Rect2(0.0, h.end.y, screen.x, screen.y - h.end.y), shade)
	_shade.draw_rect(Rect2(0.0, h.position.y, h.position.x, h.size.y), shade)
	_shade.draw_rect(Rect2(h.end.x, h.position.y, screen.x - h.end.x, h.size.y), shade)
	var glow: float = 0.6 + 0.4 * sin(_pulse * 4.0)
	_shade.draw_rect(h.grow(2.0), Color(1.0, 0.82, 0.3, glow), false, 3.0)

func _target_rect(target: Variant) -> Rect2:
	var value: Variant = target
	if value is Callable:
		value = (value as Callable).call()
	if value == null:
		return Rect2()
	if value is Rect2:
		return (value as Rect2).grow(HOLE_MARGIN)
	if value is Control:
		var control: Control = value as Control
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			return Rect2()
		return control.get_global_rect().grow(HOLE_MARGIN)
	if value is Node3D:
		var node: Node3D = value as Node3D
		if not is_instance_valid(node) or not node.is_inside_tree():
			return Rect2()
		var camera: Camera3D = node.get_viewport().get_camera_3d()
		var point: Vector3 = node.global_position + Vector3(0.0, 0.9, 0.0)
		if camera == null or camera.is_position_behind(point):
			return Rect2()
		var center: Vector2 = camera.unproject_position(point)
		var screen: Rect2 = get_viewport().get_visible_rect()
		if not screen.has_point(center):
			return Rect2()
		return Rect2(center - NODE3D_BOX * 0.5, NODE3D_BOX)
	return Rect2()
