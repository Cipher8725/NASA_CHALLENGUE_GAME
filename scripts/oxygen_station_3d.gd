class_name OxygenStation3D
extends Node3D

## Puesto de oxígeno en 3D del minijuego de reparación del oxígeno.
##
## Carga el modelo `ai_assets/models/minijuegos/oxygen_station.glb` (hecho en Blender con
## `tools/blender/oxygen_station.py`): tanque de O2, tubería, válvula de purga con volante
## rojo, manómetro de 0 a 100 % y piloto de estado. La aguja del manómetro es la aguja del
## minijuego y la zona verde se dibuja sobre la esfera. Al acertar, el volante gira, sale
## vapor y el piloto destella en verde; al fallar, el piloto parpadea en rojo.

const MODEL_PATH: String = "res://ai_assets/models/minijuegos/oxygen_station.glb"
## Arco de la escala del manómetro: 0 % a -135° y 100 % a +135° (medido desde arriba,
## en sentido horario), igual que la esfera dibujada en la textura.
const DIAL_START_DEG: float = -135.0
const DIAL_SWEEP_DEG: float = 270.0
## Radios (en metros) de la banda verde sobre la esfera, por fuera de las marcas.
const ZONE_INNER_RADIUS: float = 0.205
const ZONE_OUTER_RADIUS: float = 0.246
## Distancia de la banda verde por delante de la esfera, para que no parpadee.
const ZONE_OFFSET: float = 0.0015
const ZONE_SEGMENTS: int = 48
const COLOR_IDLE: Color = Color(0.2, 1.0, 0.45)
const COLOR_HIT: Color = Color(0.45, 1.0, 0.6)
const COLOR_MISS: Color = Color(1.0, 0.15, 0.1)
const COLOR_ZONE: Color = Color(0.15, 0.85, 0.35)
## Balanceo lento de la cámara para que se note el volumen.
const SWAY_SPEED: float = 0.35
const SWAY_AMOUNT: float = 0.05
## Encuadre: se ve todo el puesto, con el manómetro en el centro.
const CAMERA_POSITION: Vector3 = Vector3(0.12, 0.2, 1.62)
const CAMERA_TARGET: Vector3 = Vector3(0.03, 0.07, 0.0)

var _model: Node3D
var _needle: Node3D
var _valve: Node3D
var _lamp: MeshInstance3D
var _lamp_material: StandardMaterial3D
var _lamp_light: OmniLight3D
var _zone: MeshInstance3D
var _steam: CPUParticles3D
var _camera: Camera3D
var _gauge_center: Vector3 = Vector3.ZERO
var _needle_value: float = 0.0
var _zone_center: float = -1.0
var _zone_width: float = -1.0
var _flash_tween: Tween
var _valve_tween: Tween
var _time: float = 0.0

func _ready() -> void:
	_build_environment()
	_build_station()
	set_state(0.0, 0.5, 0.16)

func _process(delta: float) -> void:
	_time += delta
	if _camera != null:
		_camera.position.x = CAMERA_POSITION.x + sin(_time * SWAY_SPEED) * SWAY_AMOUNT
		_camera.look_at(CAMERA_TARGET)

# --- API pública ---

## Coloca la aguja (0.0 a 1.0) y la zona verde (centro y ancho, en fracción de la escala).
func set_state(needle: float, target_center: float, target_width: float) -> void:
	_needle_value = clampf(needle, 0.0, 1.0)
	if _needle != null:
		_needle.rotation.z = -deg_to_rad(value_to_degrees(_needle_value))
	if not is_equal_approx(target_center, _zone_center) or not is_equal_approx(target_width, _zone_width):
		_zone_center = target_center
		_zone_width = target_width
		_rebuild_zone()

## Pulso correcto: el volante gira un cuarto de vuelta, sale vapor y el piloto destella.
func flash_hit() -> void:
	if _valve != null:
		if _valve_tween:
			_valve_tween.kill()
		_valve_tween = create_tween()
		_valve_tween.tween_property(_valve, "rotation:z", _valve.rotation.z - PI * 0.5, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _steam != null:
		_steam.restart()
		_steam.emitting = true
	_flash_lamp(COLOR_HIT, 1)

## Pulso fallido: el piloto parpadea en rojo dos veces.
func flash_miss() -> void:
	_flash_lamp(COLOR_MISS, 2)

## Ángulo de la aguja (grados desde arriba, sentido horario) para un valor de 0.0 a 1.0.
static func value_to_degrees(value: float) -> float:
	return DIAL_START_DEG + DIAL_SWEEP_DEG * clampf(value, 0.0, 1.0)

## Ángulo actual de la aguja en grados (lo usan las pruebas).
func get_needle_degrees() -> float:
	return -rad_to_deg(_needle.rotation.z) if _needle != null else 0.0

## ¿Se cargó el modelo con todas sus piezas móviles?
func is_model_ready() -> bool:
	return _needle != null and _valve != null and _lamp != null and _zone != null

## Ángulos (en grados) donde empieza y termina la zona verde dibujada.
func get_zone_degrees() -> Vector2:
	var half: float = _zone_width * 0.5
	return Vector2(value_to_degrees(_zone_center - half), value_to_degrees(_zone_center + half))

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
	key.rotation_degrees = Vector3(-30.0, 28.0, 0.0)
	key.light_energy = 1.0
	key.shadow_enabled = true
	add_child(key)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(-0.9, 0.4, 1.0)
	fill.omni_range = 3.0
	fill.light_energy = 0.8
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)
	var dial_light: SpotLight3D = SpotLight3D.new()
	dial_light.position = Vector3(0.16, 0.5, 0.9)
	dial_light.spot_range = 3.0
	dial_light.spot_angle = 18.0
	dial_light.light_energy = 0.8
	add_child(dial_light)
	dial_light.look_at(Vector3(0.16, -0.03, 0.1))

	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.position = CAMERA_POSITION
	add_child(_camera)
	_camera.look_at(CAMERA_TARGET)

func _build_station() -> void:
	var packed: PackedScene = load(MODEL_PATH) as PackedScene
	if packed == null:
		push_warning("OxygenStation3D: no se encontró %s" % MODEL_PATH)
		return
	_model = packed.instantiate() as Node3D
	add_child(_model)
	_needle = _model.find_child("Needle", true, false) as Node3D
	_valve = _model.find_child("Valve", true, false) as Node3D
	_lamp = _model.find_child("Lamp", true, false) as MeshInstance3D
	var center: Node3D = _model.find_child("GaugeCenter", true, false) as Node3D
	if center != null:
		_gauge_center = center.position
	elif _needle != null:
		_gauge_center = _needle.position

	# Aguja roja intensa para que se lea bien sobre la esfera clara.
	var needle_mesh: MeshInstance3D = _needle as MeshInstance3D
	if needle_mesh != null:
		var needle_material: StandardMaterial3D = StandardMaterial3D.new()
		needle_material.albedo_color = Color(0.85, 0.05, 0.03)
		needle_material.roughness = 0.45
		needle_material.emission_enabled = true
		needle_material.emission = Color(0.5, 0.02, 0.0)
		needle_mesh.material_override = needle_material
	if _lamp != null:
		_lamp_material = StandardMaterial3D.new()
		_lamp_material.albedo_color = COLOR_IDLE
		_lamp_material.emission_enabled = true
		_lamp_material.emission = COLOR_IDLE
		_lamp_material.emission_energy_multiplier = 1.2
		_lamp.material_override = _lamp_material
		_lamp_light = OmniLight3D.new()
		_lamp_light.light_color = COLOR_IDLE
		_lamp_light.light_energy = 0.4
		_lamp_light.omni_range = 0.6
		_lamp_light.position = _lamp.position + Vector3(0.0, 0.0, 0.08)
		_model.add_child(_lamp_light)

	_zone = MeshInstance3D.new()
	_zone.name = "GreenZone"
	var zone_material: StandardMaterial3D = StandardMaterial3D.new()
	zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_material.albedo_color = COLOR_ZONE
	zone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_zone.material_override = zone_material
	_zone.position = Vector3(_gauge_center.x, _gauge_center.y, _gauge_center.z - 0.002 + ZONE_OFFSET)
	_model.add_child(_zone)

	var vent: Node3D = _model.find_child("Vent", true, false) as Node3D
	_steam = CPUParticles3D.new()
	_steam.position = vent.position if vent != null else Vector3(-0.14, 0.47, 0.08)
	_steam.emitting = false
	_steam.one_shot = true
	_steam.amount = 36
	_steam.lifetime = 0.9
	_steam.explosiveness = 0.85
	_steam.direction = Vector3(0.3, 1.0, 0.4)
	_steam.spread = 25.0
	_steam.initial_velocity_min = 0.35
	_steam.initial_velocity_max = 0.6
	_steam.gravity = Vector3(0.0, 0.25, 0.0)
	_steam.damping_min = 0.4
	_steam.damping_max = 0.8
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.4
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(1.0, 1.0))
	_steam.scale_amount_curve = scale_curve
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_steam.color_ramp = fade
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 0.025
	puff.height = 0.05
	puff.radial_segments = 10
	puff.rings = 5
	var puff_material: StandardMaterial3D = StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.vertex_color_use_as_albedo = true
	puff.material = puff_material
	_steam.mesh = puff
	_model.add_child(_steam)

## Dibuja la banda verde (un sector de anillo) entre los ángulos de la zona buena.
func _rebuild_zone() -> void:
	if _zone == null:
		return
	var half: float = _zone_width * 0.5
	var from_deg: float = value_to_degrees(_zone_center - half)
	var to_deg: float = value_to_degrees(_zone_center + half)
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in ZONE_SEGMENTS + 1:
		var angle: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / ZONE_SEGMENTS))
		var direction: Vector3 = Vector3(sin(angle), cos(angle), 0.0)
		vertices.append(direction * ZONE_INNER_RADIUS)
		vertices.append(direction * ZONE_OUTER_RADIUS)
		if i < ZONE_SEGMENTS:
			var k: int = i * 2
			indices.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_zone.mesh = mesh

func _flash_lamp(color: Color, times: int) -> void:
	if _lamp_material == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	for i: int in times:
		_flash_tween.tween_callback(_set_lamp.bind(color, 4.0))
		_flash_tween.tween_interval(0.16)
		_flash_tween.tween_callback(_set_lamp.bind(color, 0.6))
		_flash_tween.tween_interval(0.12)
	_flash_tween.tween_callback(_set_lamp.bind(COLOR_IDLE, 1.2))

func _set_lamp(color: Color, energy: float) -> void:
	_lamp_material.albedo_color = color
	_lamp_material.emission = color
	_lamp_material.emission_energy_multiplier = energy
	if _lamp_light != null:
		_lamp_light.light_color = color
		_lamp_light.light_energy = energy * 0.35
