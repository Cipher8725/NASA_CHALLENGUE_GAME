class_name OxygenRepairMinigame
extends RepairMinigame

## Minijuego de reparación del oxígeno: presurización.
##
## Mientras el jugador mantiene pulsada la tecla (ESPACIO/ENTER) o el botón,
## la bomba sube la presión; al soltar, la presión se escapa sola. Hay que
## llevar la aguja hasta la zona verde y MANTENERLA ahí `hold_required`
## segundos. Salir de la zona hace perder estabilidad, y pasarse del 100 %
## abre la válvula de alivio: la presión cae y se pierde tiempo.

## Presión que sube por segundo mientras se mantiene pulsado (fracción 0-1).
@export var pump_rate: float = 0.55
## Empujón extra de presión en cada pulsación (permite dar toques cortos).
@export var pump_per_press: float = 0.04
## Presión que se escapa por segundo de forma continua.
@export var leak_rate: float = 0.22
## Segundos seguidos dentro de la zona verde para completar la reparación.
@export var hold_required: float = 2.5
## Multiplicador con el que se pierde la estabilidad fuera de la zona.
@export var hold_decay_factor: float = 1.5
## Ancho de la zona verde (fracción de la barra).
@export var target_width: float = 0.14
## Límites entre los que se coloca el centro de la zona verde.
@export var target_min_center: float = 0.6
@export var target_max_center: float = 0.8
## Presión a la que cae el sistema cuando salta la válvula de alivio.
@export var overpressure_reset: float = 0.3
## Segundos que se restan cuando salta la válvula de alivio.
@export var overpressure_time_penalty: float = 2.0

@onready var _gauge: RepairGauge = %Gauge
## Puesto de oxígeno 3D (parche de tutoriales): su manómetro repite la presión y la zona verde.
@onready var _station: OxygenStation3D = get_node_or_null("%Station") as OxygenStation3D
@onready var _button: Button = %RepairButton
@onready var _title: Label = %TitleLabel

var _pressure: float = 0.0
var _target_center: float = 0.7
var _hold_time: float = 0.0
var _key_held: bool = false
var _button_held: bool = false
var _overpressures: int = 0
var _was_in_zone: bool = false

func _ready() -> void:
	super._ready()
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	# Sin foco: ESPACIO no debe activar el botón además de la tecla.
	_button.focus_mode = Control.FOCUS_NONE
	_randomize_target()

func _setup() -> void:
	_title.text = tr("REPARACIÓN DE OXÍGENO")
	_pressure = 0.0
	_hold_time = 0.0
	_overpressures = 0
	_key_held = false
	_button_held = false
	_was_in_zone = false
	_randomize_target()
	_sync_gauges()
	_set_status(tr("Mantén ESPACIO para subir la presión hasta la zona verde."))
	_refresh_hud()

func _update_visuals(delta: float) -> void:
	step(delta)

func _handle_action_input(event: InputEvent) -> void:
	# ESPACIO (y ENTER) equivalen a mantener el botón de la bomba.
	if event.is_action_pressed("ui_accept"):
		_key_held = true
		press_button()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ui_accept"):
		_key_held = false
		get_viewport().set_input_as_handled()

# --- API pública ---

## Avanza la simulación `delta` segundos. Lo llama `_process`; las pruebas
## pueden invocarlo directamente.
func step(delta: float) -> void:
	if not is_running():
		return
	if is_pumping():
		_pressure += pump_rate * delta
	_pressure -= leak_rate * delta

	# Válvula de alivio: pasarse del máximo descarga el sistema.
	if _pressure >= 1.0:
		_overpressures += 1
		_pressure = overpressure_reset
		remove_time(overpressure_time_penalty)
		_gauge.flash_miss()
		AudioManager.sfx(&"miss")
		AudioManager.sfx(&"steam", -6.0)
		if _station != null:
			_station.flash_miss()
		_set_status(tr("¡SOBREPRESIÓN! La válvula se abrió  -%.1f s") % overpressure_time_penalty)
	_pressure = clampf(_pressure, 0.0, 1.0)

	# La estabilidad solo crece dentro de la zona verde.
	if is_in_zone():
		_hold_time = minf(hold_required, _hold_time + delta)
		if not _was_in_zone:
			_set_status(tr("¡Mantén la presión estable!"))
			AudioManager.sfx(&"hit", -6.0)
		_was_in_zone = true
	else:
		_hold_time = maxf(0.0, _hold_time - delta * hold_decay_factor)
		if _was_in_zone:
			_set_status(tr("Presión fuera de rango: vuelve a la zona verde."))
		_was_in_zone = false

	set_progress(_hold_time / hold_required)
	_sync_gauges()
	if _hold_time >= hold_required:
		_gauge.flash_hit()
		AudioManager.sfx(&"hit")
		if _station != null:
			_station.flash_hit()
		_succeed(tr("Presión estabilizada. Sistema de oxígeno restablecido."))

## Pulsación puntual de la bomba (un toque corto de presión).
func press_button() -> void:
	if not is_running():
		return
	_pressure = clampf(_pressure + pump_per_press, 0.0, 1.0)
	_sync_gauges()

## ¿La bomba está activa (tecla o botón mantenidos)?
func is_pumping() -> bool:
	return _key_held or _button_held

## Activa o desactiva la bomba como si se mantuviera la tecla (pruebas).
func set_pumping(value: bool) -> void:
	_key_held = value

## Presión actual, de 0.0 a 1.0.
func get_pressure() -> float:
	return _pressure

## Fija la presión (usado por las pruebas).
func set_pressure(value: float) -> void:
	_pressure = clampf(value, 0.0, 1.0)
	_sync_gauges()

## Centro de la zona verde, de 0.0 a 1.0.
func get_target_center() -> float:
	return _target_center

## ¿La presión está dentro de la zona verde?
func is_in_zone() -> bool:
	return absf(_pressure - _target_center) <= target_width * 0.5

## Segundos acumulados de presión estable.
func get_hold_time() -> float:
	return _hold_time

## Veces que ha saltado la válvula de alivio.
func get_overpressures() -> int:
	return _overpressures

# --- Métodos privados ---

## Coloca la zona verde en una posición aleatoria dentro de sus límites.
func _randomize_target() -> void:
	_target_center = randf_range(target_min_center, target_max_center)

func _on_button_down() -> void:
	_button_held = true
	press_button()

func _on_button_up() -> void:
	_button_held = false

# --- Puesto 3D y tutorial (parche de tutoriales) ---

## Puesto 3D del minijuego (lo usan las pruebas; puede ser null).
func get_station() -> OxygenStation3D:
	return _station

## La barra 2D y el manómetro 3D muestran siempre la misma presión y zona verde.
func _sync_gauges() -> void:
	_gauge.set_state(_pressure, _target_center, target_width)
	if _station != null:
		_station.set_state(_pressure, _target_center, target_width)

## Tutorial del minijuego de oxígeno (mecánica de mantener la presión).
func guide_steps() -> Array[Dictionary]:
	return [
		GuideOverlay.step(tr("Reparar el oxígeno"),
			tr("Este es el [b]puesto de oxígeno[/b]: el tanque, la válvula y el [b]manómetro[/b]. Su aguja marca la presión."),
			get_node_or_null("Panel/Body/StationView") as Control),
		GuideOverlay.step(tr("Sube la presión"),
			tr("[b]Mantén ESPACIO[/b] (o el botón) para subir la presión; al soltar, baja sola. Lleva la aguja a la [b]zona verde[/b]."),
			get_node_or_null("Panel/Body/Gauge") as Control),
		GuideOverlay.step(tr("Mantenla estable"),
			tr("Quédate en la zona verde hasta llenar la barra [b]ESTABLE[/b]. Si pasas del 100 %, la válvula se abre y pierdes tiempo."),
			get_node_or_null("Panel/Body/PressureRow") as Control),
		GuideOverlay.step(tr("¡Tu turno!"),
			tr("Puedes usar este botón o la tecla [b]ESPACIO[/b]. [b]ESC[/b] cierra la reparación."),
			get_node_or_null("Panel/Body/RepairButton") as Control),
	]
