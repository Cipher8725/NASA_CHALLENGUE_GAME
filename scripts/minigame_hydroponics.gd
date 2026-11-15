class_name HydroponicsMinigame
extends RepairMinigame

## Minijuego de la hidroponía: cultivar comida fresca como en el huerto Veggie de la ISS.
##
## Los cultivos y sus datos salen de `resources/hidroponia/cultivos.json` (estudios
## OSD-745, OSD-780 y OSD-655 de NASA OSDR y material de la Agencia Espacial Canadiense).
##
## Mecánica:
## 1. El jugador elige la luz del huerto: rica en rojo (90:10) o rica en azul (50:50),
##    las dos fórmulas reales de VEG-04. La azul gasta 15 % más energía.
## 2. Mantiene la humedad de la almohadilla dentro de la zona verde regando (ESPACIO).
##    Cada riego gasta agua de la base. Como en la ISS, la planta pide más agua a medida
##    que crece.
## 3. Cuando pasan los días reales hasta la cosecha, el minijuego se gana y la comida sube.
##
## Este es el compromiso de ingeniería del desafío: cultivar comida cuesta agua y energía.

const CROPS_PATH: String = "res://resources/hidroponia/cultivos.json"

## Zona buena de humedad (fracción 0-1).
@export var moisture_min: float = 0.35
@export var moisture_max: float = 0.8
## Humedad que sube cada riego.
@export var water_per_press: float = 0.2
## Secado por segundo al empezar y al final del cultivo (la planta grande bebe más).
@export var dry_rate_start: float = 0.06
@export var dry_rate_end: float = 0.16
## Errores permitidos antes de perder la cosecha.
@export var max_errors: int = 3

@onready var _title: Label = %TitleLabel
@onready var _crop_label: Label = %CropLabel
@onready var _moisture_bar: ProgressBar = %MoistureBar
@onready var _moisture_label: Label = %MoistureLabel
@onready var _day_label: Label = %DayLabel
@onready var _red_button: Button = %RedLightButton
@onready var _blue_button: Button = %BlueLightButton
@onready var _water_button: Button = %WaterButton
## Huerto en 3D (cámara Veggie): plantas que crecen, luz de color y gotas al regar.
@onready var _garden: HydroponicsGarden3D = %Garden

var _data: Dictionary = {}
var _crop: Dictionary = {}
var _light: String = ""
var _moisture: float = 0.55
var _days: float = 0.0
var _errors: int = 0
var _water_used: float = 0.0
var _energy_used: float = 0.0
var _game: GameManager = null

func _ready() -> void:
	super._ready()
	_game = GameManager.get_instance()
	_red_button.pressed.connect(select_light.bind("rojo"))
	_blue_button.pressed.connect(select_light.bind("azul"))
	_water_button.pressed.connect(water)
	for button: Button in [_red_button, _blue_button, _water_button]:
		button.focus_mode = Control.FOCUS_NONE


## Tutorial del huerto hidropónico.
func guide_steps() -> Array[Dictionary]:
	return [
		GuideOverlay.step(tr("El huerto hidropónico"),
			tr("Aquí cultivas comida como en la [b]ISS[/b] (cámara Veggie de la NASA). Las plantas crecen sin tierra, con luz LED y agua."),
			get_node_or_null("Panel/Body/GardenView") as Control),
		GuideOverlay.step(tr("1. Elige la luz"),
			tr("[b]Roja (90:10)[/b] o [b]azul (50:50)[/b], como en los estudios reales. La luz gasta energía de la base."),
			get_node_or_null("Panel/Body/LightRow") as Control),
		GuideOverlay.step(tr("2. Mantén la humedad"),
			tr("Riega con [b]ESPACIO[/b] o con el botón. La humedad debe quedar en la [b]zona buena (35 % a 80 %)[/b]: ni seca ni encharcada."),
			get_node_or_null("Panel/Body/MoistureRow") as Control),
		GuideOverlay.step(tr("3. Cosecha"),
			tr("Cuida las plantas hasta que la cosecha llegue al 100 %. Cada día del juego es un día real del experimento."),
			get_node_or_null("Panel/Body/GrowthRow") as Control),
	]

func _setup() -> void:
	_data = _load_crops()
	_crop = _pick_crop()
	_light = ""
	_moisture = 0.55
	_days = 0.0
	_errors = 0
	_title.text = tr("HUERTO HIDROPÓNICO")
	_crop_label.text = "%s — %s" % [tr(String(_crop.get("nombre", "Cultivo"))), tr(String(_crop.get("donde", "")))]
	_garden.set_crop(String(_crop.get("id", "lechuga")))
	_garden.set_light("")
	_set_status(tr("Elige la luz: 1 = roja (90:10)   2 = azul (50:50)"))
	_refresh_garden()

func _update_visuals(delta: float) -> void:
	if _light.is_empty():
		return
	var settings: Dictionary = _data.get("uso_en_juego", {})
	# La luz encendida gasta energía de la base (la azul, 15 % más).
	var energy_rate: float = float(settings.get("energia_luz_azul_por_segundo" if _light == "azul" else "energia_luz_roja_por_segundo", 0.35))
	_spend(GameManager.RESOURCE_ENERGY, energy_rate * delta)
	_energy_used += energy_rate * delta
	# La almohadilla se seca más rápido cuanto más grande es la planta.
	var dry: float = lerpf(dry_rate_start, dry_rate_end, get_progress())
	_moisture = maxf(0.0, _moisture - dry * delta)
	if _moisture < moisture_min * 0.5:
		_register_error(tr("¡Se secó la almohadilla! Riega más seguido."))
		_moisture = moisture_min
	# Solo crece con la humedad en la zona buena.
	if _moisture >= moisture_min and _moisture <= moisture_max:
		_days += delta / float(settings.get("segundos_por_dia", 0.5))
		set_progress(_days / harvest_days())
		if get_progress() >= 1.0:
			_succeed(tr("¡Cosecha lista! %s a los %d días, como en la ISS (%s).") % [tr(String(_crop.get("nombre", ""))), harvest_days(), _crop.get("estudio", "")])
	_refresh_garden()

func _handle_action_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		water()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_1:
				select_light("rojo")
			KEY_2:
				select_light("azul")

# --- API pública ---

## Enciende la luz del huerto: "rojo" (90 % rojo, 10 % azul) o "azul" (50:50).
func select_light(kind: String) -> void:
	if not is_running() or not _light.is_empty():
		return
	_light = kind
	_garden.set_light(kind)
	_set_status(tr("Luz %s encendida. Riega con ESPACIO y mantén la humedad en verde.") % (tr("roja 90:10") if kind == "rojo" else tr("azul 50:50 (+15 % energía)")))
	_refresh_garden()

## Riega la almohadilla: sube la humedad y gasta agua de la base.
func water() -> void:
	if not is_running() or _light.is_empty():
		return
	var cost: float = float(_data.get("uso_en_juego", {}).get("agua_por_riego", 3.0))
	_spend(GameManager.RESOURCE_WATER, cost)
	_water_used += cost
	_moisture += water_per_press
	_garden.splash()
	AudioManager.sfx(&"water", -3.0)
	if _moisture > 1.0:
		_moisture = moisture_max
		_register_error(tr("¡Demasiada agua! Las raíces necesitan aire."))
	_refresh_garden()

## Días que necesita el cultivo elegido (dato real del estudio).
func harvest_days() -> int:
	return int(_crop.get("dias_hasta_cosecha", 33))

func get_crop() -> Dictionary:
	return _crop

func get_light() -> String:
	return _light

func get_moisture() -> float:
	return _moisture

func set_moisture(value: float) -> void:
	_moisture = clampf(value, 0.0, 1.0)

func get_errors() -> int:
	return _errors

func get_water_used() -> float:
	return _water_used

func get_energy_used() -> float:
	return _energy_used

# --- Métodos privados ---

## En el huerto no se "repara": se cosecha. Se cambian los títulos del resultado.
func _show_result(success: bool, message: String) -> void:
	super._show_result(success, message)
	_result_title.text = tr("¡COSECHA LISTA!") if success else tr("COSECHA PERDIDA")

func _load_crops() -> Dictionary:
	var file: FileAccess = FileAccess.open(CROPS_PATH, FileAccess.READ)
	if file == null:
		push_error("HydroponicsMinigame: falta %s" % CROPS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

## Elige al azar un cultivo con días de cosecha publicados (los que no tienen dato no se juegan).
func _pick_crop() -> Dictionary:
	var options: Array = []
	for crop: Variant in _data.get("cultivos", []):
		if (crop as Dictionary).get("dias_hasta_cosecha") != null:
			options.append(crop)
	if options.is_empty():
		return {"nombre": tr("Lechuga"), "dias_hasta_cosecha": 33}
	return options[randi() % options.size()] as Dictionary

func _register_error(message: String) -> void:
	_errors += 1
	set_progress(maxf(0.0, get_progress() - 0.08))
	_days = get_progress() * harvest_days()
	_set_status(tr("%s  (errores: %d/%d)") % [message, _errors, max_errors])
	if _errors >= max_errors:
		_fail(tr("Se perdió la cosecha. En la ISS también pasó: en VEG-04A el exceso de fertilizante dañó las plantas."))

func _spend(resource_type: StringName, amount: float) -> void:
	if _game != null:
		_game.consume_resource(resource_type, amount)

func _refresh_garden() -> void:
	_garden.set_growth(get_progress())
	_garden.set_moisture(_moisture)
	_moisture_bar.value = _moisture
	_moisture_label.text = "%d%%" % roundi(_moisture * 100.0)
	_day_label.text = tr("Día %d de %d") % [floori(_days), harvest_days()]
	_red_button.disabled = not _light.is_empty()
	_blue_button.disabled = not _light.is_empty()
	_water_button.disabled = _light.is_empty()
