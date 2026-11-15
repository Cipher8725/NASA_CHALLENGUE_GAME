class_name DomeConsole
extends ResourceConsole

## Consola del domo: desvía energía de la estación al escudo del domo.
##
## Es una `ResourceConsole` del recurso escudo (`shield`), así que el jugador
## la usa con la misma tecla de interacción. Al usarla se abre el panel
## `scenes/ui/dome_energy_panel.tscn`, donde el jugador elige uno de los
## TRES NIVELES de desvío (cuánta energía pasa al escudo). La conversión la
## hace `GameManager.divert_energy_to_dome(fracción)`; la energía gastada la
## vuelven a cargar poco a poco los paneles solares.

## Escena del panel de selección de nivel.
const PANEL_SCENE: String = "res://scenes/ui/dome_energy_panel.tscn"
## Nombre de cada nivel (índice 0 = nivel 1).
const LEVEL_NAMES: Array[String] = ["BAJO", "MEDIO", "MÁXIMO"]

## Fracción de la energía actual que desvía cada nivel (nivel 1, 2 y 3).
@export var level_fractions: Array[float] = [0.25, 0.5, 1.0]
## Segundos que se muestran los avisos de la consola en el HUD.
@export var alert_duration: float = 3.0

## Panel abierto ahora mismo (null si está cerrado).
var _panel: DomeEnergyPanel = null

## Abre el panel de niveles. Devuelve 0: el escudo se gana al elegir nivel.
func repair() -> float:
	if _panel != null or not _can_divert():
		return 0.0
	_open_panel()
	return 0.0

## Desvía la energía del nivel indicado (1, 2 o 3). Devuelve el escudo ganado.
## También lo usan los tests, sin pasar por el panel.
func divert_level(level: int) -> float:
	if level < 1 or level > level_fractions.size():
		return 0.0
	if not _can_divert():
		return 0.0
	# El aviso de éxito lo muestra el HUD al oír `energy_diverted_to_dome`.
	return _game.divert_energy_to_dome(level_fractions[level - 1])

## Energía que gastaría un nivel con la carga actual.
func get_level_energy(level: int) -> float:
	if level < 1 or level > level_fractions.size():
		return 0.0
	return _game.get_resource_level(GameManager.RESOURCE_ENERGY) * level_fractions[level - 1]

## Escudo que ganaría un nivel (limitado por lo que le falta al escudo).
func get_level_shield_gain(level: int) -> float:
	var missing: float = _game.get_resource_max(GameManager.RESOURCE_SHIELD) - _game.get_resource_level(GameManager.RESOURCE_SHIELD)
	return minf(missing, get_level_energy(level) * _game.config.dome_transfer_efficiency)

# --- Métodos privados ---

## Comprueba si se puede desviar energía; si no, avisa del motivo.
func _can_divert() -> bool:
	if _game.is_short_circuit_active():
		_notify(tr("CORTO CIRCUITO: repara la energía en el generador antes de usar el domo."))
		return false
	if _game.get_resource_level(GameManager.RESOURCE_ENERGY) <= 0.0:
		_notify(tr("SIN ENERGÍA: espera a que los paneles solares carguen."))
		return false
	if _game.get_resource_level(GameManager.RESOURCE_SHIELD) >= _game.get_resource_max(GameManager.RESOURCE_SHIELD):
		_notify(tr("El escudo del domo ya está al máximo."))
		return false
	return true

## Instancia el panel en la capa de minijuegos y bloquea al jugador.
func _open_panel() -> void:
	var packed: PackedScene = load(PANEL_SCENE) as PackedScene
	if packed == null:
		push_error("DomeConsole: no se pudo cargar %s" % PANEL_SCENE)
		return
	_panel = packed.instantiate() as DomeEnergyPanel
	var layer: Node = get_tree().get_first_node_in_group("repair_minigames")
	if layer == null:
		layer = CanvasLayer.new()
		(layer as CanvasLayer).layer = 10
		get_tree().current_scene.add_child(layer)
	layer.add_child(_panel)
	_panel.level_chosen.connect(_on_level_chosen)
	_panel.cancelled.connect(_close_panel)
	_panel.setup(self)
	_set_player_input(false)
	AudioManager.sfx(&"console")

func _on_level_chosen(level: int) -> void:
	divert_level(level)
	_close_panel()

func _close_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_set_player_input(true)

## Bloquea o libera el control del jugador (y el ratón).
func _set_player_input(enabled: bool) -> void:
	var player: HabitatPlayer = get_tree().get_first_node_in_group("player") as HabitatPlayer
	if player != null:
		player.set_input_enabled(enabled)

## Aviso en el HUD (si la escena tiene uno).
func _notify(message: String) -> void:
	if not is_inside_tree():
		return
	var hud: MissionHud = get_tree().get_first_node_in_group("mission_hud") as MissionHud
	if hud != null:
		hud.show_alert(message, alert_duration)
