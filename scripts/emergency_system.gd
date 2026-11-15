class_name EmergencySystem
extends Node

## Generador de eventos de emergencia ambiental.
##
## Programa coaliciones aleatorias (micrometeorito, sobrecarga energética,
## caída de presión o fuga de agua) y las aplica sobre el `GameManager`.
## El temporizador es un nodo estructural definido en `scenes/emergency_system.tscn`.
##
## Además genera **tormentas solares reales**: cuando salta, elige un evento
## del catálogo DONKI de la NASA (descargado a `resources/radiacion/`) y aplica
## su severidad real (clase C, M o X) sobre el escudo radioactivo. El HUD
## muestra el aviso con la clase, la fecha y el identificador del evento.

## Tipos de emergencia que el sistema puede generar.
@export var enabled_emergency_types: Array[StringName] = [
	GameManager.EMERGENCY_METEOR,
	GameManager.EMERGENCY_OVERLOAD,
	GameManager.EMERGENCY_PRESSURE,
	GameManager.EMERGENCY_WATER_LEAK,
]

## Si es true, el sistema puede provocar tormentas solares reales de DONKI.
@export var solar_storms_enabled: bool = true

@onready var _timer: Timer = %EmergencyTimer
@onready var _game: GameManager = GameManager.get_instance()

func _ready() -> void:
	_timer.timeout.connect(_on_emergency_timer_timeout)
	_schedule_next_emergency()

## Programa el siguiente evento de emergencia con un intervalo aleatorio.
func _schedule_next_emergency() -> void:
	var config: MissionConfig = _game.config
	var interval: float = randf_range(config.emergency_interval_min, config.emergency_interval_max)
	_timer.wait_time = maxf(interval, 1.0)
	_timer.start()

## Fuerza una emergencia inmediata (usado por eventos scripted o depuración).
func trigger_now(emergency_type: StringName, severity: float) -> void:
	if emergency_type == GameManager.EMERGENCY_SOLAR_STORM:
		trigger_solar_storm()
		return
	_game.trigger_emergency(emergency_type, severity)

## Provoca una tormenta solar real de DONKI y devuelve el evento aplicado.
## Si el catálogo no está disponible, no se provoca ninguna.
func trigger_solar_storm() -> RadiationData.SpaceWeatherEvent:
	var radiacion: RadiationData = RadiationData.get_instance()
	var evento: RadiationData.SpaceWeatherEvent = radiacion.get_evento_mas_severo()
	if evento == null:
		push_warning("EmergencySystem: no hay eventos DONKI cargados; no hay tormenta solar.")
		return null
	_game.trigger_solar_storm(evento)
	# El HUD muestra el aviso con la clase y la fecha reales del evento.
	var hud: MissionHud = get_tree().get_first_node_in_group("mission_hud") as MissionHud
	if hud != null:
		hud.show_solar_storm(evento)
	return evento

# --- Callbacks de señal ---

func _on_emergency_timer_timeout() -> void:
	# Sin tipos habilitados no hay nada que programar.
	if enabled_emergency_types.is_empty():
		return
	# Las emergencias solo ocurren con la misión en marcha: durante la cuenta
	# atrás o tras el final de la partida el hábitat está en calma.
	var state: GameManager.MissionState = _game.get_mission_state()
	if state != GameManager.MissionState.ACTIVE and state != GameManager.MissionState.CRITICAL:
		return
	var config: MissionConfig = _game.config
	# Una de cada cuatro emergencias es una tormenta solar real de DONKI.
	if solar_storms_enabled and randi() % 4 == 0:
		trigger_solar_storm()
		_schedule_next_emergency()
		return
	var chosen_type: StringName = enabled_emergency_types[randi() % enabled_emergency_types.size()]
	var severity: float = randf_range(config.emergency_severity_min, config.emergency_severity_max)
	_game.trigger_emergency(chosen_type, severity)
	_schedule_next_emergency()
