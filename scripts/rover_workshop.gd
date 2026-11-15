class_name RoverWorkshop
extends Node3D

## Taller del Rover: entrenamiento para armar el rover Perseverance desde cero.
##
## Las 16 piezas del modelo oficial de la NASA empiezan SEPARADAS sobre la mesa
## de trabajo, alrededor del lugar de armado. El jugador las arrastra con el
## ratón hasta su lugar siguiendo un procedimiento, como en un entrenamiento:
##
##  * ENTRENAMIENTO GUIADO: una silueta azul muestra dónde va la siguiente pieza
##    y la lista de procedimiento marca el paso actual. Sin límite de tiempo.
##  * EVALUACIÓN: sin silueta y con cronómetro. Al final se muestran el tiempo,
##    los errores y las estrellas.
##
## Reglas:
##  * Una pieza solo encaja si se suelta cerca de su lugar Y es la que toca
##    según el procedimiento. Si se suelta en su lugar fuera de orden, vuelve
##    a la mesa y cuenta como error.
##  * Soltar una pieza en cualquier otro lugar no es error: se queda ahí.
##  * Al hacer clic en una pieza se abre su tarjeta: para qué sirve, un dato
##    real y su relación con los recursos de la base.
##
## Todos los datos (modelo, piezas, textos y números) viven en `rover_data`.
## La interfaz solo refleja el estado; las reglas viven en este script.

## Emitida al terminar de armar el rover.
signal training_completed(stars: int, errors: int, seconds: float)
## Emitida cuando una pieza encaja en su lugar.
signal piece_installed(piece_id: StringName)
## Emitida cuando una pieza se suelta en su lugar pero fuera de orden.
signal wrong_order(piece_id: StringName, expected_id: StringName)

enum Mode { GUIDED, EVALUATION }
enum Phase { CHOOSING, ASSEMBLING, DONE }

## Escena a la que vuelve el botón "VOLVER AL MENÚ".
const MENU_SCENE: String = "res://scenes/main_menu.tscn"

## Rover que se arma en este taller.
@export var rover_data: RoverData
## Velocidad de giro de la cámara con el botón derecho (radianes por píxel).
@export var orbit_speed: float = 0.008
## Paso de zoom de la rueda del ratón (metros).
@export var zoom_step: float = 0.6
## Distancia mínima y máxima de la cámara al centro (metros).
@export var zoom_min: float = 4.0
@export var zoom_max: float = 16.0
## Píxeles que hay que mover el ratón para que un clic se convierta en arrastre.
@export var drag_threshold_px: float = 6.0
## Si es true, aprobar la EVALUACIÓN (estrellas >= `card_promotion_stars`) sube el
## carnet del jugador al nivel `card_promotion_level` (abre zonas restringidas).
@export var promote_card: bool = true
@export var card_promotion_stars: int = 2
@export var card_promotion_level: int = 2

var _mode: Mode = Mode.GUIDED
var _phase: Phase = Phase.CHOOSING
var _errors: int = 0
var _stars: int = 0
var _elapsed: float = 0.0
var _order: Array[RoverPieceData] = []
var _next_index: int = 0
## Por cada id: nodo 3D de la pieza.
var _nodes: Dictionary = {}
## Por cada id: posición armada (su lugar en el rover) y posición en la mesa.
var _home: Dictionary = {}
var _tray: Dictionary = {}
## Por cada id: true si la pieza ya está instalada.
var _installed: Dictionary = {}
## Por cada id: caja local y triángulos locales (para detectar clics sin colisiones).
var _local_boxes: Dictionary = {}
var _local_faces: Dictionary = {}
## Por cada id: silueta transparente que muestra dónde va la pieza (modo guiado).
var _ghosts: Dictionary = {}
## Por cada id: fila de la lista de procedimiento.
var _steps: Dictionary = {}

# Estado del arrastre en curso.
var _pressed_id: StringName = &""
var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_offset: Vector3 = Vector3.ZERO
var _drag_plane_y: float = 0.0
var _orbiting: bool = false

@onready var _model_root: Node3D = %ModelRoot
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera
@onready var _title: Label = %RoverTitle
@onready var _subtitle: Label = %RoverSubtitle
@onready var _phase_label: Label = %PhaseLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _hint_label: Label = %HintLabel
@onready var _steps_box: VBoxContainer = %StepsBox
@onready var _step_template: Label = %StepTemplate
@onready var _card: PanelContainer = %InfoCard
@onready var _card_icon: TextureRect = %PieceIcon
@onready var _card_name: Label = %PieceName
@onready var _card_name_en: Label = %PieceNameEn
@onready var _card_text: Label = %PieceText
@onready var _card_material: Label = %PieceMaterial
@onready var _card_why: Label = %PieceWhy
@onready var _card_fact: Label = %PieceFact
@onready var _card_link: Label = %PieceLink
@onready var _mode_panel: PanelContainer = %ModePanel
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _credit_label: Label = %CreditLabel
## Foto real de Marte tomada por Mastcam-Z que se muestra al terminar (ver fotos.json).
@onready var _mars_photo: TextureRect = %MarsPhoto
@onready var _mars_caption: Label = %MarsPhotoCaption

## Fotos reales del Perseverance (NASA Image and Video Library).
const PHOTOS_PATH: String = "res://ai_assets/perseverance_fotos/fotos.json"
var _photo_index: int = -1

func _ready() -> void:
	AudioManager.music(&"menu")
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_rover()
	_build_steps()
	_reset_state()
	show_guide.call_deferred(false)

func _process(delta: float) -> void:
	if _phase == Phase.ASSEMBLING and _mode == Mode.EVALUATION:
		_elapsed += delta
		_refresh_hud()

# --- API pública (la usan la interfaz y las pruebas) ---

func get_mode() -> Mode:
	return _mode

func get_phase() -> Phase:
	return _phase

func get_errors() -> int:
	return _errors

func get_stars() -> int:
	return _stars

func get_elapsed() -> float:
	return _elapsed

func get_piece_count() -> int:
	return _order.size()

func get_found_piece_count() -> int:
	return _nodes.size()

func is_piece_installed(piece_id: StringName) -> bool:
	return bool(_installed.get(piece_id, false))

func get_piece_position(piece_id: StringName) -> Vector3:
	return (_nodes[piece_id] as Node3D).position

func get_home_position(piece_id: StringName) -> Vector3:
	return _home[piece_id]

func get_tray_position(piece_id: StringName) -> Vector3:
	return _tray[piece_id]

## Pieza que toca instalar ahora (null si el entrenamiento no está en curso).
func get_next_piece() -> RoverPieceData:
	if _phase != Phase.ASSEMBLING or _next_index >= _order.size():
		return null
	return _order[_next_index]

func is_ghost_visible(piece_id: StringName) -> bool:
	return _ghosts.has(piece_id) and (_ghosts[piece_id] as Node3D).visible

## Empieza el entrenamiento en el modo indicado, con todas las piezas en la mesa.
func start_training(mode: Mode) -> void:
	_reset_state()
	_mode = mode
	_phase = Phase.ASSEMBLING
	_mode_panel.visible = false
	_hint_label.text = tr("Arrastra «%s» hasta su lugar en el rover.") % tr(_order[0].nombre)
	_update_ghost()
	show_assembly_guide.call_deferred(false)
	_refresh_hud()

## Suelta una pieza en una posición (local del modelo). Devuelve true si encajó.
## Es lo que pasa al terminar un arrastre; las pruebas también lo usan.
func drop_piece(piece_id: StringName, local_position: Vector3) -> bool:
	if _phase != Phase.ASSEMBLING or not _nodes.has(piece_id) or is_piece_installed(piece_id):
		return false
	var home: Vector3 = _home[piece_id]
	if local_position.distance_to(home) > rover_data.distancia_encaje:
		# Soltada lejos de su lugar: se queda ahí, sin error.
		(_nodes[piece_id] as Node3D).position = local_position
		return false
	var expected: RoverPieceData = _order[_next_index]
	if piece_id != expected.id:
		# Lugar correcto pero fuera de orden: vuelve a la mesa y cuenta como error.
		_errors += 1
		var data: RoverPieceData = _find_data(piece_id)
		_hint_label.text = tr("Todavía no va «%s». Antes hay que instalar: %s") % [tr(data.nombre), tr(expected.nombre)]
		_move_piece(piece_id, _tray[piece_id])
		wrong_order.emit(piece_id, expected.id)
		_refresh_hud()
		return false
	_install(piece_id)
	return true

## Atajo: instala una pieza como si se soltara justo en su lugar.
func place_piece(piece_id: StringName) -> bool:
	if not _home.has(piece_id):
		return false
	return drop_piece(piece_id, _home[piece_id])

## Devuelve todas las piezas a la mesa y vuelve a la elección de modo.
func restart() -> void:
	_reset_state()

# --- Construcción ---

## Instancia el modelo, registra cada pieza y calcula su lugar en la mesa.
func _build_rover() -> void:
	_title.text = tr(rover_data.nombre)
	_subtitle.text = tr(rover_data.subtitulo)
	_credit_label.text = tr(rover_data.credito)
	_order = rover_data.get_piezas_en_orden()
	var model: Node3D = rover_data.modelo.instantiate() as Node3D
	_model_root.add_child(model)
	var ghost_material: StandardMaterial3D = StandardMaterial3D.new()
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = rover_data.color_silueta
	ghost_material.no_depth_test = false
	var count: int = _order.size()
	for i: int in count:
		var data: RoverPieceData = _order[i]
		var node: Node3D = model.find_child(data.node_name, true, false) as Node3D
		if node == null:
			push_warning("RoverWorkshop: no se encontró la pieza '%s' en el modelo." % data.node_name)
			continue
		_nodes[data.id] = node
		_home[data.id] = node.position
		var box: AABB = _collect_local_box(node)
		_local_boxes[data.id] = box
		_local_faces[data.id] = _collect_local_faces(node)
		# Lugar en la mesa: un arco frente a la cámara, en orden de armado de izquierda a derecha.
		var t: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var angle: float = deg_to_rad(-rover_data.angulo_mesa * 0.5 + rover_data.angulo_mesa * t)
		var floor_y: float = -box.position.y  # apoya la pieza sobre el suelo
		_tray[data.id] = Vector3(sin(angle) * rover_data.radio_mesa, floor_y, cos(angle) * rover_data.radio_mesa)
		# Silueta: una copia transparente que se queda en el lugar armado.
		var ghost: Node3D = node.duplicate() as Node3D
		for mesh_node: Node in ghost.find_children("*", "MeshInstance3D", true, false):
			(mesh_node as MeshInstance3D).material_override = ghost_material
		if ghost is MeshInstance3D:
			(ghost as MeshInstance3D).material_override = ghost_material
		ghost.name = "%s_silueta" % data.node_name
		ghost.visible = false
		model.add_child(ghost)
		ghost.position = node.position
		_ghosts[data.id] = ghost

## Crea una fila de la lista de procedimiento por pieza, copiando la plantilla de la escena.
func _build_steps() -> void:
	for data: RoverPieceData in _order:
		var row: Label = _step_template.duplicate() as Label
		row.visible = true
		row.text = "%2d. %s" % [data.orden, tr(data.nombre)]
		_steps_box.add_child(row)
		_steps[data.id] = row
	_step_template.visible = false

## Une las cajas de todas las mallas de una pieza, en coordenadas de la pieza.
func _collect_local_box(piece: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mesh_instance: MeshInstance3D in _meshes_of(piece):
		var relative: Transform3D = piece.global_transform.affine_inverse() * mesh_instance.global_transform
		var part: AABB = relative * mesh_instance.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box

## Junta los triángulos de todas las mallas de una pieza (para el clic exacto).
func _collect_local_faces(piece: Node3D) -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	for mesh_instance: MeshInstance3D in _meshes_of(piece):
		if mesh_instance.mesh == null:
			continue
		var relative: Transform3D = piece.global_transform.affine_inverse() * mesh_instance.global_transform
		for vertex: Vector3 in mesh_instance.mesh.get_faces():
			faces.append(relative * vertex)
	return faces

func _meshes_of(piece: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if piece is MeshInstance3D:
		result.append(piece as MeshInstance3D)
	for node: Node in piece.find_children("*", "MeshInstance3D", true, false):
		result.append(node as MeshInstance3D)
	return result

func _reset_state() -> void:
	_phase = Phase.CHOOSING
	_errors = 0
	_stars = 0
	_elapsed = 0.0
	_next_index = 0
	_dragging = false
	_pressed_id = &""
	for piece_id: StringName in _nodes.keys():
		_installed[piece_id] = false
		(_nodes[piece_id] as Node3D).position = _tray[piece_id]
	_card.visible = false
	_result_panel.visible = false
	_mode_panel.visible = true
	_hint_label.text = tr("Elige un modo para empezar el entrenamiento.")
	_update_ghost()
	_refresh_hud()

# --- Reglas ---

func _install(piece_id: StringName) -> void:
	_installed[piece_id] = true
	_move_piece(piece_id, _home[piece_id])
	_next_index += 1
	piece_installed.emit(piece_id)
	if _next_index >= _order.size():
		_finish()
	else:
		var next: RoverPieceData = _order[_next_index]
		_hint_label.text = tr("¡Instalado! Siguiente paso: %s") % tr(next.instruccion)
	_update_ghost()
	_refresh_hud()

func _finish() -> void:
	_phase = Phase.DONE
	if _errors <= rover_data.errores_para_3_estrellas:
		_stars = 3
	elif _errors <= rover_data.errores_para_2_estrellas:
		_stars = 2
	else:
		_stars = 1
	var stars_text: String = "★".repeat(_stars) + "☆".repeat(3 - _stars)
	if _mode == Mode.EVALUATION:
		_result_title.text = tr("¡Evaluación aprobada! %s está listo.") % tr(rover_data.nombre)
		_result_detail.text = tr("%s\nTiempo: %s   ·   Errores: %d") % [stars_text, _format_time(_elapsed), _errors]
		var promotion: String = _promote_card()
		if not promotion.is_empty():
			_result_detail.text += "\n" + promotion
	else:
		_result_title.text = tr("¡Entrenamiento completo! Armaste a %s.") % tr(rover_data.nombre)
		_result_detail.text = tr("%s   ·   Errores: %d\nAhora prueba el modo EVALUACIÓN, sin ayuda.") % [stars_text, _errors]
	_hint_label.text = tr("Rover completo. Pulsa EMPEZAR DE NUEVO para practicar otra vez.")
	_card.visible = false
	_show_mars_photo()
	_result_panel.visible = true
	# Medalla: en la evaluación según las estrellas; el entrenamiento guiado da bronce.
	PlayerProgress.award_and_notify(PlayerProgress.ROVER,
		PlayerProgress.medal_for_stars(_stars) if _mode == Mode.EVALUATION else PlayerProgress.BRONZE)
	training_completed.emit(_stars, _errors, _elapsed)

## Muestra la siguiente foto real del Perseverance con su texto y su crédito.
func _show_mars_photo() -> void:
	var photos: Array = _load_photos()
	if photos.is_empty():
		_mars_photo.texture = null
		_mars_caption.text = ""
		return
	_photo_index = (_photo_index + 1) % photos.size() if _photo_index >= 0 else randi() % photos.size()
	var photo: Dictionary = photos[_photo_index] as Dictionary
	_mars_photo.texture = load(String(photo.get("archivo", ""))) as Texture2D
	var when: String = String(photo.get("fecha_foto", ""))
	if photo.get("sol") != null:
		when = tr("sol %d, %s") % [int(photo.get("sol")), when]
	_mars_caption.text = tr("%s\nMastcam-Z, %s · Crédito: %s (%s)") % [tr(String(photo.get("texto", ""))), when, photo.get("credito", ""), photo.get("id", "")]

## ID de la foto mostrada (vacío si no hay ninguna). Lo usan las pruebas.
func get_shown_photo_id() -> String:
	var photos: Array = _load_photos()
	if _photo_index < 0 or _photo_index >= photos.size():
		return ""
	return String((photos[_photo_index] as Dictionary).get("id", ""))

func _load_photos() -> Array:
	var file: FileAccess = FileAccess.open(PHOTOS_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	return (parsed as Dictionary).get("fotos", []) as Array

## Sube de nivel el carnet guardado, si corresponde. Devuelve el texto a mostrar.
func _promote_card() -> String:
	if not promote_card or _stars < card_promotion_stars:
		return ""
	var card: AstronautCard = AstronautCard.load_saved()
	if card == null:
		return tr("Crea tu carnet en el menú para ganar acceso al laboratorio.")
	if card.nivel_acceso >= card_promotion_level:
		return ""
	card.nivel_acceso = card_promotion_level
	if not card.save_card():
		return ""
	return tr("¡Tu carnet subió a nivel %d: %s!") % [card.nivel_acceso, tr(card.get_rank())]

func _find_data(piece_id: StringName) -> RoverPieceData:
	for data: RoverPieceData in _order:
		if data.id == piece_id:
			return data
	return null

# --- Movimiento, silueta e interfaz ---

func _move_piece(piece_id: StringName, target: Vector3) -> void:
	var node: Node3D = _nodes[piece_id]
	if rover_data.duracion_movimiento <= 0.0 or not is_inside_tree():
		node.position = target
		return
	var tween: Tween = create_tween()
	tween.tween_property(node, "position", target, rover_data.duracion_movimiento).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## En modo guiado, solo se ve la silueta de la pieza que toca instalar.
func _update_ghost() -> void:
	var next: RoverPieceData = get_next_piece()
	for piece_id: StringName in _ghosts.keys():
		var show: bool = _mode == Mode.GUIDED and next != null and piece_id == next.id
		(_ghosts[piece_id] as Node3D).visible = show

func _show_card(data: RoverPieceData) -> void:
	_card.visible = true
	_card_icon.texture = data.icono
	_card_name.text = "%d. %s" % [data.orden, tr(data.nombre)]
	# En español se muestra también el nombre en inglés; en inglés sería repetirlo.
	_card_name_en.text = data.nombre_en
	_card_name_en.visible = not Localization.is_english()
	_card_text.text = tr(data.descripcion)
	_card_material.text = tr("De qué está hecho: ") + tr(data.material)
	_card_why.text = tr("Por qué es importante: ") + tr(data.importancia)
	_card_fact.text = tr("Dato real: ") + tr(data.dato)
	_card_link.text = tr("En la misión: ") + tr(data.conexion_mision)

func _refresh_hud() -> void:
	var installed: int = _next_index
	match _phase:
		Phase.CHOOSING:
			_phase_label.text = tr("ENTRENAMIENTO DE ENSAMBLAJE")
			_progress_label.text = tr("%d piezas separadas en la mesa") % _nodes.size()
		Phase.ASSEMBLING:
			if _mode == Mode.GUIDED:
				_phase_label.text = tr("MODO ENTRENAMIENTO GUIADO")
				_progress_label.text = tr("Paso %d de %d   ·   Errores: %d") % [mini(installed + 1, _nodes.size()), _nodes.size(), _errors]
			else:
				_phase_label.text = tr("MODO EVALUACIÓN")
				_progress_label.text = tr("Paso %d de %d   ·   Errores: %d   ·   Tiempo: %s") % [mini(installed + 1, _nodes.size()), _nodes.size(), _errors, _format_time(_elapsed)]
		Phase.DONE:
			_phase_label.text = tr("¡ROVER ARMADO!")
			_progress_label.text = tr("%d de %d piezas   ·   Errores: %d") % [installed, _nodes.size(), _errors]
	# Lista de procedimiento: ✔ instaladas, ▶ la actual y el resto en gris.
	var next: RoverPieceData = get_next_piece()
	for data: RoverPieceData in _order:
		if not _steps.has(data.id):
			continue
		var row: Label = _steps[data.id]
		if is_piece_installed(data.id):
			row.text = "✔ %d. %s" % [data.orden, tr(data.nombre)]
			row.modulate = Color(0.55, 0.95, 0.7, 1.0)
		elif next != null and next.id == data.id and _mode == Mode.GUIDED:
			row.text = "▶ %d. %s" % [data.orden, tr(data.nombre)]
			row.modulate = Color(1.0, 0.86, 0.45, 1.0)
		else:
			row.text = "   %d. %s" % [data.orden, tr(data.nombre)] if _mode == Mode.GUIDED else "   %d. ???" % data.orden
			row.modulate = Color(0.7, 0.74, 0.82, 0.8)

func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]

# --- Entrada: clic, arrastre y cámara ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_on_left_press(button.position)
			else:
				_on_left_release(button.position)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = button.pressed
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom(-zoom_step)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom(zoom_step)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _orbiting:
			_camera_pivot.rotate_y(-motion.relative.x * orbit_speed)
		elif _pressed_id != &"":
			_on_drag(motion.position)

func _on_left_press(screen_position: Vector2) -> void:
	var piece_id: StringName = _pick_piece(screen_position)
	if piece_id == &"":
		return
	_show_card(_find_data(piece_id))
	if _phase != Phase.ASSEMBLING or is_piece_installed(piece_id):
		return
	_pressed_id = piece_id
	_press_position = screen_position
	_dragging = false

func _on_drag(screen_position: Vector2) -> void:
	var node: Node3D = _nodes[_pressed_id]
	if not _dragging:
		if screen_position.distance_to(_press_position) < drag_threshold_px:
			return
		_dragging = true
		# La pieza se levanta y se mueve sobre un plano horizontal a esa altura.
		_drag_plane_y = node.global_position.y + rover_data.altura_arrastre
		var grab: Variant = _ray_to_plane(_press_position, _drag_plane_y)
		_drag_offset = (node.global_position + Vector3.UP * rover_data.altura_arrastre) - (grab as Vector3) if grab != null else Vector3.ZERO
	var hit: Variant = _ray_to_plane(screen_position, _drag_plane_y)
	if hit != null:
		node.global_position = (hit as Vector3) + _drag_offset

func _on_left_release(_screen_position: Vector2) -> void:
	if _pressed_id == &"":
		return
	var piece_id: StringName = _pressed_id
	_pressed_id = &""
	if not _dragging:
		return
	_dragging = false
	var node: Node3D = _nodes[piece_id]
	# Al soltar, se compara con su lugar sin contar la altura extra del arrastre.
	var dropped: Vector3 = node.position
	var home: Vector3 = _home[piece_id]
	if Vector2(dropped.x - home.x, dropped.z - home.z).length() <= rover_data.distancia_encaje:
		dropped.y = home.y
	else:
		dropped.y -= rover_data.altura_arrastre
	drop_piece(piece_id, dropped)

func _ray_to_plane(screen_position: Vector2, plane_y: float) -> Variant:
	var plane: Plane = Plane(Vector3.UP, plane_y)
	return plane.intersects_ray(_camera.project_ray_origin(screen_position), _camera.project_ray_normal(screen_position))

func _zoom(amount: float) -> void:
	var distance: float = clampf(_camera.position.length() + amount, zoom_min, zoom_max)
	_camera.position = _camera.position.normalized() * distance

## Devuelve la pieza bajo el cursor (o &"" si no hay ninguna).
## 1) Descarta rápido con la caja de cada pieza. 2) Prueba los triángulos reales
## de las candidatas, de la más cercana a la más lejana. No usa colisiones físicas.
func _pick_piece(screen_position: Vector2) -> StringName:
	var origin: Vector3 = _camera.project_ray_origin(screen_position)
	var direction: Vector3 = _camera.project_ray_normal(screen_position)
	var candidates: Array = []
	for piece_id: StringName in _nodes.keys():
		var node: Node3D = _nodes[piece_id]
		var world_box: AABB = node.global_transform * (_local_boxes[piece_id] as AABB)
		var hit: Variant = world_box.intersects_ray(origin, direction)
		if hit != null:
			candidates.append([origin.distance_to(hit as Vector3), piece_id])
		elif world_box.has_point(origin):
			candidates.append([0.0, piece_id])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var best_id: StringName = &""
	var best_distance: float = INF
	for candidate: Array in candidates:
		if float(candidate[0]) >= best_distance:
			break
		var piece_id: StringName = candidate[1]
		var distance: float = _ray_distance_to_piece(piece_id, origin, direction)
		if distance < best_distance:
			best_distance = distance
			best_id = piece_id
	return best_id

## Distancia desde el origen del rayo hasta el triángulo más cercano de la pieza (INF si no choca).
func _ray_distance_to_piece(piece_id: StringName, origin: Vector3, direction: Vector3) -> float:
	var node: Node3D = _nodes[piece_id]
	var to_local: Transform3D = node.global_transform.affine_inverse()
	var local_origin: Vector3 = to_local * origin
	var local_direction: Vector3 = (to_local.basis * direction).normalized()
	var faces: PackedVector3Array = _local_faces[piece_id]
	var best: float = INF
	var i: int = 0
	while i + 2 < faces.size():
		var hit: Variant = Geometry3D.ray_intersects_triangle(local_origin, local_direction, faces[i], faces[i + 1], faces[i + 2])
		if hit != null:
			best = minf(best, local_origin.distance_to(hit as Vector3))
		i += 3
	return best

# --- Botones ---

func _on_guided_pressed() -> void:
	start_training(Mode.GUIDED)

func _on_evaluation_pressed() -> void:
	start_training(Mode.EVALUATION)

func _on_restart_pressed() -> void:
	restart()

func _on_menu_pressed() -> void:
	var error: Error = get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		push_error("RoverWorkshop: no se pudo volver al menú (error %d)" % error)

func _on_close_card_pressed() -> void:
	_card.visible = false

# --- Tutoriales ---

## Tutorial de entrada al taller: qué se hace y cómo elegir el modo.
func show_guide(force: bool = true) -> GuideOverlay:
	if _phase != Phase.CHOOSING:
		return show_assembly_guide(force)
	return GuideOverlay.start(self, "taller_rover", [
		GuideOverlay.step(tr("Taller del Rover"),
			tr("Las [b]16 piezas[/b] del rover Perseverance están separadas en la mesa. Tu trabajo: armarlo en el orden correcto, como los ingenieros de la NASA.")),
		GuideOverlay.step(tr("Elige un modo"),
			tr("[b]Guiado[/b]: una silueta te muestra dónde va cada pieza (ideal la primera vez).\n[b]Evaluación[/b]: sin ayuda y con cronómetro. Te da de 1 a 3 estrellas y tu medalla."), _mode_panel),
	], false, force)

## Tutorial del armado (la primera vez que se empieza a armar).
func show_assembly_guide(force: bool = true) -> GuideOverlay:
	return GuideOverlay.start(self, "taller_armado", [
		GuideOverlay.step(tr("Qué pieza sigue"),
			tr("Aquí ves la instrucción del paso actual."), _hint_label),
		GuideOverlay.step(tr("El procedimiento"),
			tr("La lista de pasos en orden: se arma [b]de abajo hacia arriba[/b]. Si pones una pieza antes de tiempo, cuenta como error."), %StepsBox),
		GuideOverlay.step(tr("Arrastra las piezas"),
			tr("Con el [b]botón izquierdo[/b] arrastra la pieza desde la mesa hasta el rover.\n[b]Botón derecho[/b]: girar la cámara · [b]Rueda[/b]: acercar o alejar.")),
		GuideOverlay.step(tr("Aprende de cada pieza"),
			tr("Al instalarla (o al hacer clic en ella) verás una tarjeta: de qué está hecha, para qué sirve y un dato real de la misión."), _progress_label),
	], false, force)
