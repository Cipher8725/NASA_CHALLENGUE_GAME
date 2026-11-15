extends Node

## Test del domo y del nuevo sistema de energía.
##
## Comprueba:
##  - La misión ya no termina por tiempo (no hay límite de 3 minutos).
##  - La energía no se descarga sola y los paneles solares la suben despacio.
##  - El corto circuito deja la energía a 0 sin perder la partida, bloquea la
##    carga solar y gasta más oxígeno; se repara pulsando E junto al
##    generador (consola de energía invisible + minijuego de cables).
##  - La consola del domo desvía toda la energía al escudo.
##  - El domo tiene colisión propia, cubre la estación y no toca ninguna
##    colisión de la estación (no rompe nada).

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _run() -> void:
	var failures: int = 0
	var game: GameManager = GameManager.get_instance()
	var main_scene: Node = get_tree().current_scene.get_node_or_null("Main")
	if game == null or main_scene == null:
		print("  [FALLO] Escena principal o gestor no disponibles")
		get_tree().quit(1)
		return
	await _wait_active(game)

	failures += await _test_endless_mission(game)
	failures += await _test_solar_charge(game)
	failures += await _test_short_circuit(game, main_scene)
	failures += _test_dome_console(game, main_scene)
	failures += await _test_dome_collision(main_scene)

	print("=== RESULTADO DOMO Y ENERGIA: %s ===" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(0 if failures == 0 else 1)

## Sin límite de tiempo: pasada la duración antigua la misión sigue activa.
func _test_endless_mission(game: GameManager) -> int:
	var failures: int = 0
	failures += _check("La misión no tiene límite de tiempo", game.config.endless_mission)
	# Se acorta la duración solo en memoria para no esperar 3 minutos.
	var original: float = game.config.mission_duration
	game.config.mission_duration = 0.5
	var timer: SceneTreeTimer = get_tree().create_timer(1.5)
	while timer.time_left > 0.0:
		_keep_alive(game)
		await get_tree().process_frame
	var state: GameManager.MissionState = game.get_mission_state()
	failures += _check("Pasado el tiempo antiguo la misión sigue en marcha",
		state == GameManager.MissionState.ACTIVE or state == GameManager.MissionState.CRITICAL)
	failures += _check("El ciclo de radiación se repite (progreso < 1)", game.get_mission_progress() < 1.0)
	game.config.mission_duration = original
	return failures

## Los paneles cargan despacio y la energía no se descarga sola.
func _test_solar_charge(game: GameManager) -> int:
	var failures: int = 0
	failures += _check("Sin descarga continua de energía", is_zero_approx(game.config.energy_decay_rate))
	game.consume_resource(GameManager.RESOURCE_ENERGY, 50.0)
	var before: float = game.get_resource_level(GameManager.RESOURCE_ENERGY)
	await _wait_seconds(game, 1.0)
	var gained: float = game.get_resource_level(GameManager.RESOURCE_ENERGY) - before
	failures += _check("Los paneles suben la energía (+%.2f en 1 s)" % gained, gained > 0.1)
	failures += _check("La carga solar es lenta (< 1 por segundo)", gained < 1.0)
	return failures

## El corto circuito tumba la energía y se repara con E junto al generador.
func _test_short_circuit(game: GameManager, main_scene: Node) -> int:
	var failures: int = 0
	game.trigger_emergency(GameManager.EMERGENCY_SHORT_CIRCUIT, 0.5)
	failures += _check("El corto circuito queda activo", game.is_short_circuit_active())
	failures += _check("Toda la energía cae a 0", is_zero_approx(game.get_resource_level(GameManager.RESOURCE_ENERGY)))

	var oxygen_before: float = game.get_resource_level(GameManager.RESOURCE_OXYGEN)
	await _wait_seconds(game, 1.0, false)
	var state: GameManager.MissionState = game.get_mission_state()
	failures += _check("Sin energía la misión NO se pierde",
		state == GameManager.MissionState.ACTIVE or state == GameManager.MissionState.CRITICAL)
	failures += _check("Con el corto los paneles no cargan",
		is_zero_approx(game.get_resource_level(GameManager.RESOURCE_ENERGY)))
	var oxygen_used: float = oxygen_before - game.get_resource_level(GameManager.RESOURCE_OXYGEN)
	failures += _check("Con el corto el oxígeno baja más rápido (%.2f/s)" % oxygen_used,
		oxygen_used > game.config.oxygen_decay_rate * 1.2)

	# Jugador junto al generador, por fuera de su caja de colisión.
	var room: Node3D = main_scene.get_node("Habitat/Interior/IMG_sala_del_generador") as Node3D
	var energy_console: ResourceConsole = room.get_node("ConsoleEnergy") as ResourceConsole
	failures += _check("La consola de energía está dentro del generador", energy_console != null)
	failures += _check("La consola de energía es invisible", energy_console != null and not energy_console.panel_visible)
	var player: HabitatPlayer = main_scene.get_node("Player") as HabitatPlayer
	player.global_position = energy_console.global_position + room.global_transform.basis.x.normalized() * 3.0 + Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	for _i: int in range(10):
		await get_tree().physics_frame

	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	for _i: int in range(10):
		await get_tree().process_frame
	var release: InputEventKey = InputEventKey.new()
	release.physical_keycode = KEY_E
	release.pressed = false
	Input.parse_input_event(release)

	var manager: RepairMinigameManager = get_tree().get_first_node_in_group("repair_minigames") as RepairMinigameManager
	var cables: CableRepairMinigame = manager.get_active_minigame() as CableRepairMinigame
	failures += _check("Pulsar E en el generador abre el minijuego de energía", cables != null)
	if cables == null:
		return failures
	cables.result_display_time = 0.05
	var order: Array[int] = cables.get_socket_order()
	for cable: int in range(order.size()):
		cables.press_cable(cable)
		cables.press_socket(order.find(cable))
	await get_tree().create_timer(0.4).timeout
	failures += _check("El minijuego repara el corto circuito", not game.is_short_circuit_active())
	failures += _check("La energía vuelve tras la reparación", game.get_resource_level(GameManager.RESOURCE_ENERGY) > 0.0)
	return failures

## La consola del domo desvía energía al escudo en tres niveles (25/50/100 %).
func _test_dome_console(game: GameManager, main_scene: Node) -> int:
	var failures: int = 0
	var dome_console: DomeConsole = main_scene.get_node_or_null("Habitat/Interior/IMG_sala_del_generador/ConsoleDome") as DomeConsole
	failures += _check("Consola del domo en la sala del generador", dome_console != null)
	if dome_console == null:
		return failures
	failures += _check("La consola tiene 3 niveles", dome_console.level_fractions.size() == 3)
	for level: int in [1, 2, 3]:
		game.restore_resource(GameManager.RESOURCE_ENERGY, 1000.0)
		game.restore_resource(GameManager.RESOURCE_SHIELD, 1000.0)
		game.consume_resource(GameManager.RESOURCE_ENERGY, 20.0)
		game.consume_resource(GameManager.RESOURCE_SHIELD, 90.0)
		var energy: float = game.get_resource_level(GameManager.RESOURCE_ENERGY)
		var shield: float = game.get_resource_level(GameManager.RESOURCE_SHIELD)
		var fraction: float = dome_console.level_fractions[level - 1]
		var gained: float = dome_console.divert_level(level)
		failures += _check("Nivel %d: el escudo sube %.0f%% de la energía (+%.1f)" % [level, fraction * 100.0, gained],
			is_equal_approx(game.get_resource_level(GameManager.RESOURCE_SHIELD), shield + energy * fraction * game.config.dome_transfer_efficiency))
		failures += _check("Nivel %d: se gasta %.0f%% de la energía" % [level, fraction * 100.0],
			is_equal_approx(game.get_resource_level(GameManager.RESOURCE_ENERGY), energy * (1.0 - fraction)))
	failures += _check("Sin energía la consola no hace nada", is_zero_approx(dome_console.divert_level(3)))
	return failures

## El domo tiene colisión propia, cierra la estación y no toca nada.
func _test_dome_collision(main_scene: Node) -> int:
	var failures: int = 0
	var dome: StationDome = main_scene.get_node_or_null("Habitat/StationDome") as StationDome
	failures += _check("Domo instanciado en el hábitat", dome != null)
	if dome == null:
		return failures
	failures += _check("La cáscara del domo tiene colisión (%d triángulos)" % dome.get_collision_triangle_count(),
		dome.get_collision_triangle_count() > 1000)
	await get_tree().physics_frame

	var dome_body: StaticBody3D = dome.get_node("DomeBody") as StaticBody3D
	var space: PhysicsDirectSpaceState3D = dome.get_world_3d().direct_space_state

	# Ninguna colisión de la estación (salvo el bloque base, en el que se
	# apoya) puede tocar la cáscara del domo.
	var touching: Array[String] = []
	var checked: int = 0
	for node: Node in main_scene.get_node("Habitat").find_children("*", "CollisionShape3D", true, false):
		var shape_node: CollisionShape3D = node as CollisionShape3D
		if shape_node.shape == null or shape_node.disabled or dome.is_ancestor_of(shape_node):
			continue
		if String(shape_node.get_path()).contains("StationPlatform/BaseCube"):
			continue
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.transform = shape_node.global_transform
		if shape_node.shape is ConcavePolygonShape3D:
			# Las formas cóncavas no sirven como consulta: se usa su caja envolvente.
			var box: BoxShape3D = BoxShape3D.new()
			var bounds: AABB = shape_node.shape.get_debug_mesh().get_aabb()
			box.size = bounds.size
			query.shape = box
			query.transform = shape_node.global_transform * Transform3D(Basis.IDENTITY, bounds.get_center())
		else:
			query.shape = shape_node.shape
		query.collide_with_areas = false
		checked += 1
		for hit: Dictionary in space.intersect_shape(query, 8):
			if hit.get("collider") == dome_body:
				touching.append(String(shape_node.get_path()))
	failures += _check("Ninguna de %d colisiones de la estación toca el domo" % checked, touching.is_empty())
	for path: String in touching:
		print("    toca el domo: ", path)

	# Desde el centro de la estación, mirando hacia fuera a 1 m de altura, el
	# primer obstáculo lejano es el domo, antes de que se acabe el bloque base.
	var center: Vector3 = dome.global_position + Vector3(0.0, 1.0, 0.0)
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var hit: Dictionary = _ray_to_dome(space, dome_body, center, direction, 140.0)
		failures += _check("El domo cierra la estación hacia %s" % direction, not hit.is_empty())
	# Hacia arriba desde el tejado del generador (y ~ 5 m) el domo está alto.
	var up: Dictionary = _ray_to_dome(space, dome_body, center + Vector3(0.0, 5.0, 0.0), Vector3.UP, 60.0)
	failures += _check("El domo cubre la estación por arriba (%.1f m)" % (Vector3(up.get("position", Vector3.ZERO)).y),
		not up.is_empty() and Vector3(up["position"]).y > 20.0)
	return failures

# --- Utilidades ---

## Lanza un rayo ignorando todo lo que no sea el domo.
func _ray_to_dome(space: PhysicsDirectSpaceState3D, dome_body: StaticBody3D, from: Vector3, direction: Vector3, length: float) -> Dictionary:
	var exclude: Array[RID] = []
	for _i: int in range(32):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * length)
		query.exclude = exclude
		query.hit_back_faces = true
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return {}
		if hit.get("collider") == dome_body:
			return hit
		exclude.append(hit["rid"])
	return {}

## Espera `seconds` reponiendo los recursos para que la misión no falle.
func _wait_seconds(game: GameManager, seconds: float, keep_alive: bool = true) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	while timer.time_left > 0.0:
		if keep_alive:
			_keep_alive(game)
		await get_tree().process_frame

## Repone los recursos que no se están probando (oxígeno, agua, escudo, comida).
func _keep_alive(game: GameManager) -> void:
	game.restore_resource(GameManager.RESOURCE_OXYGEN, 100.0)
	game.restore_resource(GameManager.RESOURCE_WATER, 100.0)
	game.restore_resource(GameManager.RESOURCE_FOOD, 100.0)

func _wait_active(game: GameManager) -> void:
	for _i: int in range(600):
		if game.get_mission_state() == GameManager.MissionState.ACTIVE:
			return
		await get_tree().process_frame

func _check(label: String, condition: bool) -> int:
	print("  [%s] %s" % ["OK" if condition else "FALLO", label])
	return 0 if condition else 1
