class_name PauseMenu
extends CanvasLayer

## Menú de pausa (Autoload "Pause").
##
## Esc o P (acción `pause_game`) abren la pausa en la Base Lunar, el Taller del
## Rover y las simulaciones de despegue. `get_tree().paused = true` congela el
## GameManager (recursos, reloj, puntos), las emergencias, el jugador y la
## cuenta atrás; este nodo sigue funcionando (`process_mode` ALWAYS).
##
## Une las dos pausas que tenía el proyecto:
##   * Base Lunar: Continuar, Reiniciar misión y Volver al menú (que abandona la
##     misión con `GameManager.abort_mission()`); no se abre con un minijuego o
##     el panel del domo abiertos (el jugador tiene el control bloqueado) ni con
##     la misión ya terminada.
##   * Parche de tutoriales: Cómo jugar (repite el tutorial de la escena),
##     idioma (vía el autoload `Lang`), volumen de música y efectos y el aviso
##     de medalla nueva (`show_medal`, lo usa `PlayerProgress`).

## Escenas donde se puede pausar (en el menú, la biblioteca y el carnet Esc ya tiene su uso).
const PAUSABLE_SCENES: PackedStringArray = [
	"res://scenes/main.tscn",
	"res://scenes/rover_workshop.tscn",
	"res://scenes/simulacion_despegue.tscn",
	"res://scenes/simulacion_despegue_3d.tscn",
]
const MOON_BASE_SCENE: String = "res://scenes/main.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const TUTORIAL_SCENE: String = "res://scenes/ui/tutorial.tscn"

## Se emite al pausar (true) y al reanudar (false).
signal pause_changed(paused: bool)

var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _tutorial: Tutorial

@onready var _root: Control = %Root
@onready var _panel: Control = %Panel
@onready var _continue: Button = %ContinueButton
@onready var _how_to: Button = %HowToButton
@onready var _restart: Button = %RestartButton
@onready var _language: Button = %LanguageButton
@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _menu: Button = %MenuButton
@onready var _toast: Control = %Toast
@onready var _toast_medal: MedalIcon = %ToastMedal
@onready var _toast_title: Label = %ToastTitle
@onready var _toast_text: Label = %ToastText
var _toast_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_toast.visible = false
	_continue.pressed.connect(close)
	_how_to.pressed.connect(show_how_to_play)
	_restart.pressed.connect(restart_scene)
	_language.pressed.connect(_toggle_language)
	_menu.pressed.connect(go_to_main_menu)
	_music.value_changed.connect(_on_music_changed)
	_sfx.value_changed.connect(_on_sfx_changed)

static func get_instance() -> PauseMenu:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Pause") as PauseMenu if tree != null else null

## ¿Se puede pausar ahora?
func can_pause() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or not PAUSABLE_SCENES.has(scene.scene_file_path):
		return false
	var manager: RepairMinigameManager = get_tree().get_first_node_in_group("repair_minigames") as RepairMinigameManager
	if manager != null and manager.is_open():
		return false
	if get_tree().get_first_node_in_group("tutorial") != null or GuideOverlay.is_active(get_tree()):
		return false
	if scene.scene_file_path == MOON_BASE_SCENE:
		# Misión terminada: la pantalla de resultado ya ofrece reiniciar.
		var game: GameManager = GameManager.get_instance()
		if game != null:
			var state: GameManager.MissionState = game.get_mission_state()
			if state == GameManager.MissionState.FAILED or state == GameManager.MissionState.COMPLETED:
				return false
		# Con el panel del domo abierto el jugador tiene el control bloqueado.
		var player: HabitatPlayer = get_tree().get_first_node_in_group("player") as HabitatPlayer
		if player != null and not player.is_input_enabled():
			return false
	return true

func is_open() -> bool:
	return _root.visible

## ¿La partida está en pausa?
func is_paused() -> bool:
	return is_open() and get_tree().paused

func open() -> void:
	if is_open():
		return
	_mouse_before = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	_refresh()
	_root.visible = true
	_panel.visible = true
	_restart.visible = _is_moon_base()
	AudioManager.sfx(&"ui_open", -4.0)
	_continue.grab_focus()
	pause_changed.emit(true)

func close() -> void:
	if not is_open():
		return
	if _tutorial != null:
		_tutorial.queue_free()
		_tutorial = null
	_root.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(_mouse_before)
	AudioManager.sfx(&"ui_close", -4.0)
	pause_changed.emit(false)

## Nombres de la pausa anterior de la Base Lunar.
func pause() -> void:
	open()

func resume() -> void:
	close()

## "Cómo jugar": repite el tutorial paso a paso de la escena actual (base, taller o despegue).
## Si la escena no tiene uno, muestra el tutorial general de páginas.
func show_how_to_play() -> void:
	_panel.visible = false
	var scene: Node = get_tree().current_scene
	var guide: GuideOverlay = null
	if scene != null and scene.has_method("show_guide"):
		guide = scene.call("show_guide", true) as GuideOverlay
	if guide != null:
		_root.visible = false
		guide.finished.connect(func(_skipped: bool) -> void:
			_root.visible = true
			_panel.visible = true
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_continue.grab_focus())
		return
	_tutorial = (load(TUTORIAL_SCENE) as PackedScene).instantiate() as Tutorial
	_root.add_child(_tutorial)
	_tutorial.closed.connect(func() -> void:
		_tutorial = null
		_panel.visible = true
		_continue.grab_focus())

## Reinicia la escena actual (en la Base Lunar, la misión desde el principio).
func restart_scene() -> void:
	_root.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func go_to_main_menu() -> void:
	var leaving_base: bool = _is_moon_base()
	close()
	# La misión se abandona: el GameManager (autoload) deja de consumir recursos.
	if leaving_base:
		var game: GameManager = GameManager.get_instance()
		if game != null:
			game.abort_mission()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

## Aviso de medalla nueva (arriba, unos segundos). Si además se ganó el certificado, lo dice.
func show_medal(module: StringName, medal: int, certificate_unlocked: bool) -> void:
	_toast_medal.medal = medal
	_toast_title.text = tr(PlayerProgress.MEDAL_TITLES[medal])
	var text: String = tr(String(PlayerProgress.MODULE_NAMES.get(module, "")))
	if certificate_unlocked:
		text += "\n" + tr("¡Ganaste el Certificado de Astronauta Junior! Míralo en «Mi carnet».")
	_toast_text.text = text
	_toast.visible = true
	_toast.modulate.a = 0.0
	AudioManager.sfx(&"medal")
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(5.0 if certificate_unlocked else 3.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)

func is_toast_visible() -> bool:
	return _toast.visible

func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game")):
		return
	if is_open():
		if _tutorial == null:
			close()
			get_viewport().set_input_as_handled()
	elif can_pause():
		open()
		get_viewport().set_input_as_handled()

func _is_moon_base() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.scene_file_path == MOON_BASE_SCENE

func _refresh() -> void:
	_language.text = "Español" if Lang.is_english() else "English"
	var audio: AudioManager = AudioManager.get_instance()
	if audio != null:
		_music.set_value_no_signal(audio.get_music_volume() * 100.0)
		_sfx.set_value_no_signal(audio.get_sfx_volume() * 100.0)

func _toggle_language() -> void:
	Lang.toggle_language()
	_refresh()

func _on_music_changed(value: float) -> void:
	var audio: AudioManager = AudioManager.get_instance()
	if audio != null:
		audio.set_music_volume(value / 100.0)

func _on_sfx_changed(value: float) -> void:
	var audio: AudioManager = AudioManager.get_instance()
	if audio != null:
		audio.set_sfx_volume(value / 100.0)
		audio.play(&"ui_click", 0.0, false)
