class_name MissionHud
extends Control

## HUD de la misión.
##
## El HUD es un observador puro: se conecta a las señales del `GameManager`
## y refleja el estado. Nunca modifica el estado del juego (regla de
## `gameplay.md`: la lógica no referencia a la UI, la UI observa la lógica).

## Escala global del HUD (97 %: la UI se reduce un 3 %).
const UI_SCALE: float = 0.97

# Oxígeno, energía y escudo se muestran como burbujas que se van gastando.
@onready var _oxygen_bar: ResourceBubbles = %OxygenBar
@onready var _energy_bar: ResourceBubbles = %EnergyBar
@onready var _shield_bar: ResourceBubbles = %ShieldBar

@onready var _oxygen_value: Label = %OxygenValue
@onready var _energy_value: Label = %EnergyValue
@onready var _water_value: Label = %WaterValue
@onready var _shield_value: Label = %ShieldValue
@onready var _food_value: Label = %FoodValue

@onready var _timer_label: Label = %TimerLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _state_label: Label = %StateLabel
@onready var _alert_label: Label = %AlertLabel
@onready var _result_panel: Control = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _minimap: HudMinimap = %Minimap
@onready var _short_circuit_banner: Control = %ShortCircuitBanner
@onready var _short_circuit_label: Label = %ShortCircuitLabel
@onready var _game: GameManager = GameManager.get_instance()

## Etiquetas legibles de cada recurso vital.
const RESOURCE_LABELS: Dictionary = {
	&"oxygen": "OXÍGENO",
	&"energy": "ENERGÍA",
	&"water": "AGUA",
	&"shield": "ESCUDO RADIOACTIVO",
	&"food": "COMIDA",
}

## Colores de la cuenta atrás: normal, aviso (quedan 30 s) y peligro (10 s).
const COLOR_TIMER_NORMAL: Color = Color(0.96, 0.98, 1, 1)
const COLOR_TIMER_WARNING: Color = Color(1, 0.82, 0.35, 1)
const COLOR_TIMER_DANGER: Color = Color(1, 0.45, 0.4, 1)

## Color de la etiqueta de estado según la marcha de la misión. Los niños
## reconocen el estado por el color antes de leerlo.
const STATE_COLORS: Dictionary = {
	GameManager.MissionState.BRIEFING: Color(0.62, 0.76, 0.95),
	GameManager.MissionState.ACTIVE: Color(0.5, 0.93, 0.64),
	GameManager.MissionState.CRITICAL: Color(1, 0.66, 0.32),
	GameManager.MissionState.FAILED: Color(1, 0.45, 0.4),
	GameManager.MissionState.COMPLETED: Color(0.5, 0.93, 0.64),
}

var _alert_time_left: float = 0.0
## Sala a la que hay que ir para reparar el corto circuito ("" si no hay corto).
var _repair_room: String = ""
var _banner_time: float = 0.0
## Evita repetir el aviso de radiación alta mientras dura el mismo pico.
var _high_radiation_warned: bool = false

## Nombres para niños de cada emergencia.
const EMERGENCY_LABELS: Dictionary = {
	&"micrometeorito": "MICROMETEORITO",
	&"sobrecarga_energia": "SOBRECARGA DE ENERGÍA",
	&"corto_circuito": "CORTO CIRCUITO",
	&"caida_presion": "CAÍDA DE PRESIÓN",
	&"fuga_agua": "FUGA DE AGUA",
}

func _ready() -> void:
	_apply_ui_scale()
	get_viewport().size_changed.connect(_apply_ui_scale)

	# Conexión a las señales del gestor global (observación, no control).
	_game.resource_changed.connect(_on_resource_changed)
	_game.resource_critical.connect(_on_resource_critical)
	_game.resource_depleted.connect(_on_resource_depleted)
	_game.emergency_triggered.connect(_on_emergency_triggered)
	_game.mission_state_changed.connect(_on_mission_state_changed)
	_game.mission_failed.connect(_on_mission_failed)
	_game.mission_completed.connect(_on_mission_completed)
	_game.short_circuit_changed.connect(_on_short_circuit_changed)
	_game.energy_diverted_to_dome.connect(_on_energy_diverted_to_dome)

	_result_panel.visible = false
	_alert_label.visible = false
	_short_circuit_banner.visible = false
	if _game.is_short_circuit_active():
		_on_short_circuit_changed(true)
	_update_timer_display()
	_update_score_display()
	_update_state_display(_game.get_mission_state())

func _process(delta: float) -> void:
	# El HUD solo refresca los indicadores de tiempo y puntuación.
	_update_timer_display()
	_update_score_display()

	_check_radiation_peak()
	_update_short_circuit_banner(delta)

	if _alert_time_left > 0.0:
		_alert_time_left -= delta
		if _alert_time_left <= 0.0:
			_alert_label.visible = false

# --- Métodos privados ---

## Reduce todo el HUD a UI_SCALE. El control se estira a `pantalla / escala`
## para que, una vez escalado, siga ocupando la pantalla entera y los anclajes
## (esquinas) sigan en su sitio.
func _apply_ui_scale() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	scale = Vector2(UI_SCALE, UI_SCALE)
	size = get_viewport_rect().size / UI_SCALE

## Porcentaje entero de un recurso.
func _percent(current: float, maximum: float) -> int:
	return roundi(100.0 * current / maximum) if maximum > 0.0 else 0

## Refleja el valor de un recurso en sus burbujas y su porcentaje.
func _update_resource_bubbles(bubbles: ResourceBubbles, value_label: Label, current: float, maximum: float) -> void:
	bubbles.set_values(current, maximum)
	value_label.text = "%d%%" % _percent(current, maximum)

## Agua y comida: solo nombre y porcentaje (sin barra).
func _update_resource_text(value_label: Label, current: float, maximum: float) -> void:
	value_label.text = "%d%%" % _percent(current, maximum)

## Refresca el reloj de la misión. Sin límite de tiempo muestra lo que se
## lleva aguantado; con límite, la cuenta atrás.
func _update_timer_display() -> void:
	if _game.config.endless_mission:
		_timer_label.text = _format_time(_game.get_mission_time())
		_timer_label.add_theme_color_override("font_color", COLOR_TIMER_NORMAL)
		return
	var remaining: float = maxf(0.0, _game.config.mission_duration - _game.get_mission_time())
	_timer_label.text = _format_time(remaining)

	# El color avisa antes que el número: amarillo a 30 s, rojo a 10 s.
	var color: Color = COLOR_TIMER_NORMAL
	if remaining <= 10.0:
		color = COLOR_TIMER_DANGER
	elif remaining <= 30.0:
		color = COLOR_TIMER_WARNING
	_timer_label.add_theme_color_override("font_color", color)

## Refresca la puntuación de la misión.
func _update_score_display() -> void:
	_score_label.text = tr("PUNTOS: %d") % roundi(_game.get_score())

## Traduce el estado de misión a un texto comprensible y le da color.
func _update_state_display(state: GameManager.MissionState) -> void:
	match state:
		GameManager.MissionState.BRIEFING:
			_state_label.text = tr("ESTADO: PREPARANDO")
		GameManager.MissionState.ACTIVE:
			_state_label.text = tr("ESTADO: EN CURSO")
		GameManager.MissionState.CRITICAL:
			_state_label.text = tr("ESTADO: CRÍTICO")
		GameManager.MissionState.FAILED:
			_state_label.text = tr("ESTADO: FALLIDO")
		GameManager.MissionState.COMPLETED:
			_state_label.text = tr("ESTADO: COMPLETADO")
	var color: Color = STATE_COLORS.get(state, COLOR_TIMER_NORMAL)
	_state_label.add_theme_color_override("font_color", color)

## Convierte segundos a formato mm:ss.
func _format_time(seconds: float) -> String:
	var total_seconds: int = roundi(seconds)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

# --- Callbacks de señal ---

func _on_resource_changed(resource_type: StringName, current_value: float, max_value: float) -> void:
	match resource_type:
		GameManager.RESOURCE_OXYGEN:
			_update_resource_bubbles(_oxygen_bar, _oxygen_value, current_value, max_value)
		GameManager.RESOURCE_ENERGY:
			_update_resource_bubbles(_energy_bar, _energy_value, current_value, max_value)
		GameManager.RESOURCE_WATER:
			_update_resource_text(_water_value, current_value, max_value)
		GameManager.RESOURCE_SHIELD:
			_update_resource_bubbles(_shield_bar, _shield_value, current_value, max_value)
		GameManager.RESOURCE_FOOD:
			_update_resource_text(_food_value, current_value, max_value)

func _on_resource_critical(resource_type: StringName) -> void:
	var label: String = tr(String(RESOURCE_LABELS.get(resource_type, resource_type)))
	_show_alert(tr("¡%s EN NIVEL CRÍTICO!") % label, 3.0)

func _on_resource_depleted(resource_type: StringName) -> void:
	var label: String = tr(String(RESOURCE_LABELS.get(resource_type, resource_type)))
	_show_alert(tr("¡%s AGOTADO!") % label, 4.0)

func _on_emergency_triggered(emergency_type: StringName, _severity: float) -> void:
	if emergency_type == GameManager.EMERGENCY_SOLAR_STORM:
		var flare: Dictionary = _game.get_last_solar_flare()
		_show_alert(tr("¡%s! Revisa el escudo.") % RadiationData.flare_label(flare).to_upper(), 4.0)
		return
	if emergency_type == GameManager.EMERGENCY_SHORT_CIRCUIT:
		_show_alert(tr("¡CORTO CIRCUITO! Sin energía. Ve a la %s y repárala (tecla E).") % tr(_short_circuit_room()), 5.0)
		return
	var label: String = tr(String(EMERGENCY_LABELS.get(emergency_type, String(emergency_type).to_upper())))
	_show_alert(tr("EMERGENCIA: %s") % label, 3.0)

## Corto circuito: aviso fijo con la sala a la que ir y destino en el
## minimapa mientras dura; al repararse se quita todo.
func _on_short_circuit_changed(active: bool) -> void:
	if active:
		_repair_room = _short_circuit_room()
		var console: ResourceConsole = _find_energy_console()
		if console != null:
			_minimap.set_target(console.global_position)
		_banner_time = 0.0
		_short_circuit_banner.visible = true
		_update_short_circuit_banner(0.0)
		return
	_repair_room = ""
	_short_circuit_banner.visible = false
	_minimap.clear_target()
	_show_alert(tr("CIRCUITO REPARADO: los paneles solares vuelven a cargar."), 3.0)

## Sala donde está la consola de energía (la del generador).
func _short_circuit_room() -> String:
	var console: ResourceConsole = _find_energy_console()
	if console == null:
		return "SALA DEL GENERADOR"
	return HudMinimap.room_name_at(console.global_position)

## Busca la consola que repara la energía (y con ella el corto circuito).
func _find_energy_console() -> ResourceConsole:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group("consoles"):
		var console: ResourceConsole = node as ResourceConsole
		if console != null and console.resource_type == GameManager.RESOURCE_ENERGY:
			return console
	return null

## Texto y parpadeo del aviso de corto circuito. Dice también dónde está el
## jugador, para que sepa si ya ha llegado.
func _update_short_circuit_banner(delta: float) -> void:
	if not _short_circuit_banner.visible:
		return
	_banner_time += delta
	var here: String = ""
	var player: Node3D = _minimap.get_player()
	if player != null:
		here = HudMinimap.room_name_at(player.global_position)
	var line2: String = tr("Ve a la %s y repara la ENERGÍA (tecla E).") % tr(_repair_room)
	if here == _repair_room:
		line2 = tr("¡Ya estás en la %s! Busca el panel del generador y pulsa E.") % tr(_repair_room)
	elif here != "":
		line2 += tr("\nEstás en: %s") % tr(here)
	_short_circuit_label.text = tr("¡CORTO CIRCUITO EN EL GENERADOR!\n%s") % line2
	# Parpadeo suave para llamar la atención sin tapar la escena.
	_short_circuit_banner.modulate.a = 0.75 + 0.25 * sin(_banner_time * 5.0)

## Aviso al desviar la energía al domo.
func _on_energy_diverted_to_dome(energy_used: float, shield_gained: float) -> void:
	_show_alert(tr("ENERGÍA AL DOMO: -%d energía, +%d escudo") % [roundi(energy_used), roundi(shield_gained)], 3.0)

## Avisa cuando la radiación real (RadLab) sube mucho por encima de la media del día.
func _check_radiation_peak() -> void:
	var state: GameManager.MissionState = _game.get_mission_state()
	if state != GameManager.MissionState.ACTIVE and state != GameManager.MissionState.CRITICAL:
		return
	var factor: float = RadiationData.shield_factor(_game.get_mission_progress())
	if factor >= RadiationData.HIGH_RADIATION_FACTOR and not _high_radiation_warned:
		_high_radiation_warned = true
		_show_alert(tr("RADIACIÓN ALTA: %d µGy/h medidos en la ISS (RadLab)") % roundi(_game.get_current_radiation_rate()), 4.0)
	elif factor < RadiationData.HIGH_RADIATION_FACTOR:
		_high_radiation_warned = false

## Dato real de radiación para la pantalla de resultado.
func _radiation_fact() -> String:
	return tr("Dato real: un astronauta en la ISS recibió unos %d µGy en un día (RadLab, NASA).") % roundi(RadiationData.daily_dose())

func _on_mission_state_changed(new_state: GameManager.MissionState) -> void:
	_update_state_display(new_state)

func _on_mission_failed(reason: String) -> void:
	_result_panel.visible = true
	_result_title.text = tr("MISIÓN FALLIDA")
	_result_detail.text = tr("%s\n\nPuntuación: %d\n\n%s") % [reason, roundi(_game.get_score()), _radiation_fact()]

func _on_mission_completed(final_score: float) -> void:
	_result_panel.visible = true
	_result_title.text = tr("MISIÓN COMPLETADA")
	_result_detail.text = tr("¡Has sobrevivido al hábitat!\n\nPuntuación final: %d\n\n%s") % [roundi(final_score), _radiation_fact()]

## Muestra un mensaje de alerta temporal en pantalla.
func _show_alert(message: String, duration: float) -> void:
	_alert_label.text = message
	_alert_label.visible = true
	_alert_time_left = duration

## Muestra un aviso en el HUD. Uso externo (minijuegos de reparación).
func show_alert(message: String, duration: float = 3.0) -> void:
	_show_alert(message, duration)
