class_name LaunchSimulation3D
extends LaunchSimulation

## Simulación del despegue del Apolo 8 en 3D.
##
## Usa la misma lógica de misión que la versión 2D (`LaunchSimulation`): reloj,
## maniobras, errores, estrellas y telemetría real. Esta clase solo agrega el
## mundo 3D:
##   * el Saturno V oficial de NASA 3D Resources, dividido en etapas,
##   * la Tierra como esfera de radio real que baja y gira bajo el cohete según
##     la altura y la distancia recorrida reales,
##   * fuego de la etapa que empuja, humo en la plataforma y etapas que caen,
##   * dos vistas: EXTERIOR (cámara que se gira con el ratón) y CABINA (paneles
##     del paquete "Nasa Space 2" con ventanas que dejan ver el mundo 3D).
## El cohete queda siempre en el origen y el mundo se mueve: así no se pierde
## precisión numérica a cientos de kilómetros.

const EARTH_RADIUS_M: float = 6371000.0
## Altura de la cubierta de la plataforma sobre el suelo (Mobile Launcher Apollo: ~7,6 m).
const PAD_DECK_M: float = 7.6
## Encendido de la 1.ª etapa antes de T-0 en el Apolo 8 (aprox. T−6,6 s).
const IGNITION_BEFORE_LIFTOFF_S: float = 6.6
## Hasta este segundo el cohete sube vertical; luego se inclina hacia el este.
const VERTICAL_RISE_S: float = 12.0
## Centro aproximado (altura en m) de cada pieza, para la cámara exterior.
const PIECE_CENTER_M: Dictionary = {"s_ic": 21.0, "s_ii": 55.0, "s_ivb": 78.0, "csm": 97.0}
const STAGE_FIRE: Dictionary = {"s_ic": "Fire_s_ic", "s_ii": "Fire_s_ii", "s_ivb": "Fire_s_ivb"}
const ROCKET_PIECES: Array[String] = ["s_ic", "s_ii", "s_ivb", "adaptador_sla", "csm", "torre_escape"]

@export_group("Cámara")
@export var exterior_distance: float = 190.0
@export var exterior_min_distance: float = 40.0
@export var exterior_max_distance: float = 900.0
@export var mouse_sensitivity: float = 0.25
@export var camera_shake_m: float = 0.35

var _cockpit_view: bool = false
var _ext_yaw: float = 35.0
var _ext_pitch: float = -8.0
var _cab_yaw: float = 0.0
var _cab_pitch: float = 0.0
var _dragging: bool = false
## Etapas soltadas que caen: {node, speed, spin, age}.
var _falling: Array[Dictionary] = []
var _piece_transforms: Dictionary = {}

@onready var _world: Node3D = %World
@onready var _rocket: Node3D = %Rocket
@onready var _earth_pivot: Node3D = %EarthPivot
@onready var _earth: MeshInstance3D = %Earth
@onready var _smoke: CPUParticles3D = %Smoke
@onready var _cabin: Node3D = %Cabin
@onready var _cockpit_camera: Camera3D = %CockpitCamera
@onready var _exterior_pivot: Node3D = %ExteriorPivot
@onready var _exterior_camera: Camera3D = %ExteriorCamera
@onready var _sky_3d: ShaderMaterial = ((get_node("World/WorldEnvironment") as WorldEnvironment).environment.sky.sky_material) as ShaderMaterial

func _ready() -> void:
	for piece: String in ROCKET_PIECES:
		_piece_transforms[piece] = (_rocket.get_node(piece) as Node3D).transform
	super()

# --- API pública (pruebas) ---

func is_cockpit_view() -> bool:
	return _cockpit_view

func is_fire_on(stage: String) -> bool:
	var fire: Node3D = _rocket.get_node_or_null(str(STAGE_FIRE.get(stage, ""))) as Node3D
	return fire != null and fire.visible

## Inclinación del cohete desde la vertical (grados) en un segundo de misión.
func rocket_pitch_deg(t: float) -> float:
	if t <= VERTICAL_RISE_S:
		return 0.0
	var first_point: float = 61.45
	if t < first_point:
		return lerpf(0.0, telemetry_value(first_point, "inclinacion_deg"), (t - VERTICAL_RISE_S) / (first_point - VERTICAL_RISE_S))
	return telemetry_value(t, "inclinacion_deg")

## Distancia (m) entre el centro de la Tierra y el cohete según la altura real.
func earth_offset_m(t: float) -> float:
	return EARTH_RADIUS_M + PAD_DECK_M + telemetry_at(t).x * 1000.0

# --- Ganchos de LaunchSimulation ---

func _on_reset() -> void:
	# Volver a montar las etapas sueltas en el cohete.
	for item: Dictionary in _falling:
		var node: Node3D = item["node"]
		node.reparent(_rocket, false)
	_falling.clear()
	for piece: String in ROCKET_PIECES:
		var node: Node3D = _rocket.get_node(piece) as Node3D
		node.transform = _piece_transforms[piece]
		node.visible = true
	_update_world(0.0)

func _on_stage_dropped(stage: String) -> void:
	var node: Node3D = _rocket.get_node_or_null(stage) as Node3D
	if node == null:
		return
	node.reparent(_world, true)
	_falling.append({"node": node, "speed": 6.0 if stage == "torre_escape" else 2.0, "spin": randf_range(-0.25, 0.25), "age": 0.0, "up": stage == "torre_escape"})

func _on_stage_jolt() -> void:
	_cab_pitch -= 6.0

func _set_view(index: int) -> void:
	_view = wrapi(index, 0, 2)
	_cockpit_view = _view == 1
	_cockpit_camera.current = _cockpit_view
	_exterior_camera.current = not _cockpit_view
	_view_label.text = tr("Vista: Cabina (C)") if _cockpit_view else tr("Vista: Exterior (C)")

func _update_visuals(delta: float) -> void:
	_update_world(delta)

# --- Mundo 3D ---

func _update_world(delta: float) -> void:
	var t: float = get_mission_time()
	var altitude_km: float = telemetry_at(t).x
	var flying: bool = get_phase() == Phase.FLIGHT or get_phase() == Phase.DONE
	# La Tierra baja (altura) y gira hacia atrás (distancia recorrida hacia el este).
	_earth_pivot.position = Vector3(0.0, -earth_offset_m(t), 0.0)
	_earth_pivot.rotation.z = telemetry_value(t, "alcance_km") * 1000.0 / EARTH_RADIUS_M
	_rocket.rotation.z = -deg_to_rad(rocket_pitch_deg(t))
	_sky_3d.set_shader_parameter("altitude_km", altitude_km)
	var now: float = Time.get_ticks_msec() / 1000.0
	var earth_mat: ShaderMaterial = (_earth.mesh as PrimitiveMesh).material as ShaderMaterial
	earth_mat.set_shader_parameter("time_s", now)
	earth_mat.set_shader_parameter("rim_strength", smoothstep(20.0, 150.0, altitude_km) * 0.9)
	# Fuego: solo la etapa que empuja; la 1.ª se enciende unos segundos antes de T-0.
	var igniting: bool = get_phase() == Phase.COUNTDOWN and _countdown_left <= IGNITION_BEFORE_LIFTOFF_S
	for stage: String in STAGE_FIRE:
		var fire: MeshInstance3D = _rocket.get_node(str(STAGE_FIRE[stage])) as MeshInstance3D
		var on: bool = (stage == "s_ic" and igniting) or (flying and stage == get_current_stage() and not is_waiting_for_order() and get_phase() != Phase.DONE)
		fire.visible = on
		if on:
			# En el aire fino la llama se abre más.
			var spread: float = 1.0 + clampf(altitude_km / 40.0, 0.0, 2.5)
			fire.scale = Vector3(spread, 1.0 + 0.08 * sin(now * 30.0), spread)
			((fire.mesh as PrimitiveMesh).material as ShaderMaterial).set_shader_parameter("time_s", now)
	_smoke.emitting = igniting or (get_phase() == Phase.FLIGHT and t < 20.0)
	# Ventanas de la cabina: tapadas hasta soltar la torre de escape.
	for panel: Node in _cabin.get_children():
		if panel is MeshInstance3D and str(panel.name).begins_with("Panel_"):
			var mat: ShaderMaterial = (panel as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
			mat.set_shader_parameter("covered", 0.0 if are_windows_open() else 1.0)
	_update_falling(delta)
	_update_cameras()

func _update_falling(delta: float) -> void:
	var up: Vector3 = _rocket.global_transform.basis.y
	for i: int in range(_falling.size() - 1, -1, -1):
		var item: Dictionary = _falling[i]
		var node: Node3D = item["node"]
		item["age"] = float(item["age"]) + delta
		item["speed"] = float(item["speed"]) + delta * (4.0 if bool(item["up"]) else 9.0)
		# La torre sale disparada hacia adelante; las etapas quedan atrás y giran.
		node.global_position += (up if bool(item["up"]) else -up) * float(item["speed"]) * delta * 6.0
		node.rotate_z(float(item["spin"]) * delta)
		if float(item["age"]) > 25.0:
			node.visible = false

func _update_cameras() -> void:
	var stages: Dictionary = _data.get("etapas", {}) as Dictionary
	var shake: float = 0.0
	if get_phase() == Phase.FLIGHT and stages.has(get_current_stage()) and not is_waiting_for_order():
		shake = float((stages[get_current_stage()] as Dictionary).get("vibracion", 0.0)) * camera_shake_m
	var now: float = Time.get_ticks_msec() / 1000.0
	var jitter: Vector2 = Vector2(sin(now * 51.0), cos(now * 43.0)) * shake
	# Exterior: mira al centro de la parte del cohete que queda.
	var lowest: String = "csm"
	for piece: String in ["s_ic", "s_ii", "s_ivb"]:
		if is_stage_attached(piece):
			lowest = piece
			break
	var center_m: float = lerpf(float(PIECE_CENTER_M[lowest]), 97.0, 0.35)
	_exterior_pivot.global_position = _rocket.global_transform * Vector3(0.0, center_m, 0.0)
	_exterior_pivot.rotation_degrees = Vector3(_ext_pitch, _ext_yaw, 0.0)
	_exterior_camera.position = Vector3(0.0, 0.0, exterior_distance)
	_exterior_camera.h_offset = jitter.x * 0.3
	_exterior_camera.v_offset = jitter.y * 0.3
	# Cabina: mirar alrededor (sin dar la vuelta completa).
	_cockpit_camera.rotation_degrees = Vector3(_cab_pitch, _cab_yaw, 0.0)
	_cockpit_camera.h_offset = jitter.x * 0.04
	_cockpit_camera.v_offset = jitter.y * 0.04

# --- Entrada ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP and not _cockpit_view:
			exterior_distance = maxf(exterior_min_distance, exterior_distance * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and not _cockpit_view:
			exterior_distance = minf(exterior_max_distance, exterior_distance * 1.1)
		return
	if event is InputEventMouseMotion and _dragging:
		var motion: Vector2 = (event as InputEventMouseMotion).relative * mouse_sensitivity
		if _cockpit_view:
			_cab_yaw = clampf(_cab_yaw - motion.x, -170.0, 170.0)
			_cab_pitch = clampf(_cab_pitch - motion.y, -80.0, 80.0)
		else:
			_ext_yaw -= motion.x
			_ext_pitch = clampf(_ext_pitch - motion.y, -80.0, 80.0)
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_C:
		_set_view(_view + 1)
		get_viewport().set_input_as_handled()
		return
	super(event)
