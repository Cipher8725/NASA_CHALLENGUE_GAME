extends Node
# Prueba de medallas y del Certificado de Astronauta Junior (con un archivo de progreso aparte).

var _fails: int = 0

func _ready() -> void:
	PlayerProgress.use_file("user://progreso_prueba.cfg")
	PlayerProgress.reset()
	_check(PlayerProgress.get_medal(PlayerProgress.BASE) == PlayerProgress.NONE, "al empezar no hay medallas")
	_check(not PlayerProgress.has_certificate(), "al empezar no hay certificado")
	# Reglas de cada medalla.
	_check(PlayerProgress.medal_for_base(70.0) == PlayerProgress.GOLD and PlayerProgress.medal_for_base(40.0) == PlayerProgress.SILVER \
		and PlayerProgress.medal_for_base(10.0) == PlayerProgress.BRONZE, "medalla de la base según los recursos")
	_check(PlayerProgress.medal_for_stars(1) == PlayerProgress.BRONZE and PlayerProgress.medal_for_stars(3) == PlayerProgress.GOLD, "medalla según las estrellas")
	# Se guarda la mejor medalla.
	_check(PlayerProgress.award(PlayerProgress.ROVER, PlayerProgress.SILVER), "se gana plata en el rover")
	_check(not PlayerProgress.award(PlayerProgress.ROVER, PlayerProgress.BRONZE), "un bronce después no baja la medalla")
	_check(PlayerProgress.get_medal(PlayerProgress.ROVER) == PlayerProgress.SILVER, "queda la mejor medalla")
	# Biblioteca: 1 libro bronce, 4 plata.
	PlayerProgress.mark_book_read("sistema_solar")
	_check(PlayerProgress.get_medal(PlayerProgress.LIBRARY) == PlayerProgress.BRONZE, "1 libro leído da bronce")
	PlayerProgress.mark_book_read("sistema_solar")
	_check(PlayerProgress.get_books_read() == 1, "el mismo libro no cuenta dos veces")
	for book: String in ["tierra_luna", "a", "b"]:
		PlayerProgress.mark_book_read(book)
	_check(PlayerProgress.get_medal(PlayerProgress.LIBRARY) == PlayerProgress.SILVER, "4 libros leídos dan plata")
	# Certificado.
	PlayerProgress.award(PlayerProgress.BASE, PlayerProgress.GOLD)
	_check(PlayerProgress.missing_for_certificate() == [PlayerProgress.LAUNCH], "falta solo el despegue")
	PlayerProgress.award_and_notify(PlayerProgress.LAUNCH, PlayerProgress.BRONZE)
	_check(PlayerProgress.has_certificate() and not PlayerProgress.get_certificate_date().is_empty(), "con los tres módulos se gana el certificado y se guarda la fecha")
	var pause: PauseMenu = PauseMenu.get_instance()
	_check(pause != null and pause.is_toast_visible(), "aparece el aviso de medalla")

	# Carnet: medallas y botón del certificado.
	var editor: CardEditor = (load("res://scenes/card_editor.tscn") as PackedScene).instantiate() as CardEditor
	add_child(editor)
	await get_tree().process_frame
	var row: HBoxContainer = editor.get_node("%Row") as HBoxContainer
	_check((row.get_child(0).get_node("Icon") as MedalIcon).medal == PlayerProgress.GOLD, "el carnet muestra el oro de la base")
	_check(not (editor.get_node("%CertificateButton") as Button).disabled, "el carnet habilita VER CERTIFICADO")
	editor.queue_free()

	# Certificado.
	var certificate: Certificate = (load("res://scenes/certificate.tscn") as PackedScene).instantiate() as Certificate
	add_child(certificate)
	await get_tree().process_frame
	var medals: HBoxContainer = certificate.get_node("%Medals") as HBoxContainer
	_check((medals.get_child(1).get_node("Icon") as MedalIcon).medal == PlayerProgress.SILVER, "el certificado muestra la plata del rover")
	_check((certificate.get_node("%Seal") as MedalIcon).medal == PlayerProgress.BRONZE, "el sello toma la medalla más baja de los tres módulos")
	certificate.queue_free()

	PlayerProgress.reset()
	PlayerProgress.use_file(PlayerProgress.PATH)
	print("=== RESULTADO MEDALLAS Y CERTIFICADO: %s ===" % ("TODO OK" if _fails == 0 else "%d FALLOS" % _fails))
	get_tree().quit()

func _check(ok: bool, what: String) -> void:
	print(("[OK] " if ok else "[FALLO] ") + what)
	if not ok:
		_fails += 1
