extends Node

## Test de la Biblioteca de estudio y su lector.

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	var failures: int = 0
	var books: Array[Dictionary] = Library.load_catalog(Library.CATALOG_PATH)
	failures += _check("El catálogo tiene 11 libros", books.size() == 11)
	var levels: Dictionary = {}
	var complete: bool = true
	for b: Dictionary in books:
		levels[b["nivel"]] = int(levels.get(b["nivel"], 0)) + 1
		if (b["paginas"] as Array).size() != 3 or (b["fuentes"] as Array).is_empty() or not ResourceLoader.exists(str(b["portada"])):
			complete = false
	failures += _check("Libros por nivel (3 Básico, 4 Intermedio, 4 Avanzado)", levels.get("Básico", 0) == 3 and levels.get("Intermedio", 0) == 4 and levels.get("Avanzado", 0) == 4)
	failures += _check("Cada libro tiene 3 páginas, fuentes y portada", complete)

	var lib: Library = (load("res://scenes/biblioteca.tscn") as PackedScene).instantiate() as Library
	add_child(lib)
	await get_tree().process_frame
	var button: TextureButton = lib.get_book_button("tierra_luna")
	failures += _check("Los 11 libros están en la estantería", lib.get_book_button("trajes_espaciales") != null and button != null)
	failures += _check("Los libros nuevos están en la estantería", lib.get_book_button("cuerpo_espacio") != null and lib.get_book_button("clima_espacio") != null)
	failures += _check("Los libros están en su estante (Básico arriba)", button != null and button.position.is_equal_approx(Vector2(616, 165)))
	failures += _check("Empieza mostrando la estantería", not lib.is_reading())
	button.pressed.emit()
	await get_tree().process_frame
	failures += _check("Al pulsar un libro se abre el lector", lib.is_reading() and lib.get_current_book_id() == "tierra_luna")
	failures += _check("El libro tiene 3 dobles páginas (portada, páginas, fuentes)", lib.get_spread_count() == 3)
	failures += _check("La primera doble página muestra el título", (lib.get_node("%LeftTitle") as Label).text == "La Tierra y la Luna")
	failures += _check("Anterior está desactivado al inicio", (lib.get_node("%PrevButton") as Button).disabled)
	lib.next_spread()
	lib.next_spread()
	lib.next_spread()
	failures += _check("Siguiente no pasa de la última página", lib.get_spread_index() == 2 and (lib.get_node("%NextButton") as Button).disabled)
	failures += _check("El contador dice 3 / 3", (lib.get_node("%PageLabel") as Label).text == "3 / 3")
	failures += _check("La última doble página tiene las fuentes", (lib.get_node("%LeftTitle") as Label).text == "Fuentes" and "nasa.gov" in (lib.get_node("%LeftText") as RichTextLabel).text)
	lib.close_book()
	failures += _check("Cerrar libro vuelve a la estantería", not lib.is_reading())
	lib.open_book("despegue_orbita")
	lib.next_spread()
	failures += _check("El libro del despegue muestra el diagrama del cohete", (lib.get_node("%LeftImage") as TextureRect).texture != null)
	lib.next_spread()
	failures += _check("Al terminar ofrece practicar en la simulación", (lib.get_node("%ActivityButton") as Button).visible)
	# El libro del clima espacial ofrece practicar en la base lunar.
	lib.open_book("clima_espacio")
	lib.next_spread()
	lib.next_spread()
	failures += _check("El libro del clima espacial ofrece practicar en la base lunar", (lib.get_node("%ActivityButton") as Button).visible)
	failures += _check("Un libro que no existe no se abre", not lib.open_book("no_existe"))
	lib.queue_free()
	_finish(failures)

func _finish(failures: int) -> void:
	print("=== RESULTADO BIBLIOTECA: %s ===" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(0 if failures == 0 else 1)

func _check(label: String, condition: bool) -> int:
	if condition:
		print("  [OK]   ", label)
		return 0
	print("  [FALLO] ", label)
	return 1
