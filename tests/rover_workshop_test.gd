extends Node

## Test del Taller del Rover (entrenamiento de ensamblaje).
##
## Comprueba que:
##  * el recurso del rover carga y trae las 16 piezas con textos e instrucción,
##  * cada pieza existe como nodo dentro del modelo 3D oficial,
##  * al empezar, todas las piezas están SEPARADAS en la mesa (lejos de su lugar),
##  * soltar una pieza lejos de su lugar no cuenta como error,
##  * soltarla en su lugar fuera de orden no se acepta, vuelve a la mesa y es error,
##  * en modo guiado se ve la silueta de la pieza que toca; en evaluación, no,
##  * armar en orden completa el rover y da las estrellas esperadas,
##  * "empezar de nuevo" devuelve todas las piezas a la mesa.

const TRAY_MIN_DISTANCE: float = 1.0

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	var failures: int = 0

	# --- Datos ---
	var data: RoverData = load("res://resources/rover_perseverance.tres") as RoverData
	failures += _check("El recurso del rover carga", data != null)
	if data == null:
		_finish(failures)
		return
	failures += _check("El rover tiene 16 piezas", data.piezas.size() == 16)
	var complete: bool = true
	var orders: Dictionary = {}
	for piece: RoverPieceData in data.piezas:
		if piece.nombre.is_empty() or piece.nombre_en.is_empty() or piece.descripcion.is_empty() or piece.dato.is_empty() or piece.conexion_mision.is_empty() or piece.instruccion.is_empty() or piece.material.is_empty() or piece.importancia.is_empty() or piece.icono == null:
			complete = false
		orders[piece.orden] = true
	failures += _check("Todas las piezas tienen nombre, material, importancia, instrucción e ícono", complete)
	failures += _check("Cada pieza tiene un orden de armado distinto", orders.size() == data.piezas.size())

	# --- Escena ---
	var packed: PackedScene = load("res://scenes/rover_workshop.tscn") as PackedScene
	var workshop: RoverWorkshop = packed.instantiate() as RoverWorkshop if packed != null else null
	failures += _check("La escena del taller se instancia con el script RoverWorkshop", workshop != null)
	if workshop == null:
		_finish(failures)
		return
	# Sin animaciones: las piezas se mueven al instante durante la prueba.
	workshop.rover_data = data.duplicate() as RoverData
	workshop.rover_data.duracion_movimiento = 0.0
	workshop.promote_card = false  # la prueba no toca el carnet del jugador
	add_child(workshop)
	await get_tree().process_frame

	var ordered: Array[RoverPieceData] = data.get_piezas_en_orden()
	failures += _check("Las 16 piezas se encontraron en el modelo 3D", workshop.get_found_piece_count() == 16)
	failures += _check("El taller empieza eligiendo modo", workshop.get_phase() == RoverWorkshop.Phase.CHOOSING)
	var separated: bool = true
	for piece: RoverPieceData in ordered:
		if workshop.is_piece_installed(piece.id) or workshop.get_piece_position(piece.id).distance_to(workshop.get_home_position(piece.id)) < TRAY_MIN_DISTANCE:
			separated = false
	failures += _check("Todas las piezas empiezan separadas en la mesa", separated)
	failures += _check("No se puede armar antes de elegir modo", not workshop.place_piece(ordered[0].id))

	# --- Modo guiado ---
	workshop.start_training(RoverWorkshop.Mode.GUIDED)
	failures += _check("El modo guiado empieza el armado", workshop.get_phase() == RoverWorkshop.Phase.ASSEMBLING)
	failures += _check("La primera pieza es la del orden 1", workshop.get_next_piece() == ordered[0])
	failures += _check("En modo guiado se ve la silueta de la primera pieza", workshop.is_ghost_visible(ordered[0].id) and not workshop.is_ghost_visible(ordered[1].id))

	var far: Vector3 = workshop.get_home_position(ordered[0].id) + Vector3(3.0, 0.0, 3.0)
	failures += _check("Soltar una pieza lejos de su lugar no la instala", not workshop.drop_piece(ordered[0].id, far))
	failures += _check("…y no cuenta como error", workshop.get_errors() == 0)

	failures += _check("Una pieza fuera de orden no encaja", not workshop.place_piece(ordered[5].id))
	failures += _check("…cuenta como error", workshop.get_errors() == 1)
	failures += _check("…y vuelve a la mesa", workshop.get_piece_position(ordered[5].id).is_equal_approx(workshop.get_tray_position(ordered[5].id)))

	failures += _check("La pieza correcta encaja en su lugar", workshop.place_piece(ordered[0].id) and workshop.is_piece_installed(ordered[0].id))
	failures += _check("La silueta pasa a la siguiente pieza", workshop.is_ghost_visible(ordered[1].id) and not workshop.is_ghost_visible(ordered[0].id))
	var all_ok: bool = true
	for i: int in range(1, ordered.size()):
		if not workshop.place_piece(ordered[i].id):
			all_ok = false
	failures += _check("Armar en orden acepta todas las piezas", all_ok)
	failures += _check("El rover queda armado", workshop.get_phase() == RoverWorkshop.Phase.DONE)
	failures += _check("Con 1 error se ganan 2 estrellas", workshop.get_stars() == 2)

	# --- Reinicio y evaluación ---
	workshop.restart()
	var back_on_tray: bool = true
	for piece: RoverPieceData in ordered:
		if workshop.is_piece_installed(piece.id) or not workshop.get_piece_position(piece.id).is_equal_approx(workshop.get_tray_position(piece.id)):
			back_on_tray = false
	failures += _check("Empezar de nuevo devuelve todas las piezas a la mesa", back_on_tray and workshop.get_errors() == 0)
	workshop.start_training(RoverWorkshop.Mode.EVALUATION)
	failures += _check("En evaluación no hay silueta de ayuda", not workshop.is_ghost_visible(ordered[0].id))
	for piece: RoverPieceData in ordered:
		workshop.place_piece(piece.id)
	failures += _check("Evaluación sin errores da 3 estrellas", workshop.get_phase() == RoverWorkshop.Phase.DONE and workshop.get_stars() == 3)

	_finish(failures)

func _finish(failures: int) -> void:
	print("=== RESULTADO TALLER DEL ROVER: %s ===" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(0 if failures == 0 else 1)

func _check(label: String, condition: bool) -> int:
	if condition:
		print("  [OK]   ", label)
		return 0
	print("  [FALLO] ", label)
	return 1
