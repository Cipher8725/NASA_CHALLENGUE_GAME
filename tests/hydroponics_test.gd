extends Node

## Test de la produccion de alimentos en la hidroponia.
##
## Comprueba que:
##  * El catalogo de cultivos de la CSA existe y trae fuentes y fecha de descarga.
##  * El minijuego se abre desde la consola de comida.
##  * Al ganar, la comida sube.
##  * Regar (agua) y la luz (energia) gastan los recursos de la mision.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _run() -> void:
	var failures: int = 0
	failures += _test_catalogo_cultivos()
	failures += await _test_minigame()
	failures += await _test_consumo_recursos()
	print("=== RESULTADO HIDROPONIA: %s ===" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(0 if failures == 0 else 1)

## El catalogo de cultivos de la CSA debe existir y traer datos con fuente.
func _test_catalogo_cultivos() -> int:
	var failures: int = 0
	var ruta: String = "res://resources/hidroponia/cultivos.json"
	failures += _check("Existe el JSON de cultivos", FileAccess.file_exists(ruta))
	if not FileAccess.file_exists(ruta):
		return failures
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not (datos is Dictionary):
		return _check("El JSON de cultivos es un objeto válido", false)
	var mapa: Dictionary = datos as Dictionary
	var tiene_fuentes: bool = mapa.has("fuentes") and (mapa.get("fuentes", []) as Array).size() > 0
	failures += _check("El JSON de cultivos tiene 'fuentes'", tiene_fuentes)
	failures += _check("El JSON de cultivos tiene 'fecha_descarga'", str(mapa.get("fecha_descarga", "")) != "")
	var cultivos: Array = mapa.get("cultivos", []) as Array
	failures += _check("El JSON tiene 3 o 4 cultivos", cultivos.size() >= 3 and cultivos.size() <= 4)
	for item: Variant in cultivos:
		var cultivo: Dictionary = item as Dictionary
		var nombre: String = str(cultivo.get("nombre", ""))
		failures += _check("El cultivo '%s' tiene días hasta cosechar" % nombre, int(cultivo.get("dias_hasta_cosechar", 0)) > 0)
		failures += _check("El cultivo '%s' tiene nutrientes" % nombre, str(cultivo.get("nutrientes", "")) != "")
		failures += _check("El cultivo '%s' tiene rango de luz" % nombre, float(cultivo.get("luz_maxima_porcentaje", 0.0)) > float(cultivo.get("luz_minima_porcentaje", 0.0)))
		failures += _check("El cultivo '%s' tiene rango de agua" % nombre, float(cultivo.get("agua_maxima_porcentaje", 0.0)) > float(cultivo.get("agua_minima_porcentaje", 0.0)))
	return failures

## El minijuego se abre desde la consola y hace crecer la comida al ganar.
func _test_minigame() -> int:
	var failures: int = 0
	var game: GameManager = GameManager.get_instance()
	if game == null:
		return _check("El GameManager esta disponible", false)

	# La consola de comida debe existir en la hidroponia y tener el recurso food.
	var consola: ResourceConsole = _buscar_consola_comida()
	failures += _check("Existe la consola de comida en la hidroponía", consola != null)
	if consola == null:
		return failures
	failures += _check("La consola de comida usa el recurso 'food'", consola.resource_type == GameManager.RESOURCE_FOOD)

	# El gestor debe reconocer el minijuego de la comida.
	var gestor: RepairMinigameManager = get_tree().get_first_node_in_group("repair_minigames") as RepairMinigameManager
	if gestor == null:
		return _check("El gestor de minijuegos esta disponible", false)
	failures += _check("El gestor tiene minijuego para la comida", gestor.has_minigame_for(GameManager.RESOURCE_FOOD))

	# Abrir el minijuego desde la consola.
	var abierto: bool = gestor.open_minigame(consola)
	failures += _check("El minijuego se abre desde la consola", abierto)
	if not abierto:
		return failures
	var minigame: HydroponicsMinigame = gestor.get_active_minigame() as HydroponicsMinigame
	failures += _check("El minijuego abierto es el de hidroponía", minigame != null)
	if minigame == null:
		return failures
	# Se anula la espera del panel de resultado: el test no debe depender
	# del reloj real (en headless los fotogramas pasan muy rapido).
	minigame.result_display_time = 0.0
	failures += _check("El minijuego tiene cultivos de la CSA", minigame.get_crop_count() >= 3)
	failures += _check("El minijuego ha elegido un cultivo", not minigame.get_cultivo().is_empty())

	# Con los controles en rango la planta crece.
	var cultivo: Dictionary = minigame.get_cultivo()
	var luz: float = (float(cultivo.get("luz_minima_porcentaje", 0.0)) + float(cultivo.get("luz_maxima_porcentaje", 100.0))) / 200.0
	var agua: float = (float(cultivo.get("agua_minima_porcentaje", 0.0)) + float(cultivo.get("agua_maxima_porcentaje", 100.0))) / 200.0
	minigame.set_controles(luz, agua)
	failures += _check("Los controles en rango son válidos para el cultivo", minigame.esta_en_rango())

	# Fuera de rango la planta pierde crecimiento.
	minigame.set_crecimiento(0.5)
	minigame.set_controles(0.02, 0.02)
	failures += _check("Fuera de rango el cultivo no está bien", not minigame.esta_en_rango())

	# Al llegar al 100 % el minijuego termina con éxito y la comida sube.
	# Primero se deja hueco: si la comida está al máximo no puede subir.
	game.consume_resource(GameManager.RESOURCE_FOOD, 60.0)
	var comida_antes: float = game.get_resource_level(GameManager.RESOURCE_FOOD)
	minigame.set_crecimiento(0.99)
	minigame.set_controles(luz, agua)
	minigame._process(0.2)
	# Al terminar, el gestor lo libera: se comprueba el estado ANTES de esperar.
	failures += _check("El minijuego termina al llegar al 100 %", minigame.is_finished())
	# Se espera a que el gestor repare la comida.
	for _i: int in range(30):
		await get_tree().process_frame
	var comida_despues: float = game.get_resource_level(GameManager.RESOURCE_FOOD)
	failures += _check("La comida sube al completar el minijuego", comida_despues > comida_antes)
	return failures

## Regar y encender la luz gastan agua y energía de la mision.
func _test_consumo_recursos() -> int:
	var failures: int = 0
	var game: GameManager = GameManager.get_instance()
	if game == null:
		return _check("El GameManager esta disponible", false)

	var packed: PackedScene = load("res://scenes/ui/minigame_hydroponics.tscn") as PackedScene
	var minigame: HydroponicsMinigame = packed.instantiate() as HydroponicsMinigame
	if minigame == null:
		return _check("El minijuego de hidroponía se instancia", false)
	add_child(minigame)
	minigame.result_display_time = 0.05
	minigame.begin()
	await get_tree().process_frame

	var cultivo: Dictionary = minigame.get_cultivo()
	var luz: float = (float(cultivo.get("luz_minima_porcentaje", 0.0)) + float(cultivo.get("luz_maxima_porcentaje", 100.0))) / 200.0
	var agua: float = (float(cultivo.get("agua_minima_porcentaje", 0.0)) + float(cultivo.get("agua_maxima_porcentaje", 100.0))) / 200.0
	minigame.set_controles(luz, agua)

	var agua_antes: float = game.get_resource_level(GameManager.RESOURCE_WATER)
	var energia_antes: float = game.get_resource_level(GameManager.RESOURCE_ENERGY)
	for _i: int in range(10):
		minigame._process(0.05)
	var agua_despues: float = game.get_resource_level(GameManager.RESOURCE_WATER)
	var energia_despues: float = game.get_resource_level(GameManager.RESOURCE_ENERGY)
	failures += _check("Regar consume agua", agua_despues < agua_antes)
	failures += _check("La luz consume energía", energia_despues < energia_antes)

	minigame.queue_free()
	return failures

# --- Utilidades ---

## Busca la consola de comida en el árbol de la estación.
func _buscar_consola_comida() -> ResourceConsole:
	var pending: Array[Node] = [get_tree().current_scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
			if child is ResourceConsole:
				var consola: ResourceConsole = child as ResourceConsole
				if consola.resource_type == GameManager.RESOURCE_FOOD:
					return consola
	return null

func _check(label: String, condition: bool) -> int:
	if not condition:
		print("  [FALLO] ", label)
		return 1
	print("  [OK]   ", label)
	return 0
