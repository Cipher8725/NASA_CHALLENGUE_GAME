class_name HydroponicsGarden3D
extends Node3D

## Huerto 3D del minijuego de hidroponía, inspirado en la cámara Veggie de la ISS.
##
## Todo se construye con primitivas de Godot (regla de greyboxing de AGENTS.md):
## caja blanca con fuelle, barra de LED, base con 6 almohadillas y plantas hechas de
## hojas (esferas aplastadas). Las plantas crecen con el progreso del minijuego,
## la luz toma el color de la fórmula elegida (90:10 o 50:50), las almohadillas se
## oscurecen cuando están húmedas y caen gotas al regar.

## Color de la luz rica en rojo (90 % rojo, 10 % azul) y de la rica en azul (50:50).
const COLOR_RED_RICH: Color = Color(1.0, 0.32, 0.42)
const COLOR_BLUE_RICH: Color = Color(0.72, 0.38, 1.0)
const COLOR_OFF: Color = Color(0.55, 0.58, 0.65)
## Número de almohadillas (como en VEG-04: 6 por tratamiento de luz).
const PILLOWS: int = 6
## Hojas por planta.
const LEAVES: int = 9
## Velocidad de giro lento de la cámara (radianes por segundo).
const ORBIT_SPEED: float = 0.12

var _plants: Array[Node3D] = []
var _pillow_materials: Array[StandardMaterial3D] = []
var _led_material: StandardMaterial3D
var _grow_light: OmniLight3D
var _fill_light: OmniLight3D
var _drops: CPUParticles3D
var _pivot: Node3D
var _crop_id: String = "lechuga"
var _growth: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_build_environment()
	_build_chamber()
	_build_plants()
	set_light("")
	set_growth(0.0)
	set_moisture(0.55)

func _process(delta: float) -> void:
	# La cámara gira despacio para que se vea el volumen del huerto.
	_time += delta
	_pivot.rotation.y = sin(_time * ORBIT_SPEED) * 0.45
	# Las hojas se mecen un poco con el aire de los ventiladores.
	for i: int in _plants.size():
		_plants[i].rotation.z = sin(_time * 1.3 + i) * 0.03

# --- API pública ---

## Cambia el cultivo: "lechuga" (hojas anchas y rojas) o "mizuna" (hojas finas y verdes).
func set_crop(crop_id: String) -> void:
	_crop_id = crop_id
	for plant: Node3D in _plants:
		plant.queue_free()
	_plants.clear()
	_build_plants()
	set_growth(_growth)

## Tamaño de las plantas según el progreso de la cosecha (0 a 1).
func set_growth(progress: float) -> void:
	_growth = clampf(progress, 0.0, 1.0)
	var scale_value: float = lerpf(0.12, 1.0, _growth)
	for plant: Node3D in _plants:
		plant.scale = Vector3.ONE * scale_value

## Luz del huerto: "rojo", "azul" o "" (apagada).
func set_light(kind: String) -> void:
	var color: Color = COLOR_OFF
	var energy: float = 0.4
	if kind == "rojo":
		color = COLOR_RED_RICH
		energy = 2.6
	elif kind == "azul":
		color = COLOR_BLUE_RICH
		# La luz azul aporta cerca de 15 % más energía (dato real de VEG-04).
		energy = 2.6 * 1.15
	_grow_light.light_color = color
	_grow_light.light_energy = energy
	_led_material.emission = color
	_led_material.emission_energy_multiplier = 3.0 if not kind.is_empty() else 0.2

## Humedad de las almohadillas (0 a 1): cuanto más húmedas, más oscuras.
func set_moisture(moisture: float) -> void:
	var dry: Color = Color(0.93, 0.9, 0.82)
	var wet: Color = Color(0.45, 0.42, 0.38)
	for material: StandardMaterial3D in _pillow_materials:
		material.albedo_color = dry.lerp(wet, clampf(moisture, 0.0, 1.0))

## Lanza unas gotas de agua sobre las almohadillas.
func splash() -> void:
	_drops.restart()
	_drops.emitting = true

func get_plant_count() -> int:
	return _plants.size()

func get_growth() -> float:
	return _growth

# --- Construcción ---

func _build_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.ambient_light_energy = 0.32
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_pivot = Node3D.new()
	add_child(_pivot)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 0.95, 1.05)
	camera.rotation_degrees = Vector3(-33, 0, 0)
	camera.fov = 50.0
	camera.current = true
	_pivot.add_child(camera)

	_fill_light = OmniLight3D.new()
	_fill_light.position = Vector3(0.8, 1.2, 1.4)
	_fill_light.light_energy = 0.7
	_fill_light.omni_range = 4.0
	add_child(_fill_light)

func _build_chamber() -> void:
	var white: StandardMaterial3D = _material(Color(0.86, 0.86, 0.9), 0.85)
	var frame: StandardMaterial3D = _material(Color(0.62, 0.64, 0.7), 0.4, 0.6)
	# Fondo, laterales y techo de la cámara (tela blanca del Veggie).
	_box(Vector3(1.6, 1.05, 0.04), Vector3(0, 0.5, -0.45), white)
	_box(Vector3(0.04, 1.05, 0.95), Vector3(-0.8, 0.5, 0.0), white)
	_box(Vector3(0.04, 1.05, 0.95), Vector3(0.8, 0.5, 0.0), white)
	_box(Vector3(1.64, 0.06, 0.98), Vector3(0, 1.04, 0.0), frame)
	# Base y bandeja.
	_box(Vector3(1.64, 0.08, 0.98), Vector3(0, -0.04, 0.0), frame)
	_box(Vector3(1.5, 0.04, 0.8), Vector3(0, 0.02, 0.0), _material(Color(0.95, 0.95, 0.97), 0.7))
	# Barra de LED en el techo.
	_led_material = _material(Color(0.2, 0.2, 0.25), 0.3)
	_led_material.emission_enabled = true
	_box(Vector3(1.4, 0.04, 0.5), Vector3(0, 0.99, 0.0), _led_material)
	# Luz de cultivo bajo la barra de LED.
	_grow_light = OmniLight3D.new()
	_grow_light.position = Vector3(0, 0.88, 0.05)
	_grow_light.omni_range = 2.2
	_grow_light.shadow_enabled = true
	add_child(_grow_light)
	# Almohadillas (pillows) en dos filas de tres.
	for i: int in PILLOWS:
		var material: StandardMaterial3D = _material(Color(0.93, 0.9, 0.82), 0.95)
		_pillow_materials.append(material)
		_box(Vector3(0.2, 0.09, 0.2), _pillow_position(i) + Vector3(0, 0.08, 0), material)
	# Gotas de agua.
	_drops = CPUParticles3D.new()
	_drops.position = Vector3(0, 0.75, 0.0)
	_drops.emitting = false
	_drops.one_shot = true
	_drops.amount = 60
	_drops.lifetime = 0.8
	_drops.explosiveness = 0.6
	_drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_drops.emission_box_extents = Vector3(0.6, 0.02, 0.3)
	_drops.direction = Vector3.DOWN
	_drops.initial_velocity_min = 0.4
	_drops.initial_velocity_max = 0.8
	_drops.gravity = Vector3(0, -3.5, 0)
	var drop_mesh: SphereMesh = SphereMesh.new()
	drop_mesh.radius = 0.012
	drop_mesh.height = 0.03
	var drop_material: StandardMaterial3D = _material(Color(0.55, 0.8, 1.0, 0.85), 0.05)
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mesh.material = drop_material
	_drops.mesh = drop_mesh
	add_child(_drops)

func _build_plants() -> void:
	var is_lettuce: bool = _crop_id != "mizuna"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	for i: int in PILLOWS:
		var plant: Node3D = Node3D.new()
		plant.position = _pillow_position(i) + Vector3(0, 0.13, 0)
		add_child(plant)
		_plants.append(plant)
		var count: int = LEAVES + 5 if is_lettuce else LEAVES + 5
		for k: int in count:
			# En la lechuga, las últimas hojas forman el corazón: más pequeñas y más rectas.
			var inner: bool = k >= LEAVES
			var leaf: MeshInstance3D = MeshInstance3D.new()
			var mesh: SphereMesh = SphereMesh.new()
			var color: Color
			if is_lettuce:
				# Lechuga romana roja 'Outredgeous': hojas anchas, rojo vino con centro verde.
				mesh.radius = 0.05 if inner else 0.075 * rng.randf_range(0.85, 1.15)
				mesh.height = 0.15 if inner else 0.21 * rng.randf_range(0.85, 1.1)
				color = Color(0.32, 0.04, 0.1).lerp(Color(0.3, 0.45, 0.15), 0.45 if inner else rng.randf() * 0.2)
			else:
				# Mizuna: hojas finas y largas, verde claro.
				mesh.radius = 0.02
				mesh.height = 0.3 * rng.randf_range(0.8, 1.15)
				color = Color(0.32, 0.72, 0.26).lerp(Color(0.6, 0.85, 0.35), rng.randf() * 0.5)
			mesh.material = _material(color, 0.6)
			leaf.mesh = mesh
			# Las hojas salen del centro en roseta, inclinadas hacia afuera.
			var angle: float = TAU * float(k) / float(LEAVES) + rng.randf_range(-0.3, 0.3)
			var tilt: float = deg_to_rad(rng.randf_range(42.0, 68.0) if is_lettuce else rng.randf_range(25.0, 62.0))
			if inner:
				tilt *= 0.45
			leaf.rotation = Vector3(tilt, angle, 0)
			leaf.position = Vector3(sin(angle), 0, cos(angle)) * (0.02 if inner else 0.06) + Vector3(0, 0.06, 0)
			leaf.scale = Vector3(1.0, 1.0, 0.35)
			plant.add_child(leaf)

func _pillow_position(index: int) -> Vector3:
	var column: int = index % 3
	var row: int = index / 3
	return Vector3((column - 1) * 0.42, 0.0, -0.17 + row * 0.36)

func _box(size: Vector3, position_value: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position_value
	add_child(instance)
	return instance

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
