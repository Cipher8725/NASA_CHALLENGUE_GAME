class_name PowerPanel3D
extends Node3D

## Gabinete eléctrico en 3D del minijuego de reparación de la energía.
##
## Carga `ai_assets/models/minijuegos/power_panel.glb` (hecho en Blender con
## `tools/blender/power_panel.py`). A la izquierda cuelgan cuatro enchufes de colores
## (A rojo, B azul, C verde, D amarillo) con sus cables saliendo de la bandeja; a la
## derecha hay cuatro tomas con su letra (en el mismo orden barajado que los botones)
## y un piloto cada una. Al conectar bien, el enchufe viaja hasta su toma, el cable se
## tiende y el piloto se pone verde; al fallar saltan chispas y el piloto parpadea en rojo.
## Al terminar, la palanca general sube y todo se enciende.

const MODEL_PATH: String = "res://ai_assets/models/minijuegos/power_panel.glb"
const CABLE_COUNT: int = 4
## Colores y letras iguales a los del minijuego (`CableRepairMinigame.CABLE_STYLE`).
const CABLE_COLORS: Array[Color] = [
	Color(0.90, 0.20, 0.18), Color(0.20, 0.50, 0.95), Color(0.25, 0.80, 0.35), Color(0.95, 0.78, 0.18)]
const CABLE_LETTERS: PackedStringArray = ["A", "B", "C", "D"]
const CABLE_RADIUS: float = 0.011
const CABLE_SIDES: int = 8
const CABLE_SEGMENTS: int = 28
## El enchufe entra en la toma con la punta hacia dentro del gabinete.
const PLUGGED_ROTATION_X: float = PI * 0.5
## Distancia de la boca de la toma al centro del enchufe enchufado.
const PLUG_DEPTH: float = 0.035
const LIFT_SELECTED: float = 0.035
const LED_OFF: Color = Color(0.25, 0.27, 0.3)
const LED_OK: Color = Color(0.3, 1.0, 0.15)
const LED_BAD: Color = Color(1.0, 0.15, 0.1)
const CAMERA_POSITION: Vector3 = Vector3(0.0, 0.02, 1.4)
const CAMERA_TARGET: Vector3 = Vector3(0.0, -0.01, 0.0)
const SWAY_SPEED: float = 0.35
const SWAY_AMOUNT: float = 0.05

var _model: Node3D
var _plugs: Array[Node3D] = []
var _plug_rest: Array[Transform3D] = []
var _cable_ends: Array[Node3D] = []
var _outlets: Array[Vector3] = []
var _sockets: Array[Vector3] = []
var _socket_leds: Array[StandardMaterial3D] = []
var _socket_labels: Array[Label3D] = []
var _cables: Array[MeshInstance3D] = []
var _plug_materials: Array[StandardMaterial3D] = []
var _connected_socket: Array[int] = [-1, -1, -1, -1]
var _socket_order: Array[int] = [0, 1, 2, 3]
var _lever: Node3D
var _main_led: StandardMaterial3D
var _sparks: CPUParticles3D
var _camera: Camera3D
var _selected: int = -1
var _time: float = 0.0
var _complete: bool = false

func _ready() -> void:
	_build_environment()
	_build_panel()
	reset([0, 1, 2, 3])

func _process(delta: float) -> void:
	_time += delta
	if _camera != null:
		_camera.position.x = CAMERA_POSITION.x + sin(_time * SWAY_SPEED) * SWAY_AMOUNT
		_camera.look_at(CAMERA_TARGET)
	# Los cables siguen a los enchufes mientras se mueven.
	_update_cables()

# --- API pública ---

## Vuelve a empezar con un nuevo orden de tomas: `socket_order[posicion]` es el cable de esa toma.
func reset(socket_order: Array[int]) -> void:
	_socket_order = socket_order.duplicate()
	_connected_socket = [-1, -1, -1, -1]
	_selected = -1
	_complete = false
	for i: int in mini(_plugs.size(), CABLE_COUNT):
		_plugs[i].transform = _plug_rest[i]
		_set_plug_glow(i, false)
	for position: int in mini(_socket_labels.size(), CABLE_COUNT):
		var cable_index: int = _socket_order[position]
		_socket_labels[position].text = CABLE_LETTERS[cable_index]
		_socket_labels[position].modulate = CABLE_COLORS[cable_index].lightened(0.25)
		_set_led(position, LED_OFF, 0.0)
	if _lever != null:
		_lever.rotation.x = 0.0
	if _main_led != null:
		_set_material_light(_main_led, LED_BAD, 1.0)
	_update_cables()

## Resalta el cable elegido (el enchufe sube un poco y brilla).
func select_cable(cable_index: int) -> void:
	if _selected >= 0 and _selected != cable_index and _connected_socket[_selected] < 0:
		_move_plug(_selected, _plug_rest[_selected], 0.15)
		_set_plug_glow(_selected, false)
	_selected = cable_index
	if cable_index < 0 or cable_index >= _plugs.size() or _connected_socket[cable_index] >= 0:
		return
	var lifted: Transform3D = _plug_rest[cable_index]
	lifted.origin.y += LIFT_SELECTED
	lifted.origin.z += 0.03
	_move_plug(cable_index, lifted, 0.15)
	_set_plug_glow(cable_index, true)

## Conexión correcta: el enchufe viaja a la toma y el piloto se pone verde.
func connect_cable(cable_index: int, socket_position: int) -> void:
	if cable_index < 0 or cable_index >= _plugs.size() or socket_position < 0 or socket_position >= _sockets.size():
		return
	_connected_socket[cable_index] = socket_position
	_selected = -1
	_set_plug_glow(cable_index, false)
	var target: Transform3D = Transform3D(Basis(Vector3.RIGHT, PLUGGED_ROTATION_X),
		_sockets[socket_position] + Vector3(0.0, 0.0, PLUG_DEPTH))
	_move_plug(cable_index, target, 0.45)
	_set_led(socket_position, LED_OK, 1.3)
	if get_connected_count() >= CABLE_COUNT:
		_finish()

## Conexión incorrecta: chispas en la toma y piloto rojo parpadeando; el enchufe vuelve a su sitio.
func fail_connection(socket_position: int) -> void:
	if _selected >= 0 and _selected < _plugs.size() and _connected_socket[_selected] < 0:
		_move_plug(_selected, _plug_rest[_selected], 0.2)
		_set_plug_glow(_selected, false)
	_selected = -1
	if socket_position < 0 or socket_position >= _sockets.size():
		return
	if _sparks != null:
		_sparks.position = _sockets[socket_position] + Vector3(0.0, 0.0, 0.02)
		_sparks.restart()
		_sparks.emitting = true
	var tween: Tween = create_tween()
	for i: int in 2:
		tween.tween_callback(_set_led.bind(socket_position, LED_BAD, 4.0))
		tween.tween_interval(0.14)
		tween.tween_callback(_set_led.bind(socket_position, LED_OFF, 0.0))
		tween.tween_interval(0.1)

## Número de enchufes conectados.
func get_connected_count() -> int:
	var total: int = 0
	for socket_position: int in _connected_socket:
		if socket_position >= 0:
			total += 1
	return total

## Toma en la que está enchufado un cable (-1 si cuelga suelto).
func get_cable_socket(cable_index: int) -> int:
	return _connected_socket[cable_index] if cable_index >= 0 and cable_index < CABLE_COUNT else -1

## Letra que muestra la toma de esa posición.
func get_socket_letter(socket_position: int) -> String:
	return _socket_labels[socket_position].text if socket_position >= 0 and socket_position < _socket_labels.size() else ""

## ¿Subió la palanca general?
func is_complete() -> bool:
	return _complete

## ¿Se cargó el modelo con todas sus piezas?
func is_model_ready() -> bool:
	return _plugs.size() == CABLE_COUNT and _sockets.size() == CABLE_COUNT and _outlets.size() == CABLE_COUNT \
		and _lever != null and _cables.size() == CABLE_COUNT

# --- Construcción ---

func _build_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.05, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.52, 0.65)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -22.0, 0.0)
	key.light_energy = 1.0
	key.shadow_enabled = true
	add_child(key)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(0.8, 0.3, 1.0)
	fill.omni_range = 3.0
	fill.light_energy = 0.45
	fill.light_color = Color(0.75, 0.82, 1.0)
	add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.position = CAMERA_POSITION
	add_child(_camera)
	_camera.look_at(CAMERA_TARGET)

func _build_panel() -> void:
	var packed: PackedScene = load(MODEL_PATH) as PackedScene
	if packed == null:
		push_warning("PowerPanel3D: no se encontró %s" % MODEL_PATH)
		return
	_model = packed.instantiate() as Node3D
	add_child(_model)
	for i: int in CABLE_COUNT:
		var plug: Node3D = _model.find_child("Plug_%d" % i, true, false) as Node3D
		var outlet: Node3D = _model.find_child("Outlet_%d" % i, true, false) as Node3D
		var socket: Node3D = _model.find_child("Socket_%d" % i, true, false) as Node3D
		if plug == null or outlet == null or socket == null:
			push_warning("PowerPanel3D: faltan piezas del cable %d" % i)
			return
		_plugs.append(plug)
		_plug_rest.append(plug.transform)
		_cable_ends.append(plug.find_child("CableEnd_%d" % i, true, false) as Node3D)
		_outlets.append(outlet.position)
		_sockets.append(socket.position)
		# El cuerpo del enchufe toma el color de su cable.
		var body: MeshInstance3D = plug.find_child("PlugBody_%d" % i, true, false) as MeshInstance3D
		var plug_material: StandardMaterial3D = StandardMaterial3D.new()
		plug_material.albedo_color = CABLE_COLORS[i]
		plug_material.roughness = 0.4
		plug_material.emission_enabled = true
		plug_material.emission = CABLE_COLORS[i]
		plug_material.emission_energy_multiplier = 0.0
		if body != null:
			body.material_override = plug_material
		_plug_materials.append(plug_material)
		# Piloto de la toma.
		var led: MeshInstance3D = _model.find_child("SocketLed_%d" % i, true, false) as MeshInstance3D
		var led_material: StandardMaterial3D = StandardMaterial3D.new()
		led_material.emission_enabled = true
		if led != null:
			led.material_override = led_material
		_socket_leds.append(led_material)
		# Letra de la toma (cambia con cada partida porque las tomas se barajan).
		var anchor: Node3D = _model.find_child("SocketLabel_%d" % i, true, false) as Node3D
		var label: Label3D = Label3D.new()
		label.font_size = 64
		label.pixel_size = 0.0011
		label.outline_size = 12
		label.position = anchor.position if anchor != null else socket.position + Vector3(-0.11, 0.0, 0.03)
		_model.add_child(label)
		_socket_labels.append(label)
		# Cable: tubo que se recalcula cuando se mueve el enchufe.
		var cable: MeshInstance3D = MeshInstance3D.new()
		var cable_material: StandardMaterial3D = StandardMaterial3D.new()
		cable_material.albedo_color = CABLE_COLORS[i].darkened(0.1)
		cable_material.roughness = 0.55
		cable.material_override = cable_material
		_model.add_child(cable)
		_cables.append(cable)
	_lever = _model.find_child("Lever", true, false) as Node3D
	var main_led_mesh: MeshInstance3D = _model.find_child("MainLed", true, false) as MeshInstance3D
	if main_led_mesh != null:
		_main_led = StandardMaterial3D.new()
		_main_led.emission_enabled = true
		main_led_mesh.material_override = _main_led
	_build_sparks()

func _build_sparks() -> void:
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 28
	_sparks.lifetime = 0.45
	_sparks.explosiveness = 0.95
	_sparks.direction = Vector3(0.0, 0.3, 1.0)
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 0.6
	_sparks.initial_velocity_max = 1.3
	_sparks.gravity = Vector3(0.0, -2.5, 0.0)
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var spark_mesh: SphereMesh = SphereMesh.new()
	spark_mesh.radius = 0.005
	spark_mesh.height = 0.01
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3
	var spark_material: StandardMaterial3D = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1.0, 0.85, 0.35)
	spark_mesh.material = spark_material
	_sparks.mesh = spark_mesh
	_model.add_child(_sparks)

# --- Animación ---

func _move_plug(cable_index: int, target: Transform3D, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_plugs[cable_index], "transform", target, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _finish() -> void:
	_complete = true
	if _lever != null:
		var tween: Tween = create_tween()
		tween.tween_interval(0.45)
		tween.tween_property(_lever, "rotation:x", PI, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _main_led != null:
		_set_material_light(_main_led, LED_OK, 1.3)

func _set_plug_glow(cable_index: int, on: bool) -> void:
	if cable_index >= 0 and cable_index < _plug_materials.size():
		_plug_materials[cable_index].emission_energy_multiplier = 0.9 if on else 0.0

func _set_led(socket_position: int, color: Color, energy: float) -> void:
	if socket_position >= 0 and socket_position < _socket_leds.size():
		_set_material_light(_socket_leds[socket_position], color, energy)

static func _set_material_light(material: StandardMaterial3D, color: Color, energy: float) -> void:
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = energy

## Cada cable es una curva de Bézier desde su pasacables hasta la parte de atrás del enchufe.
## Cuelga hacia abajo cuando está suelto y hace una comba hacia el frente cuando está enchufado.
func _update_cables() -> void:
	for i: int in _cables.size():
		var start: Vector3 = _outlets[i]
		var end: Vector3 = _model.to_local(_cable_ends[i].global_position) if _cable_ends[i] != null else _plugs[i].position
		var plug_up: Vector3 = _plugs[i].transform.basis.y.normalized()
		var control_a: Vector3 = start + Vector3(0.0, -0.12, 0.02)
		var control_b: Vector3 = end + plug_up * 0.12 + Vector3(0.0, -0.06, 0.0)
		_cables[i].mesh = _tube(start, control_a, control_b, end)

func _tube(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var previous_side: Vector3 = Vector3.RIGHT
	for s: int in CABLE_SEGMENTS + 1:
		var t: float = float(s) / CABLE_SEGMENTS
		var point: Vector3 = _bezier(p0, p1, p2, p3, t)
		var tangent: Vector3 = (_bezier(p0, p1, p2, p3, minf(t + 0.01, 1.0)) - _bezier(p0, p1, p2, p3, maxf(t - 0.01, 0.0))).normalized()
		# Marco que gira lo mínimo para que el tubo no se retuerza.
		var side: Vector3 = (previous_side - tangent * previous_side.dot(tangent)).normalized()
		if side.length_squared() < 0.01:
			side = tangent.cross(Vector3.FORWARD).normalized()
		previous_side = side
		var up: Vector3 = tangent.cross(side).normalized()
		for k: int in CABLE_SIDES:
			var angle: float = TAU * float(k) / CABLE_SIDES
			var normal: Vector3 = side * cos(angle) + up * sin(angle)
			vertices.append(point + normal * CABLE_RADIUS)
			normals.append(normal)
	for s: int in CABLE_SEGMENTS:
		for k: int in CABLE_SIDES:
			var a: int = s * CABLE_SIDES + k
			var b: int = s * CABLE_SIDES + (k + 1) % CABLE_SIDES
			indices.append_array([a, a + CABLE_SIDES, b, b, a + CABLE_SIDES, b + CABLE_SIDES])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)
