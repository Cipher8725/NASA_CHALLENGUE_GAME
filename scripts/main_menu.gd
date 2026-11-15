class_name MainMenu
extends Control

## Menú principal del juego (primera escena al ejecutar).
##
## Diseño "Nasa Space 2": a la izquierda JUGAR, BIBLIOTECA, SALIR y MI CARNET.
## JUGAR abre el panel "Menú de juego" con las cuatro actividades:
##   * Base lunar → la base de la Luna (`scenes/main.tscn`).
##   * Armado del rover → Taller del Rover Perseverance.
##   * Simulación de despegue → lanzamiento del Apolo 8 en un Saturno V.
##   * Exploración lunar → todavía sin escena: se muestra como "Próximamente".
##
## El menú no conoce la lógica de cada actividad: solo cambia de escena.

## Base lunar (la partida principal con GameManager).
const LEVEL_MOON: String = "res://scenes/main.tscn"
## Exploración lunar: vacía mientras no exista su escena.
const LEVEL_EXPLORATION: String = ""
## Taller del Rover: armar y desarmar el rover Perseverance de la NASA.
const WORKSHOP_SCENE: String = "res://scenes/rover_workshop.tscn"
## Pantalla para crear el carnet de astronauta.
const CARD_SCENE: String = "res://scenes/card_editor.tscn"
## Biblioteca de estudio (9 libros en 3 niveles).
const LIBRARY_SCENE: String = "res://scenes/biblioteca.tscn"
## Simulación del despegue del Apolo 8.
const LAUNCH_SCENE: String = "res://scenes/simulacion_despegue_3d.tscn"
## Versión 2D anterior (cabina en fotos), por si la computadora no puede con el 3D.
const LAUNCH_SCENE_2D: String = "res://scenes/simulacion_despegue.tscn"

@onready var _level_panel: Control = %LevelPanel
@onready var _start_button: TextureButton = %StartButton
@onready var _moon_button: TextureButton = %MoonButton
@onready var _exploration_button: TextureButton = %ExplorationButton
@onready var _exploration_soon: Label = %ExplorationSoon

func _ready() -> void:
	AudioManager.music(&"menu")
	# El menú se maneja con el ratón visible (el jugador lo captura al entrar).
	# En modo headless (pruebas) el servidor de pantalla es un mock: se omite.
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_language_textures()
	_exploration_button.disabled = LEVEL_EXPLORATION.is_empty()
	_exploration_soon.visible = _exploration_button.disabled
	_apply_language()
	(%LaunchChooser as Control).visible = false
	_hide_level_panel()
	show_guide.call_deferred(false)

func _unhandled_input(event: InputEvent) -> void:
	# Escape cierra primero el selector de despegue y luego el panel "Menú de juego".
	if event.is_action_pressed("ui_cancel") and is_launch_chooser_visible():
		_hide_launch_chooser()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _level_panel.visible:
		_hide_level_panel()
		get_viewport().set_input_as_handled()

## ¿Está abierto el panel "Menú de juego"?
func is_level_panel_visible() -> bool:
	return _level_panel.visible

## ¿Se puede jugar ya la Exploración lunar?
func is_exploration_available() -> bool:
	return not _exploration_button.disabled

## Ruta de la base lunar (la usa el test del menú).
func get_moon_level_path() -> String:
	return LEVEL_MOON

# --- Botones ---

## JUGAR abre o cierra el panel de actividades.
func _on_start_pressed() -> void:
	if _level_panel.visible:
		_hide_level_panel()
	else:
		_show_level_panel()

func _on_moon_pressed() -> void:
	_load_level(LEVEL_MOON)

func _on_workshop_pressed() -> void:
	_load_level(WORKSHOP_SCENE)

## Simulación de despegue: deja elegir entre la versión 3D y la 2D clásica.
func _on_launch_pressed() -> void:
	_show_launch_chooser()

func _on_launch_3d_pressed() -> void:
	_load_level(LAUNCH_SCENE)

func _on_launch_2d_pressed() -> void:
	_load_level(LAUNCH_SCENE_2D)

## ¿Está abierto el selector 3D / 2D de la simulación de despegue?
func is_launch_chooser_visible() -> bool:
	return (%LaunchChooser as Control).visible

## Rutas de las dos versiones de la simulación (las usa el test del menú).
func get_launch_scenes() -> PackedStringArray:
	return PackedStringArray([LAUNCH_SCENE, LAUNCH_SCENE_2D])

func _show_launch_chooser() -> void:
	var chooser: Control = %LaunchChooser as Control
	chooser.visible = true
	chooser.modulate.a = 0.0
	create_tween().tween_property(chooser, "modulate:a", 1.0, 0.15)
	(%Launch3DButton as Button).grab_focus()

func _hide_launch_chooser() -> void:
	(%LaunchChooser as Control).visible = false
	if _level_panel.visible:
		(%LaunchButton as TextureButton).grab_focus()

func _on_exploration_pressed() -> void:
	_load_level(LEVEL_EXPLORATION)

func _on_library_pressed() -> void:
	_load_level(LIBRARY_SCENE)

func _on_card_pressed() -> void:
	_load_level(CARD_SCENE)

## Texto del botón de idioma: siempre muestra el OTRO idioma.
func _apply_language() -> void:
	(%LanguageButton as Button).text = "Español" if Lang.is_english() else "English"

func _on_quit_pressed() -> void:
	get_tree().quit()

## Alterna español / inglés. Los textos se traducen solos; las imágenes de
## los botones (con el texto dibujado) se cambian por su versión en inglés.
func _on_language_pressed() -> void:
	Lang.toggle_language()
	_apply_language_textures()
	_apply_language()

# --- Idioma ---

## Propiedades de textura que pueden llevar texto dibujado.
const _TEXTURE_PROPERTIES: Array[String] = ["texture_normal", "texture_hover", "texture_pressed", "texture_disabled", "texture_focused"]

## Pone en cada botón e imagen del menú la textura del idioma activo. Las
## versiones en inglés están en una subcarpeta `en/` junto a la original
## (p. ej. `ai_assets/ui/menu/en/jugar.png`); si no existe, se usa la original.
func _apply_language_textures() -> void:
	for node: Node in find_children("*", "", true, false):
		if node is TextureButton:
			for property: String in _TEXTURE_PROPERTIES:
				_swap_texture(node, property)
		elif node is TextureRect:
			_swap_texture(node, "texture")

func _swap_texture(node: Node, property: String) -> void:
	var meta_key: StringName = StringName("original_" + property)
	if not node.has_meta(meta_key):
		node.set_meta(meta_key, node.get(property))
	var original: Texture2D = node.get_meta(meta_key) as Texture2D
	if original == null or original.resource_path.is_empty():
		return
	var texture: Texture2D = original
	if Lang.is_english():
		var english_path: String = original.resource_path.get_base_dir().path_join("en").path_join(original.resource_path.get_file())
		if ResourceLoader.exists(english_path):
			texture = load(english_path) as Texture2D
	node.set(property, texture)

# --- Panel ---

func _show_level_panel() -> void:
	_level_panel.visible = true
	_level_panel.modulate.a = 0.0
	create_tween().tween_property(_level_panel, "modulate:a", 1.0, 0.2)
	_moon_button.grab_focus()
	show_level_guide.call_deferred(false)

func _hide_level_panel() -> void:
	_level_panel.visible = false
	_start_button.grab_focus()

## Cambia a la escena indicada.
func _load_level(path: String) -> void:
	if path.is_empty():
		return
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("MainMenu: no se pudo abrir %s (error %d)" % [path, error])

# --- Tutoriales ---

## Tutorial del menú principal (la primera vez que se abre el juego).
func show_guide(force: bool = true) -> GuideOverlay:
	return GuideOverlay.start(self, "menu_principal", [
		GuideOverlay.step(tr("¡Hola, futuro astronauta!"),
			tr("Bienvenido a [b]NaSA-GAME[/b], el entrenamiento para astronautas junior. Te mostramos el menú en unos pasos. Puedes [b]saltar el tutorial[/b] cuando quieras.")),
		GuideOverlay.step(tr("Jugar"),
			tr("Aquí están las misiones: [b]Base Lunar[/b], [b]Armado del rover[/b] y [b]Simulación de despegue[/b]."), %StartButton),
		GuideOverlay.step(tr("Biblioteca"),
			tr("Libros con datos reales de la NASA, en tres niveles. Leer libros también da medalla."), %LibraryButton),
		GuideOverlay.step(tr("Mi carnet"),
			tr("Crea tu carnet de astronauta con tu nombre y tu foto. Ahí verás tus [b]medallas[/b] y tu [b]certificado[/b]."), %CardButton),
		GuideOverlay.step(tr("Idioma"),
			tr("Cambia entre español e inglés en cualquier momento."), %LanguageButton),
	], false, force)

## Tutorial del panel "Menú de juego" (la primera vez que se abre).
func show_level_guide(force: bool = true) -> GuideOverlay:
	if not _level_panel.visible:
		return null
	return GuideOverlay.start(self, "menu_juego", [
		GuideOverlay.step(tr("Base Lunar"),
			tr("Cuida la base durante la misión: recursos, consolas, minijuegos y emergencias reales. [b]Empieza por aquí.[/b]"), %MoonButton),
		GuideOverlay.step(tr("Armado del rover"),
			tr("Arma el rover [b]Perseverance[/b] pieza por pieza y aprende para qué sirve cada una."), %WorkshopButton),
		GuideOverlay.step(tr("Simulación de despegue"),
			tr("Vive el despegue del [b]Apolo 8[/b] con datos reales: puedes elegir la versión 3D o la 2D."), %LaunchButton),
		GuideOverlay.step(tr("Tu certificado"),
			tr("Gana una medalla en [b]Base, Rover y Despegue[/b] para conseguir el [b]Certificado de Astronauta Junior[/b].")),
	], false, force)
