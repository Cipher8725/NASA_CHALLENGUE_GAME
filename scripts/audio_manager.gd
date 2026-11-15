class_name AudioManager
extends Node

## Sonido del juego (Autoload "Audio").
##
## - Música de fondo en bucle con fundido entre pistas (`play_music`).
## - Efectos cortos (`play`) desde un grupo de reproductores reutilizables, y efectos
##   con posición 3D (`play_at`) para puertas y consolas.
## - Dos buses propios, "Music" y "SFX", con volumen guardado en `user://ajustes.cfg`.
## - Se engancha solo a lo que aparece en el árbol: todos los botones suenan al pulsarse,
##   las puertas al abrirse, el GameManager con alarmas y el final de misión, el taller
##   del rover, el despegue y los minijuegos. Así los scripts de juego no dependen del audio.
##
## Todos los sonidos son propios: se sintetizan con `tools/generar_audio.py`.

const SFX_PATH: String = "res://assets/audio/sfx/%s.wav"
const MUSIC_PATHS: Dictionary = {
	&"menu": "res://assets/audio/music/music_menu.ogg",
	&"base": "res://assets/audio/music/music_base.ogg",
}
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const POOL_SIZE: int = 10
const MUSIC_FADE: float = 1.2
## Volumen inicial (0.0 a 1.0) si el jugador nunca lo cambió.
const DEFAULT_MUSIC_VOLUME: float = 0.6
const DEFAULT_SFX_VOLUME: float = 0.8
## Las alarmas no se repiten más seguido que esto (segundos).
const ALARM_COOLDOWN: float = 4.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name: StringName = &""
var _loops: Dictionary = {}
var _last_sound: StringName = &""
var _play_count: int = 0
var _last_alarm_ms: int = -100000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	set_music_volume(GameSettings.get_float("audio", "musica", DEFAULT_MUSIC_VOLUME), false)
	set_sfx_volume(GameSettings.get_float("audio", "efectos", DEFAULT_SFX_VOLUME), false)
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_pool.append(player)
	_music_a = _new_music_player()
	_music_b = _new_music_player()
	get_tree().node_added.connect(_on_node_added)
	# El GameManager es otro Autoload: puede estar listo antes o después que este.
	_connect_game_manager.call_deferred()

## Instancia del Autoload (null si el juego corre sin él, por ejemplo en una prueba aislada).
static func get_instance() -> AudioManager:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Audio") as AudioManager if tree != null else null

## Atajo estático para reproducir un efecto desde cualquier script.
static func sfx(sound: StringName, volume_db: float = 0.0) -> void:
	var audio: AudioManager = get_instance()
	if audio != null:
		audio.play(sound, volume_db)

## Atajo estático para cambiar la música (pista vacía = silencio).
static func music(track: StringName) -> void:
	var audio: AudioManager = get_instance()
	if audio == null:
		return
	if track == &"":
		audio.stop_music()
	else:
		audio.play_music(track)

# --- Efectos ---

## Reproduce un efecto corto (con una pequeña variación de tono para que no canse).
func play(sound: StringName, volume_db: float = 0.0, vary_pitch: bool = true) -> void:
	var stream: AudioStream = _get_stream(sound)
	if stream == null:
		return
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.96, 1.04) if vary_pitch else 1.0
	player.play()
	_last_sound = sound
	_play_count += 1

## Reproduce un efecto en una posición del mundo 3D (se oye más fuerte de cerca).
func play_at(sound: StringName, world_position: Vector3, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _get_stream(sound)
	var scene: Node = get_tree().current_scene
	if stream == null or scene == null:
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.volume_db = volume_db
	player.unit_size = 4.0
	player.max_distance = 25.0
	player.pitch_scale = randf_range(0.95, 1.05)
	scene.add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()
	_last_sound = sound
	_play_count += 1

## Alarma con espera mínima entre repeticiones.
func play_alarm() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_alarm_ms < int(ALARM_COOLDOWN * 1000.0):
		return
	_last_alarm_ms = now
	play(&"alarm", -2.0, false)

## Sonido en bucle (por ejemplo el rugido de los motores); se detiene con `stop_loop`.
func start_loop(sound: StringName, volume_db: float = 0.0) -> void:
	if _loops.has(sound):
		return
	var stream: AudioStreamWAV = (_get_stream(sound) as AudioStreamWAV)
	if stream == null:
		return
	var looped: AudioStreamWAV = stream.duplicate() as AudioStreamWAV
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looped.loop_begin = 0
	looped.loop_end = int(looped.get_length() * looped.mix_rate)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = looped
	player.bus = BUS_SFX
	player.volume_db = volume_db
	add_child(player)
	player.play()
	_loops[sound] = player

func stop_loop(sound: StringName, fade: float = 0.6) -> void:
	var player: AudioStreamPlayer = _loops.get(sound, null) as AudioStreamPlayer
	_loops.erase(sound)
	if player == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -40.0, fade)
	tween.tween_callback(player.queue_free)

func is_loop_playing(sound: StringName) -> bool:
	return _loops.has(sound)

func stop_all_loops() -> void:
	for sound: StringName in _loops.keys():
		stop_loop(sound, 0.3)

# --- Música ---

## Cambia la música de fondo con un fundido. Si ya suena esa pista, no hace nada.
func play_music(track: StringName) -> void:
	if track == _music_name and _music_a.playing:
		return
	_music_name = track
	var path: String = String(MUSIC_PATHS.get(track, ""))
	var stream: AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis if not path.is_empty() else null
	if stream == null:
		stop_music()
		return
	stream.loop = true
	# Se intercambian los reproductores: el viejo se apaga y el nuevo sube.
	var old: AudioStreamPlayer = _music_a
	_music_a = _music_b
	_music_b = old
	_fade(_music_b, -40.0, true)
	_music_a.stream = stream
	_music_a.volume_db = -40.0
	_music_a.play()
	_fade(_music_a, 0.0, false)

func stop_music() -> void:
	_music_name = &""
	_fade(_music_a, -40.0, true)
	_fade(_music_b, -40.0, true)

func get_music_name() -> StringName:
	return _music_name if _music_a != null and _music_a.playing else &""

# --- Volumen ---

func set_music_volume(linear: float, save: bool = true) -> void:
	_set_bus_volume(BUS_MUSIC, linear)
	if save:
		GameSettings.set_value("audio", "musica", clampf(linear, 0.0, 1.0))

func set_sfx_volume(linear: float, save: bool = true) -> void:
	_set_bus_volume(BUS_SFX, linear)
	if save:
		GameSettings.set_value("audio", "efectos", clampf(linear, 0.0, 1.0))

func get_music_volume() -> float:
	return _get_bus_volume(BUS_MUSIC)

func get_sfx_volume() -> float:
	return _get_bus_volume(BUS_SFX)

## Último efecto pedido y cuántos van (los usan las pruebas).
func get_last_sound() -> StringName:
	return _last_sound

func get_play_count() -> int:
	return _play_count

## ¿Existe el archivo de ese efecto?
static func has_sound(sound: StringName) -> bool:
	return ResourceLoader.exists(SFX_PATH % sound)

# --- Enganches automáticos ---

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button: BaseButton = node as BaseButton
		if not button.has_meta("sin_sonido"):
			button.pressed.connect(play.bind(&"ui_click", -4.0))
	elif node is SlidingDoor:
		var door: SlidingDoor = node as SlidingDoor
		door.opened.connect(func() -> void: play_at(&"door", door.global_position))
		door.closed.connect(func() -> void: play_at(&"door", door.global_position, -4.0))
		door.access_denied.connect(func(_reason: String) -> void: play(&"wrong"))
	elif node is AnimatedDoor:
		var animated: AnimatedDoor = node as AnimatedDoor
		animated.state_changed.connect(func(is_open: bool) -> void:
			play_at(&"door", animated.global_position, 0.0 if is_open else -4.0))
	elif node is RoverWorkshop:
		var workshop: RoverWorkshop = node as RoverWorkshop
		workshop.piece_installed.connect(func(_id: StringName) -> void: play(&"snap"))
		workshop.wrong_order.connect(func(_id: StringName, _expected: StringName) -> void: play(&"wrong"))
		workshop.training_completed.connect(func(_stars: int, _errors: int, _seconds: float) -> void: play(&"success"))
	elif node is LaunchSimulation:
		var launch: LaunchSimulation = node as LaunchSimulation
		launch.launched.connect(_on_launched)
		launch.maneuver_done.connect(func(_id: String, on_time: bool) -> void: play(&"hit" if on_time else &"miss"))
		launch.mission_completed.connect(_on_launch_completed)
		launch.tree_exiting.connect(stop_all_loops)
	elif node is RepairMinigame:
		var minigame: RepairMinigame = node as RepairMinigame
		minigame.finished.connect(func(success: bool) -> void: play(&"success" if success else &"fail"))
	elif node is Library:
		var library: Library = node as Library
		library.book_opened.connect(func(_id: String) -> void: play(&"page"))
	elif node is PhotoBooth:
		(node as PhotoBooth).photo_taken.connect(func(_photo: Image) -> void: play(&"shutter"))

func _connect_game_manager() -> void:
	var game: GameManager = GameManager.get_instance()
	if game == null:
		return
	game.emergency_triggered.connect(func(_type: StringName, _severity: float) -> void: play_alarm())
	game.resource_critical.connect(func(_type: StringName) -> void: play_alarm())
	game.mission_completed.connect(func(_score: float) -> void: play(&"success", 0.0, false))
	game.mission_failed.connect(func(_reason: String) -> void: play(&"fail", 0.0, false))

func _on_launched() -> void:
	play(&"liftoff", 0.0, false)
	start_loop(&"rumble_loop", -6.0)

func _on_launch_completed(_stars: int, _errors: int) -> void:
	stop_loop(&"rumble_loop", 2.0)
	play(&"success", 0.0, false)

# --- Interno ---

func _get_stream(sound: StringName) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound] as AudioStream
	var path: String = SFX_PATH % sound
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_streams[sound] = stream
	return stream

func _new_music_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = BUS_MUSIC
	add_child(player)
	return player

func _fade(player: AudioStreamPlayer, target_db: float, stop_after: bool) -> void:
	if player == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, MUSIC_FADE)
	if stop_after:
		tween.tween_callback(player.stop)

static func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")

static func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var value: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))

static func _get_bus_volume(bus_name: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))
