extends Node

## Test del huerto hidropónico (comida, agua y energía).
##
## Comprueba los datos reales de cultivos, que el recurso COMIDA existe, que el
## minijuego gasta agua al regar y energía con la luz encendida, y que una
## cosecha completa termina con éxito y repone la comida.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()

func _run() -> void:
	var failures: int = 0
	var game: GameManager = GameManager.get_instance()

	# --- Datos reales ---
	var file: FileAccess = FileAccess.open(HydroponicsMinigame.CROPS_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
	failures += _check("cultivos.json tiene fuentes", (data.get("fuentes", []) as Array).size() >= 3)
	var studies: String = JSON.stringify(data)
	failures += _check("Cita OSD-745, OSD-780 y OSD-655", studies.contains("OSD-745") and studies.contains("OSD-780") and studies.contains("OSD-655"))
	failures += _check("Cita a la Agencia Espacial Canadiense", studies.contains("asc-csa.gc.ca"))

	# --- Recurso comida ---
	failures += _check("La comida es un recurso de la base", game.get_resource_max(GameManager.RESOURCE_FOOD) > 0.0)
	var manager: RepairMinigameManager = RepairMinigameManager.new()
	failures += _check("La comida tiene minijuego", manager.has_minigame_for(GameManager.RESOURCE_FOOD))
	manager.free()
	# Se instancia la sala (no se lee el .tscn como texto: en el juego exportado es binario).
	var room: Node = (load("res://scenes/rooms/room_hydroponics.tscn") as PackedScene).instantiate()
	var food_console: Node = room.find_child("ConsoleFood", true, false)
	failures += _check("La sala de hidroponía tiene la consola del huerto",
		food_console != null and StringName(food_console.get("resource_type")) == GameManager.RESOURCE_FOOD)
	room.free()

	# --- Minijuego ---
	var game_node: HydroponicsMinigame = (load("res://scenes/ui/minigame_hydroponics.tscn") as PackedScene).instantiate() as HydroponicsMinigame
	add_child(game_node)
	game_node.resource_type = GameManager.RESOURCE_FOOD
	game_node.begin()
	var crop: Dictionary = game_node.get_crop()
	failures += _check("Cultivo real elegido: %s (%d días)" % [crop.get("nombre", "?"), game_node.harvest_days()], game_node.harvest_days() == 33 or game_node.harvest_days() == 35)

	game.restore_resource(GameManager.RESOURCE_WATER, 1000.0)
	game.restore_resource(GameManager.RESOURCE_ENERGY, 1000.0)
	var water_before: float = game.get_resource_level(GameManager.RESOURCE_WATER)
	game_node.water()
	failures += _check("Sin luz no se puede regar", is_equal_approx(game.get_resource_level(GameManager.RESOURCE_WATER), water_before))
	game_node.select_light("azul")
	failures += _check("Luz azul (50:50) encendida", game_node.get_light() == "azul")
	game_node.water()
	failures += _check("Regar gasta agua de la base", game.get_resource_level(GameManager.RESOURCE_WATER) < water_before)

	var energy_before: float = game.get_resource_level(GameManager.RESOURCE_ENERGY)
	var result: Array[bool] = [false, false]
	game_node.finished.connect(func(ok: bool) -> void:
		result[0] = true
		result[1] = ok)
	# Simulación: se mantiene la humedad en la zona buena hasta la cosecha.
	for i: int in 200:
		if not game_node.is_running():
			break
		game_node.set_moisture(0.6)
		game_node._update_visuals(0.25)
	failures += _check("La luz gasta energía (%.1f)" % (energy_before - game.get_resource_level(GameManager.RESOURCE_ENERGY)), game.get_resource_level(GameManager.RESOURCE_ENERGY) < energy_before)
	failures += _check("La cosecha se completa", game_node.get_progress() >= 1.0)
	var garden: HydroponicsGarden3D = game_node.get_node("%Garden") as HydroponicsGarden3D
	failures += _check("Huerto 3D con 6 plantas", garden != null and garden.get_plant_count() == 6)
	failures += _check("Las plantas 3D crecieron hasta la cosecha", garden != null and garden.get_growth() >= 1.0)
	# _succeed() espera result_display_time antes de emitir `finished`.
	await get_tree().create_timer(game_node.result_display_time + 0.5).timeout
	failures += _check("El minijuego termina con éxito", result[0] and result[1])

	# --- Errores: agua de más ---
	var second: HydroponicsMinigame = (load("res://scenes/ui/minigame_hydroponics.tscn") as PackedScene).instantiate() as HydroponicsMinigame
	add_child(second)
	second.begin()
	second.select_light("rojo")
	second.set_moisture(0.95)
	second.water()
	failures += _check("Regar de más cuenta como error", second.get_errors() == 1)

	print("=== RESULTADO HIDROPONIA: %s ===" % ("TODO OK" if failures == 0 else "FALLOS (%d)" % failures))
	get_tree().quit(1 if failures > 0 else 0)

func _check(label: String, condition: bool) -> int:
	if condition:
		print("  [OK]   ", label)
		return 0
	print("  [FALLO] ", label)
	return 1
