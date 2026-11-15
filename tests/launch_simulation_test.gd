extends Node

## Test de la Simulación de despegue del Apolo 8.
## Avanza la simulación con step() en vez de esperar en tiempo real.

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	var failures: int = 0
	var data: Dictionary = LaunchSimulation.load_data(LaunchSimulation.DATA_PATH)
	failures += _check("Los datos del Apolo 8 cargan", not data.is_empty() and (data["eventos"] as Array).size() >= 8)
	var sim: LaunchSimulation = (load("res://scenes/simulacion_despegue.tscn") as PackedScene).instantiate() as LaunchSimulation
	add_child(sim)
	await get_tree().process_frame
	sim.set_process(false)

	# Datos reales (NASA SP-4029): separación S-IC a 153,82 s, 65,75 km y 8 447 km/h.
	var t: Vector2 = sim.telemetry_at(153.82)
	failures += _check("Telemetría real en la separación de la 1.ª etapa", absf(t.x - 65.75) < 0.1 and absf(t.y - 8447.0) < 2.0)
	var orbit: Vector2 = sim.telemetry_at(800.0)
	failures += _check("En órbita: ~191 km y ~26 600 km/h", absf(orbit.x - 191.36) < 0.1 and absf(orbit.y - 26601.0) < 5.0)

	failures += _check("Empieza en la introducción", sim.get_phase() == LaunchSimulation.Phase.INTRO)
	sim.press_action()
	failures += _check("El botón inicia la cuenta regresiva", sim.get_phase() == LaunchSimulation.Phase.COUNTDOWN)
	sim.press_action()
	failures += _check("Despegar antes de tiempo es un error", sim.get_errors() == 1 and sim.get_phase() == LaunchSimulation.Phase.COUNTDOWN)
	sim.step(10.0)
	failures += _check("Con la cuenta en 0 espera la orden", sim.is_waiting_for_order())
	sim.press_action()
	failures += _check("¡Despegue! con la 1.ª etapa S-IC", sim.get_phase() == LaunchSimulation.Phase.FLIGHT and sim.get_current_stage() == "s_ic")
	failures += _check("Ventanas tapadas al despegar", not sim.are_windows_open())

	# Volar hasta la separación de la S-IC (153,82 s).
	_fly_until_wait(sim)
	failures += _check("El reloj se detiene en la separación de la S-IC", is_equal_approx(sim.get_mission_time(), 153.82) and sim.get_next_action_event()["id"] == "separar_sic")
	sim.press_action()
	failures += _check("Se suelta la S-IC y empuja la S-II", not sim.is_stage_attached("s_ic") and sim.get_current_stage() == "s_ii")

	# Torre de escape: si el jugador no responde, la computadora la suelta (error).
	_fly_until_wait(sim)
	sim.step(sim.late_limit_real + 0.1)
	failures += _check("Sin orden, la computadora suelta la torre y cuenta error", not sim.is_stage_attached("torre_escape") and sim.get_errors() == 2)
	failures += _check("Al soltar la torre se destapan las ventanas", sim.are_windows_open())

	# 2.ª etapa y apagado de la S-IVB.
	_fly_until_wait(sim)
	sim.press_action()
	failures += _check("Se suelta la S-II y empuja la S-IVB", not sim.is_stage_attached("s_ii") and sim.get_current_stage() == "s_ivb")
	_fly_until_wait(sim)
	sim.press_action()
	for i: int in 20:
		sim.step(1.0)
	failures += _check("Llega a la órbita y termina la misión", sim.get_phase() == LaunchSimulation.Phase.DONE)
	failures += _check("La S-IVB sigue unida (luego va a la Luna)", sim.is_stage_attached("s_ivb"))
	failures += _check("2 errores = 2 estrellas", sim.get_stars() == 2)
	failures += _check("Hay 4 vistas de la cabina", LaunchSimulation.VIEW_TEXTURES.size() == 4 and ResourceLoader.exists(LaunchSimulation.VIEW_TEXTURES[3]))
	sim.queue_free()
	_finish(failures)

## Avanza en pasos de 0,5 s reales hasta que el cohete espere una orden.
func _fly_until_wait(sim: LaunchSimulation) -> void:
	for i: int in 2000:
		if sim.is_waiting_for_order() or sim.get_phase() == LaunchSimulation.Phase.DONE:
			return
		sim.step(0.5)

func _finish(failures: int) -> void:
	print("=== RESULTADO SIMULACION DESPEGUE: %s ===" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(0 if failures == 0 else 1)

func _check(label: String, condition: bool) -> int:
	if condition:
		print("  [OK]   ", label)
		return 0
	print("  [FALLO] ", label)
	return 1
