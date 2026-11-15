extends Node

## Test de la Simulación de despegue en 3D (misma lógica que la 2D + mundo 3D).

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	var failures: int = 0
	var sim: LaunchSimulation3D = (load("res://scenes/simulacion_despegue_3d.tscn") as PackedScene).instantiate() as LaunchSimulation3D
	failures += _check("La escena 3D tiene el script LaunchSimulation3D", sim != null)
	add_child(sim)
	await get_tree().process_frame
	sim.set_process(false)
	for piece: String in LaunchSimulation3D.ROCKET_PIECES:
		failures += _check("El Saturno V 3D tiene la pieza %s" % piece, sim.get_node_or_null("World/Rocket/" + piece) != null)
	for model: String in ["PanelPrincipal3D", "Escotilla3D", "DSKY3D"]:
		failures += _check("La cabina tiene el modelo 3D %s (Hunyuan 3D)" % model, sim.find_child(model, true, false) != null)
	failures += _check("Empieza con la vista exterior", not sim.is_cockpit_view())
	sim._set_view(1)
	failures += _check("La vista de cabina usa la cámara de la cabina", sim.is_cockpit_view() and (sim.get_node("%CockpitCamera") as Camera3D).current)
	sim._set_view(0)
	# Cuenta regresiva: la 1.ª etapa se enciende antes de T-0.
	sim.press_action()
	sim.step(5.0)
	sim._update_visuals(0.016)
	failures += _check("A T−5 s los motores F-1 ya están encendidos", sim.is_fire_on("s_ic"))
	sim.step(5.0)
	sim.press_action()
	for i: int in 400:
		if sim.is_waiting_for_order():
			break
		sim.step(0.5)
	sim._update_visuals(0.016)
	var pivot: Node3D = sim.get_node("%EarthPivot") as Node3D
	failures += _check("La Tierra queda 65,75 km más abajo al separar la S-IC", absf(-pivot.position.y - (6371000.0 + 7.6 + 65750.0)) < 50.0)
	failures += _check("El cohete ya va inclinado hacia el este", sim.rocket_pitch_deg(sim.get_mission_time()) > 60.0)
	failures += _check("Esperando la orden, el fuego está apagado", not sim.is_fire_on("s_ic"))
	sim.press_action()
	sim._update_visuals(0.016)
	failures += _check("La S-IC se suelta del cohete 3D", sim.get_node("World/Rocket").get_node_or_null("s_ic") == null)
	failures += _check("Ahora empuja la S-II con su fuego", sim.is_fire_on("s_ii"))
	sim._on_retry_pressed()
	failures += _check("Repetir vuelve a montar la S-IC", sim.get_node("World/Rocket").get_node_or_null("s_ic") != null)
	sim.queue_free()
	_finish(failures)

func _finish(failures: int) -> void:
	print("=== RESULTADO DESPEGUE 3D: %s ===" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(0 if failures == 0 else 1)

func _check(label: String, condition: bool) -> int:
	if condition:
		print("  [OK]   ", label)
		return 0
	print("  [FALLO] ", label)
	return 1
