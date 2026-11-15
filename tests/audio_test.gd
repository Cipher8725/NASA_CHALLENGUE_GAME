extends Node
# Prueba del sonido: Autoload, buses, volumen guardado, efectos y música.

const SOUNDS: Array[StringName] = [&"alarm", &"console", &"countdown", &"door", &"fail", &"hit", &"liftoff",
	&"miss", &"page", &"plug", &"rumble_loop", &"shutter", &"snap", &"spark", &"staging", &"steam",
	&"success", &"ui_click", &"water", &"wrong", &"medal"]

var _fails: int = 0

func _ready() -> void:
	var audio: AudioManager = AudioManager.get_instance()
	_check(audio != null, "existe el Autoload Audio")
	if audio == null:
		_end()
		return
	_check(AudioServer.get_bus_index(AudioManager.BUS_MUSIC) >= 0 and AudioServer.get_bus_index(AudioManager.BUS_SFX) >= 0, "existen los buses Music y SFX")
	var missing: Array[String] = []
	for sound: StringName in SOUNDS:
		if not AudioManager.has_sound(sound):
			missing.append(String(sound))
	_check(missing.is_empty(), "existen todos los efectos %s" % str(missing))
	# Volumen: se aplica y se guarda.
	var music_before: float = audio.get_music_volume()
	audio.set_music_volume(0.25)
	_check(absf(audio.get_music_volume() - 0.25) < 0.01, "el volumen de la música cambia")
	_check(absf(GameSettings.get_float("audio", "musica", -1.0) - 0.25) < 0.01, "el volumen se guarda en ajustes.cfg")
	audio.set_music_volume(music_before)
	# Efectos.
	var count: int = audio.get_play_count()
	audio.play(&"hit")
	_check(audio.get_play_count() == count + 1 and audio.get_last_sound() == &"hit", "suena un efecto")
	# Los botones suenan solos al pulsarse.
	var button: Button = Button.new()
	add_child(button)
	button.pressed.emit()
	_check(audio.get_last_sound() == &"ui_click", "un botón suena al pulsarse")
	# Música en bucle.
	audio.play_music(&"menu")
	await get_tree().process_frame
	_check(audio.get_music_name() == &"menu", "suena la música del menú")
	audio.play_music(&"base")
	await get_tree().process_frame
	_check(audio.get_music_name() == &"base", "cambia a la música de la base")
	# Bucle del motor.
	audio.start_loop(&"rumble_loop")
	_check(audio.is_loop_playing(&"rumble_loop"), "el rugido del motor suena en bucle")
	audio.stop_loop(&"rumble_loop", 0.1)
	_check(not audio.is_loop_playing(&"rumble_loop"), "el rugido se detiene")
	audio.stop_music()
	_end()

func _end() -> void:
	print("=== RESULTADO AUDIO: %s ===" % ("TODO OK" if _fails == 0 else "%d FALLOS" % _fails))
	get_tree().quit()

func _check(ok: bool, what: String) -> void:
	print(("[OK] " if ok else "[FALLO] ") + what)
	if not ok:
		_fails += 1
