extends Node
# Prueba del tutorial "Control de misión" y del menú de pausa.

var _fails: int = 0

func _ready() -> void:
	# --- Tutorial ---
	var tutorial: Tutorial = (load("res://scenes/ui/tutorial.tscn") as PackedScene).instantiate() as Tutorial
	add_child(tutorial)
	await get_tree().process_frame
	_check(tutorial.get_page_count() == 5, "el tutorial tiene 5 páginas")
	tutorial.next_page()
	tutorial.next_page()
	_check(tutorial.get_page() == 2, "Siguiente avanza de página")
	tutorial.previous_page()
	_check(tutorial.get_page() == 1, "Atrás vuelve una página")
	var closed: Array[bool] = [false]
	tutorial.closed.connect(func() -> void: closed[0] = true)
	GameSettings.set_value(Tutorial.SETTINGS_SECTION, Tutorial.SETTINGS_KEY, false)
	tutorial.close()
	_check(closed[0] and Tutorial.was_seen(), "al cerrarlo avisa y queda marcado como visto")

	# --- Pausa ---
	var pause: PauseMenu = PauseMenu.get_instance()
	_check(pause != null, "existe el Autoload Pause")
	if pause != null:
		_check(not pause.can_pause(), "fuera de la base, el taller y el despegue no se pausa")
		pause.open()
		_check(pause.is_open() and get_tree().paused, "al abrir la pausa el juego se detiene")
		var music: HSlider = pause.get_node("%MusicSlider") as HSlider
		music.value = 30.0
		_check(absf(AudioManager.get_instance().get_music_volume() - 0.3) < 0.02, "el control de música cambia el volumen")
		var before: String = Localization.get_language()
		(pause.get_node("%LanguageButton") as Button).pressed.emit()
		_check(Localization.get_language() != before, "el botón de idioma cambia el idioma")
		Localization.set_language(before)
		pause.show_how_to_play()
		await get_tree().process_frame
		_check(get_tree().get_first_node_in_group("tutorial") != null, "Cómo jugar abre el tutorial dentro de la pausa")
		pause.close()
		await get_tree().process_frame
		_check(not pause.is_open() and not get_tree().paused, "Continuar reanuda el juego")
		AudioManager.get_instance().set_music_volume(AudioManager.DEFAULT_MUSIC_VOLUME)
	print("=== RESULTADO PAUSA Y TUTORIAL: %s ===" % ("TODO OK" if _fails == 0 else "%d FALLOS" % _fails))
	get_tree().quit()

func _check(ok: bool, what: String) -> void:
	print(("[OK] " if ok else "[FALLO] ") + what)
	if not ok:
		_fails += 1
