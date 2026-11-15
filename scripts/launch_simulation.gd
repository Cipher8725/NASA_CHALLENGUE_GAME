class_name LaunchSimulation
extends Control

## Simulación del despegue del Apolo 8 en un Saturno V (21 de diciembre de 1968).
##
## Todos los datos (altura, velocidad y hora de cada maniobra) vienen de la tabla
## de ascenso de la NASA guardada en `resources/apolo8/ascenso.json`.
##
## Flujo: INTRO → CUENTA REGRESIVA (10 s) → VUELO → EN ÓRBITA.
## Durante el vuelo el reloj de la misión avanza más rápido que el real
## (`time_scale`). Cuando llega una maniobra, el reloj se detiene y espera la
## orden del jugador:
##   * a tiempo (o hasta `early_tolerance_real` segundos antes) → ¡Perfecto!
##   * demasiado pronto → error y hay que esperar,
##   * si tarda más de `late_limit_real` segundos → la computadora la hace sola
##     (así era en el Apolo 8 real) y cuenta como error.

signal launched
signal maneuver_done(event_id: String, on_time: bool)
signal mission_completed(stars: int, errors: int)

enum Phase { INTRO, COUNTDOWN, FLIGHT, DONE }

const DATA_PATH: String = "res://resources/apolo8/ascenso.json"
const MENU_SCENE: String = "res://scenes/main_menu.tscn"
const VIEW_TEXTURES: Array[String] = [
	"res://ai_assets/apolo8/cabina_000_frente.png",
	"res://ai_assets/apolo8/cabina_090_derecha.png",
	"res://ai_assets/apolo8/cabina_180_atras.png",
	"res://ai_assets/apolo8/cabina_270_izquierda.png",
]
const VIEW_NAMES: Array[String] = ["Frente", "Derecha", "Atrás", "Izquierda"]
const STAGE_NODES: Array[String] = ["torre_escape", "capsula_csm", "adaptador_sla", "s_ivb", "s_ii", "s_ic"]

@export_group("Tiempo")
## Segundos de misión por cada segundo real (normal y con avance rápido).
@export var time_scale: float = 5.0
@export var fast_time_scale: float = 20.0
@export var countdown_seconds: int = 10
@export_group("Órdenes")
## Se acepta la orden si llega hasta estos segundos reales antes de tiempo.
@export var early_tolerance_real: float = 1.5
## Si el jugador no da la orden en estos segundos reales, la hace la computadora.
@export var late_limit_real: float = 6.0
@export_group("Estrellas")
@export var errors_for_3_stars: int = 0
@export var errors_for_2_stars: int = 2
@export_group("Vibración")
## Desplazamiento máximo de la cabina (píxeles) con vibración 1.0.
@export var shake_pixels: float = 7.0

var _data: Dictionary = {}
var _telemetry: Array = []
var _events: Array = []
var _phase: Phase = Phase.INTRO
var _mission_time: float = 0.0
var _countdown_left: float = 0.0
var _event_index: int = 0
var _waiting_since: float = -1.0
var _errors: int = 0
var _fast: bool = false
var _view: int = 0
var _stage_id: String = ""
var _windows_open: bool = false
## Etapas ya soltadas (la animación de desaparecer tarda un poco).
var _dropped: Dictionary = {}
var _feedback_tween: Tween

## Partes de la versión 2D (cabina en fotos). La versión 3D no las tiene: pueden ser null.
@onready var _sky_material: ShaderMaterial = (get_node_or_null("%Sky") as CanvasItem).material as ShaderMaterial if has_node("%Sky") else null
## Marco 2:1 con el cielo y la cabina; es lo que vibra.
@onready var _frame: Control = get_node_or_null("ShakeRoot/CockpitFrame") as Control
@onready var _frame_base: Vector2 = _frame.position if _frame else Vector2.ZERO
@onready var _cockpit: TextureRect = get_node_or_null("%Cockpit") as TextureRect
@onready var _clock: Label = %ClockLabel
@onready var _altitude: Label = %AltitudeLabel
@onready var _speed: Label = %SpeedLabel
@onready var _stage_label: Label = %StageLabel
@onready var _engines_label: Label = %EnginesLabel
@onready var _view_label: Label = %ViewLabel
@onready var _stack: VBoxContainer = %Stack
@onready var _info_title: Label = %InfoTitle
@onready var _info_text: Label = %InfoText
@onready var _hint: Label = %HintLabel
@onready var _action: Button = %ActionButton
@onready var _feedback: Label = %FeedbackLabel
@onready var _intro: PanelContainer = %IntroPanel
@onready var _intro_text: Label = %IntroText
@onready var _result: PanelContainer = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_stars: Label = %ResultStars
@onready var _result_text: Label = %ResultText

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_data = load_data(DATA_PATH)
	_telemetry = _data.get("telemetria", []) as Array
	_events = _data.get("eventos", []) as Array
	_reset()

## Lee el JSON de la misión (vacío si falta).
static func load_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("LaunchSimulation: no existe %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}

# --- API pública (pruebas) ---

func get_phase() -> Phase:
	return _phase

func get_mission_time() -> float:
	return _mission_time

func get_errors() -> int:
	return _errors

func get_stars() -> int:
	if _errors <= errors_for_3_stars:
		return 3
	if _errors <= errors_for_2_stars:
		return 2
	return 1

func get_current_stage() -> String:
	return _stage_id

func are_windows_open() -> bool:
	return _windows_open

func is_waiting_for_order() -> bool:
	return _waiting_since >= 0.0

## Siguiente maniobra que necesita una orden del jugador (vacío si no hay).
func get_next_action_event() -> Dictionary:
	for i: int in range(_event_index, _events.size()):
		var e: Dictionary = _events[i]
		if bool(e.get("requiere_accion", false)):
			return e
	return {}

func is_stage_attached(stage: String) -> bool:
	return _stack.has_node(stage) and not _dropped.has(stage)

## Altura (km) y velocidad (km/h) reales del Apolo 8 en un segundo de misión.
func telemetry_at(t: float) -> Vector2:
	if _telemetry.is_empty():
		return Vector2.ZERO
	var prev: Dictionary = _telemetry[0]
	for item: Variant in _telemetry:
		var p: Dictionary = item
		if float(p["t"]) >= t:
			var span: float = maxf(float(p["t"]) - float(prev["t"]), 0.001)
			var k: float = clampf((t - float(prev["t"])) / span, 0.0, 1.0)
			return Vector2(lerpf(float(prev["altitud_km"]), float(p["altitud_km"]), k), lerpf(float(prev["velocidad_kmh"]), float(p["velocidad_kmh"]), k))
		prev = p
	return Vector2(float(prev["altitud_km"]), float(prev["velocidad_kmh"]))

## Botón principal (también con Espacio o Enter).
func press_action() -> void:
	match _phase:
		Phase.INTRO:
			_start_countdown()
		Phase.COUNTDOWN:
			if _countdown_left > early_tolerance_real:
				_add_error("¡Todavía no! Espera a que la cuenta llegue a 0.")
			else:
				_show_feedback("¡Despegue!", Color(0.55, 1, 0.7))
				_liftoff()
		Phase.FLIGHT:
			_try_order()

## Avanza la simulación (lo usa _process y también las pruebas).
func step(real_delta: float) -> void:
	match _phase:
		Phase.COUNTDOWN:
			_countdown_left -= real_delta
			if _countdown_left <= 0.0:
				_countdown_left = 0.0
				if _waiting_since < 0.0:
					_waiting_since = 0.0
					_hint.text = "¡AHORA! Pulsa ¡DESPEGUE!"
				else:
					_waiting_since += real_delta
					if _waiting_since >= late_limit_real:
						_add_error("La computadora encendió los motores por ti.")
						_liftoff()
		Phase.FLIGHT:
			_advance_flight(real_delta)
	_update_hud()

# --- Flujo ---

func _reset() -> void:
	_phase = Phase.INTRO
	_mission_time = 0.0
	_event_index = 0
	_waiting_since = -1.0
	_errors = 0
	_stage_id = ""
	_windows_open = false
	_dropped.clear()
	for n: String in STAGE_NODES:
		var node: Control = _stack.get_node(n) as Control
		node.visible = true
		node.modulate = Color.WHITE
	_set_view(0)
	_intro.visible = true
	_result.visible = false
	_feedback.text = ""
	var crew: Array = _data.get("tripulacion", []) as Array
	_intro_text.text = "Fecha: %s · Cohete: %s\nTripulación: %s\n\nPrimera misión con personas en ir hasta la Luna. Tú das las órdenes del despegue hasta llegar a la órbita de la Tierra: sigue las pistas y pulsa el botón naranja en el momento justo.\n\n%s\n\nMira alrededor de la cabina con las flechas (o Q y E)." % [_data.get("fecha", ""), _data.get("cohete", ""), ", ".join(PackedStringArray(crew)), _data.get("nota_automatica", "")]
	_action.text = "INICIAR CUENTA REGRESIVA"
	_info_title.text = "Antes del despegue"
	_info_text.text = "Las ventanas están tapadas por una cubierta protectora. Se destapan al soltar la torre de escape."
	_hint.text = "Pulsa el botón naranja para empezar."
	_on_reset()
	_update_hud()

func _start_countdown() -> void:
	_phase = Phase.COUNTDOWN
	_countdown_left = float(countdown_seconds)
	_waiting_since = -1.0
	_intro.visible = false
	var first: Dictionary = get_next_action_event()
	_action.text = str(first.get("accion", "¡DESPEGUE!"))
	_hint.text = str(first.get("pista", ""))

func _liftoff() -> void:
	_phase = Phase.FLIGHT
	_waiting_since = -1.0
	_apply_event(_events[_event_index] as Dictionary)
	_event_index += 1
	_prepare_next_action()
	launched.emit()

func _advance_flight(real_delta: float) -> void:
	if _event_index >= _events.size():
		return
	var e: Dictionary = _events[_event_index]
	var t_event: float = float(e["t"])
	if _waiting_since >= 0.0:
		_waiting_since += real_delta
		if _waiting_since >= late_limit_real:
			_add_error("La computadora hizo la maniobra por ti.")
			_complete_order(e, false)
		return
	var scale: float = fast_time_scale if _fast else time_scale
	_mission_time = minf(_mission_time + real_delta * scale, t_event)
	if _mission_time >= t_event:
		if bool(e.get("requiere_accion", false)):
			_waiting_since = 0.0
			_hint.text = "¡AHORA! " + str(e.get("accion", ""))
		else:
			_apply_event(e)
			_event_index += 1
			if bool(e.get("fin", false)):
				_finish()

func _try_order() -> void:
	if _event_index >= _events.size():
		return
	var e: Dictionary = _events[_event_index]
	if not bool(e.get("requiere_accion", false)):
		_add_error("¡Todavía no! Espera la próxima maniobra.")
		return
	var scale: float = fast_time_scale if _fast else time_scale
	var seconds_left_real: float = (float(e["t"]) - _mission_time) / scale
	if _waiting_since < 0.0 and seconds_left_real > early_tolerance_real:
		_add_error("¡Muy pronto! Mira la pista y el reloj.")
		return
	_complete_order(e, true)

func _complete_order(e: Dictionary, on_time: bool) -> void:
	_mission_time = float(e["t"])
	_waiting_since = -1.0
	_apply_event(e)
	_event_index += 1
	if on_time:
		_show_feedback("¡Perfecto! " + str(e.get("titulo", "")), Color(0.55, 1, 0.7))
	maneuver_done.emit(str(e["id"]), on_time)
	_prepare_next_action()

## Aplica lo que pasa en una maniobra: etapa activa, piezas que se sueltan, ventanas.
func _apply_event(e: Dictionary) -> void:
	_info_title.text = str(e.get("titulo", ""))
	_info_text.text = str(e.get("texto", ""))
	if e.has("etapa"):
		_stage_id = str(e["etapa"])
	if e.has("quitar"):
		_drop_stage(str(e["quitar"]))
	if bool(e.get("ventanas", false)):
		_windows_open = true
	if str(e.get("id", "")) == "separar_sic":
		_jolt()

func _prepare_next_action() -> void:
	var next: Dictionary = get_next_action_event()
	if next.is_empty():
		_action.text = "EN CAMINO A LA ÓRBITA..."
		_hint.text = "Espera unos segundos."
	else:
		_action.text = str(next.get("accion", ""))
		_hint.text = str(next.get("pista", ""))

func _finish() -> void:
	_phase = Phase.DONE
	_stage_id = ""
	var stars: int = get_stars()
	_result_title.text = "¡Apolo 8 en órbita!"
	_result_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	_result_text.text = "Errores: %d\n\nLlegaste a %d km de altura y %s km/h, como el Apolo 8 real, en 11 minutos y 35 segundos de vuelo.\n\nFuentes: tabla de ascenso del Apolo 8 (NASA SP-4029) e informe de la misión." % [_errors, int(telemetry_at(_mission_time).x), _thousands(int(telemetry_at(_mission_time).y))]
	_result.visible = true
	_action.text = "¡MISIÓN CUMPLIDA!"
	_hint.text = ""
	mission_completed.emit(stars, _errors)

# --- Visuales ---

func _process(delta: float) -> void:
	step(delta)
	if _sky_material:
		_sky_material.set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
	_update_visuals(delta)
	_shake(delta)
	# El botón late cuando el cohete espera la orden.
	var pulse: float = 1.0 + 0.05 * sin(Time.get_ticks_msec() / 90.0) if is_waiting_for_order() else 1.0
	_action.scale = Vector2.ONE * pulse

func _update_hud() -> void:
	var tel: Vector2 = telemetry_at(_mission_time)
	if _phase == Phase.COUNTDOWN or _phase == Phase.INTRO:
		var left: int = int(ceil(_countdown_left)) if _phase == Phase.COUNTDOWN else countdown_seconds
		_clock.text = "T− %s" % _format_time(float(left))
	else:
		_clock.text = "T+ %s" % _format_time(_mission_time)
	_altitude.text = "Altura: %s km" % _decimal(tel.x)
	_speed.text = "Velocidad: %s km/h" % _thousands(int(tel.y))
	var stages: Dictionary = _data.get("etapas", {}) as Dictionary
	if stages.has(_stage_id):
		var s: Dictionary = stages[_stage_id]
		_stage_label.text = "Empuja: " + str(s["nombre"])
		_engines_label.text = "%s · %s" % [s["motores"], s["combustible"]]
	else:
		_stage_label.text = "Motores apagados" if _phase != Phase.INTRO else "En la plataforma 39A"
		_engines_label.text = ""
	if _sky_material:
		_sky_material.set_shader_parameter("altitude_km", tel.x)
		_sky_material.set_shader_parameter("covered", 0.0 if _windows_open else 1.0)
	for n: String in ["s_ic", "s_ii", "s_ivb"]:
		var node: Control = _stack.get_node(n) as Control
		if not _dropped.has(n):
			node.modulate = Color(1.35, 1.15, 0.7) if n == _stage_id else Color.WHITE

func _shake(_delta: float) -> void:
	if _frame == null:
		return
	var stages: Dictionary = _data.get("etapas", {}) as Dictionary
	var amount: float = 0.0
	if _phase == Phase.FLIGHT and stages.has(_stage_id) and not is_waiting_for_order():
		amount = float((stages[_stage_id] as Dictionary).get("vibracion", 0.0))
		# Más sacudida cerca de la presión máxima (Max Q, ~79 s).
		amount *= 1.0 + 0.8 * exp(-pow((_mission_time - 79.0) / 25.0, 2.0))
	var t: float = Time.get_ticks_msec() / 1000.0
	_frame.position = _frame_base + Vector2(sin(t * 53.0), cos(t * 47.0)) * shake_pixels * amount

func _jolt() -> void:
	_on_stage_jolt()
	if not is_inside_tree() or _cockpit == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_cockpit, "scale", Vector2(1.04, 1.04), 0.08)
	tween.tween_property(_cockpit, "scale", Vector2.ONE, 0.35)

func _drop_stage(stage: String) -> void:
	var node: Control = _stack.get_node_or_null(stage) as Control
	if node == null:
		return
	_dropped[stage] = true
	_on_stage_dropped(stage)
	if not is_inside_tree():
		node.visible = false
		return
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: node.visible = false)
	node.modulate = Color(1, 1, 1, node.modulate.a)

func _set_view(index: int) -> void:
	_view = wrapi(index, 0, VIEW_TEXTURES.size())
	if _cockpit == null:
		return
	_cockpit.texture = load(VIEW_TEXTURES[_view]) as Texture2D
	_view_label.text = "Vista: %s (%d/%d)" % [VIEW_NAMES[_view], _view + 1, VIEW_TEXTURES.size()]

## Valor de cualquier columna de la telemetría (por ejemplo "alcance_km") en un segundo de misión.
func telemetry_value(t: float, key: String) -> float:
	if _telemetry.is_empty():
		return 0.0
	var prev: Dictionary = _telemetry[0]
	for item: Variant in _telemetry:
		var p: Dictionary = item
		if float(p["t"]) >= t:
			var span: float = maxf(float(p["t"]) - float(prev["t"]), 0.001)
			return lerpf(float(prev.get(key, 0.0)), float(p.get(key, 0.0)), clampf((t - float(prev["t"])) / span, 0.0, 1.0))
		prev = p
	return float(prev.get(key, 0.0))

# --- Ganchos para la versión 3D (no hacen nada en la 2D) ---

## Se llama cada cuadro para mover cámaras, cohete, Tierra y fuego.
func _update_visuals(_delta: float) -> void:
	pass

## Se llama cuando una etapa (o la torre de escape) se suelta.
func _on_stage_dropped(_stage: String) -> void:
	pass

## Se llama al empezar o repetir la misión.
func _on_reset() -> void:
	pass

## Sacudida al separar la 1.ª etapa.
func _on_stage_jolt() -> void:
	pass

func _add_error(message: String) -> void:
	_errors += 1
	_show_feedback(message, Color(1, 0.6, 0.35))

func _show_feedback(message: String, color: Color) -> void:
	_feedback.text = message
	_feedback.add_theme_color_override("font_color", color)
	_feedback.modulate.a = 1.0
	if not is_inside_tree():
		return
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(1.6)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.6)

static func _format_time(seconds: float) -> String:
	var s: int = int(seconds)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]

static func _thousands(value: int) -> String:
	var text: String = str(absi(value))
	var out: String = ""
	while text.length() > 3:
		out = " " + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return text + out

static func _decimal(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")

# --- Entrada y botones ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		press_action()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key: Key = (event as InputEventKey).keycode
		if key == KEY_Q or key == KEY_LEFT:
			_set_view(_view - 1)
		elif key == KEY_E or key == KEY_RIGHT:
			_set_view(_view + 1)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()

func _on_action_pressed() -> void:
	press_action()

func _on_view_left() -> void:
	_set_view(_view - 1)

func _on_view_right() -> void:
	_set_view(_view + 1)

func _on_fast_toggled(on: bool) -> void:
	_fast = on

func _on_retry_pressed() -> void:
	_reset()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
