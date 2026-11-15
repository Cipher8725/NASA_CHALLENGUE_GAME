class_name DomeEnergyPanel
extends Control

## Panel de la consola del domo: el jugador elige cuánta energía desviar
## al escudo en tres niveles (BAJO, MEDIO, MÁXIMO).
##
## Se elige con el ratón o con las teclas 1, 2 y 3; Escape cancela. Cada
## botón muestra la energía que se gasta y el escudo que se gana con la carga
## actual. La estructura vive en `scenes/ui/dome_energy_panel.tscn`; este
## script solo rellena textos y emite la elección (no toca el GameManager:
## eso lo hace `DomeConsole`).

## El jugador eligió un nivel (1, 2 o 3).
signal level_chosen(level: int)
## El jugador cerró el panel sin elegir.
signal cancelled

@onready var _info_label: Label = %InfoLabel
@onready var _buttons: Array[Button] = [%Level1Button, %Level2Button, %Level3Button]
@onready var _cancel_button: Button = %CancelButton

var _console: DomeConsole = null

func _ready() -> void:
	for i: int in _buttons.size():
		_buttons[i].pressed.connect(_choose.bind(i + 1))
	_cancel_button.pressed.connect(_cancel)

## Rellena los textos con los datos de la consola.
func setup(console: DomeConsole) -> void:
	_console = console
	_refresh()
	show_guide.call_deferred(false)

func _process(_delta: float) -> void:
	# La energía sigue cargando mientras el panel está abierto.
	_refresh()

func _input(event: InputEvent) -> void:
	# Mientras se lee el tutorial, las teclas son del tutorial.
	if get_tree().get_first_node_in_group(GuideOverlay.GROUP) != null:
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1, KEY_KP_1:
			_choose(1)
		KEY_2, KEY_KP_2:
			_choose(2)
		KEY_3, KEY_KP_3:
			_choose(3)
		_:
			return
	get_viewport().set_input_as_handled()

## Tutorial del panel del domo (la primera vez que se abre; Cómo jugar lo fuerza).
func show_guide(force: bool = true) -> GuideOverlay:
	return GuideOverlay.start(self, "consola_domo", [
		GuideOverlay.step(tr("Consola del domo"),
			tr("Aquí conviertes [b]energía[/b] en [b]escudo[/b]. El escudo protege la base de la radiación y de las tormentas solares."), %InfoLabel),
		GuideOverlay.step(tr("Elige un nivel"),
			tr("Nivel 1 usa el 25 % de la energía, nivel 2 el 50 % y nivel 3 toda. Pulsa el botón o las teclas [b]1[/b], [b]2[/b] o [b]3[/b]."), %Level1Button),
		GuideOverlay.step(tr("Cuidado con la energía"),
			tr("Si gastas mucha energía, las consolas y los paneles tardan en recuperarse. [b]Esc[/b] cierra sin desviar nada."), %CancelButton),
	], true, force)

# --- Métodos privados ---

func _refresh() -> void:
	if _console == null:
		return
	var game: GameManager = GameManager.get_instance()
	_info_label.text = tr("Energía: %d%%   ·   Escudo: %d%%") % [
		roundi(game.get_resource_percentage(GameManager.RESOURCE_ENERGY)),
		roundi(game.get_resource_percentage(GameManager.RESOURCE_SHIELD))]
	for i: int in _buttons.size():
		var level: int = i + 1
		var fraction: float = _console.level_fractions[i] if i < _console.level_fractions.size() else 0.0
		_buttons[i].text = tr("[%d]  NIVEL %d · %s — %d%% de la energía\n−%d energía   →   +%d escudo") % [
			level, level, tr(DomeConsole.LEVEL_NAMES[i]), roundi(fraction * 100.0),
			roundi(_console.get_level_energy(level)), roundi(_console.get_level_shield_gain(level))]

func _choose(level: int) -> void:
	level_chosen.emit(level)

func _cancel() -> void:
	cancelled.emit()
