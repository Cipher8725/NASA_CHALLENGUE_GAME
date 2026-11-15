class_name HydroponicsMinigame
extends RepairMinigame

## Minijuego de producción de alimentos en la hidroponía.
##
## El jugador cultiva una bandeja: ajusta la LUZ y el AGUA y debe mantenerlas
## dentro del rango que necesita el cultivo elegido. Los rangos vienen de
## `resources/hidroponia/cultivos.json`, un archivo con datos de la Canadian
## Space Agency (CSA).
##
## Compromiso de ingeniería del desafío: regar consume AGUA (RESOURCE_WATER) y
## la luz consume ENERGÍA (RESOURCE_ENERGY). Cuanto más se desvían los
## controles de su rango, más rápido se pierde el cultivo.
##
## La planta crece mientras los dos controles están dentro de su rango. Cuando
## llega al 100 % la cosecha termina y la comida sube.

## Ruta del catálogo de cultivos de la CSA.
const CULTIVOS_PATH: String = "res://resources/hidroponia/cultivos.json"

## Segundos que tarda la planta en crecer con los controles en rango.
@export var growth_seconds: float = 12.0
## Segundos que se pierde cuando el cultivo se sale de rango.
@export var damage_per_second: float = 0.06
## Fracción de crecimiento que se pierde por segundo fuera de rango.
@export var growth_loss_per_second: float = 0.04
## Agua que consume cada segundo con la luz encendida.
@export var water_cost_per_second: float = 1.5
## Energía que consume cada segundo con la luz encendida.
@export var energy_cost_per_second: float = 1.2
## Margen de tolerancia alrededor del rango del cultivo (fracción).
@export var tolerance: float = 0.06

@onready var _light_bar: ProgressBar = %LightBar
@onready var _light_zone: ColorRect = %LightZone
@onready var _water_bar: ProgressBar = %WaterBar
@onready var _water_zone: ColorRect = %WaterZone
@onready var _light_label: Label = %LightValue
@onready var _water_label: Label = %WaterValue
@onready var _crop_label: Label = %CropLabel
@onready var _plant: ColorRect = %Plant

var _cultivos: Array[Dictionary] = []
var _cultivo: Dictionary = {}
var _luz: float = 0.5
var _agua: float = 0.5
var _crecimiento: float = 0.0
var _en_rango: bool = true
var _segundos_en_rango: float = 0.0
var _game: GameManager = null

func _ready() -> void:
	super._ready()
	_game = GameManager.get_instance()
	_cultivos = _cargar_cultivos(CULTIVOS_PATH)
	# Las barras y las zonas se dibujan a mano: se calculan con el rango del
	# cultivo y el margen de tolerancia.
	_configurar_barras()

func _setup() -> void:
	if _cultivo.is_empty():
		_elegir_cultivo()
	if _cultivo.is_empty():
		_set_status("No hay datos de cultivos: no se puede cultivar.")
		return
	var nombre: String = str(_cultivo.get("nombre", ""))
	var dias: int = int(_cultivo.get("dias_hasta_cosechar", 0))
	_crop_label.text = "%s  ·  %d días hasta cosechar (CSA)" % [nombre, dias]
	_set_status("Ajusta la luz y el agua para que la planta crezca.")

## Elige un cultivo del catálogo de la CSA. Si ya hay uno elegido, se respeta.
func _elegir_cultivo() -> void:
	if not _cultivo.is_empty() or _cultivos.is_empty():
		return
	_cultivo = _cultivos[randi() % _cultivos.size()]
	_configurar_barras()

func _update_visuals(delta: float) -> void:
	# Los controles se mueven solos: el jugador los ajusta con las flechas.
	_luz = clampf(_luz, 0.0, 1.0)
	_agua = clampf(_agua, 0.0, 1.0)

	_en_rango = _esta_en_rango(_luz, "luz") and _esta_en_rango(_agua, "agua")
	if _en_rango:
		_crecimiento += delta / maxf(growth_seconds, 0.1)
		_segundos_en_rango += delta
		# Regar y encender la luz consumen recursos reales de la misión.
		_gastar_recursos(delta)
	else:
		_crecimiento = maxf(0.0, _crecimiento - growth_loss_per_second * delta)
		_set_status("¡Fuera de rango! La planta se muere si no la corriges.")

	# El color de la planta refleja cómo va el cultivo.
	var tinte: Color = Color(0.35, 0.75, 0.35, 1.0) if _en_rango else Color(0.85, 0.45, 0.3, 1.0)
	_plant.color = tinte
	# La barra de progreso es el crecimiento de la planta.
	set_progress(clampf(_crecimiento, 0.0, 1.0))
	_plant.custom_minimum_size.y = 8.0 + (140.0 * _crecimiento)

	if _crecimiento >= 1.0:
		_succeed("Cosecha lista: %s" % str(_cultivo.get("nombre", "")))

func _handle_action_input(event: InputEvent) -> void:
	# Flechas arriba/abajo: luz. Izquierda/derecha: agua.
	var paso: float = 0.06
	if event.is_action_pressed("ui_up"):
		_luz = clampf(_luz + paso, 0.0, 1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_luz = clampf(_luz - paso, 0.0, 1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_agua = clampf(_agua + paso, 0.0, 1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_agua = clampf(_agua - paso, 0.0, 1.0)
		get_viewport().set_input_as_handled()

# --- API pública (la usan las pruebas) ---

## Cultivo que se está cultivando (vacío si no hay datos).
func get_cultivo() -> Dictionary:
	return _cultivo

## Número de cultivos disponibles en el catálogo.
func get_crop_count() -> int:
	return _cultivos.size()

## Nivel de luz actual (0.0 a 1.0).
func get_luz() -> float:
	return _luz

## Nivel de agua actual (0.0 a 1.0).
func get_agua() -> float:
	return _agua

## Fija los controles (usado por las pruebas).
func set_controles(luz: float, agua: float) -> void:
	_luz = clampf(luz, 0.0, 1.0)
	_agua = clampf(agua, 0.0, 1.0)
	_en_rango = _esta_en_rango(_luz, "luz") and _esta_en_rango(_agua, "agua")

## ¿Los dos controles están dentro del rango del cultivo?
func esta_en_rango() -> bool:
	return _en_rango

## Progreso del crecimiento (0.0 a 1.0).
func get_crecimiento() -> float:
	return _crecimiento

## Fija el crecimiento (usado por las pruebas).
func set_crecimiento(value: float) -> void:
	_crecimiento = clampf(value, 0.0, 1.0)

## Elige el cultivo con el que se empieza (usado por las pruebas).
func set_cultivo(id: String) -> bool:
	for cultivo: Dictionary in _cultivos:
		if str(cultivo.get("id", "")) == id:
			_cultivo = cultivo
			_configurar_barras()
			return true
	return false

# --- Métodos privados ---

## Lee el catálogo de cultivos de la CSA.
static func _cargar_cultivos(path: String) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_warning("HydroponicsMinigame: no existe %s" % path)
		return resultado
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (datos is Dictionary):
		return resultado
	var lista: Array = (datos as Dictionary).get("cultivos", []) as Array
	for item: Variant in lista:
		if item is Dictionary:
			resultado.append(item as Dictionary)
	return resultado

## ¿El valor está dentro del rango del cultivo (con margen de tolerancia)?
func _esta_en_rango(valor: float, clave: String) -> bool:
	if _cultivo.is_empty():
		return false
	var minimo: float = float(_cultivo.get("%s_minima_porcentaje" % clave, 0.0)) / 100.0
	var maximo: float = float(_cultivo.get("%s_maxima_porcentaje" % clave, 100.0)) / 100.0
	return valor >= (minimo - tolerance) and valor <= (maximo + tolerance)

## Dibuja las zonas de rango correcto sobre las barras.
func _configurar_barras() -> void:
	if _cultivo.is_empty():
		return
	_luz = clampf(_luz, 0.0, 1.0)
	_agua = clampf(_agua, 0.0, 1.0)
	var luz_min: float = float(_cultivo.get("luz_minima_porcentaje", 0.0)) / 100.0
	var luz_max: float = float(_cultivo.get("luz_maxima_porcentaje", 100.0)) / 100.0
	var agua_min: float = float(_cultivo.get("agua_minima_porcentaje", 0.0)) / 100.0
	var agua_max: float = float(_cultivo.get("agua_maxima_porcentaje", 100.0)) / 100.0
	_colocar_zona(_light_zone, luz_min, luz_max)
	_colocar_zona(_water_zone, agua_min, agua_max)

## Sitúa una zona verde sobre su barra, en porcentajes.
func _colocar_zona(zona: ColorRect, minimo: float, maximo: float) -> void:
	zona.anchor_left = clampf(minimo, 0.0, 1.0)
	zona.anchor_right = clampf(maximo, 0.0, 1.0)
	zona.offset_left = 0.0
	zona.offset_right = 0.0

## Gasta agua y energía reales de la misión mientras el cultivo está vivo.
func _gastar_recursos(delta: float) -> void:
	if _game == null:
		return
	_game.consume_resource(GameManager.RESOURCE_WATER, water_cost_per_second * delta)
	_game.consume_resource(GameManager.RESOURCE_ENERGY, energy_cost_per_second * delta)
