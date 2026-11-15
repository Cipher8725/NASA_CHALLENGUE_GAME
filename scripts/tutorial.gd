class_name Tutorial
extends Control

## Tutorial "Control de misión": explica en pocas páginas el objetivo, los controles,
## los recursos, las consolas y las emergencias de la Base Lunar.
##
## - Sale solo la primera vez que se juega la base (`GameSettings` [juego] tutorial_visto)
##   y se puede volver a ver desde el menú de pausa ("Cómo jugar").
## - Mientras está abierto, el juego queda en pausa (este nodo sigue procesando).

signal closed

const SETTINGS_SECTION: String = "juego"
const SETTINGS_KEY: String = "tutorial_visto"

var _page: int = 0
var _pages: Array[Dictionary] = []

@onready var _step: Label = %StepLabel
@onready var _title: Label = %TitleLabel
@onready var _body: RichTextLabel = %BodyText
@onready var _back: Button = %BackButton
@onready var _next: Button = %NextButton
@onready var _skip: Button = %SkipButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("tutorial")
	_back.pressed.connect(previous_page)
	_next.pressed.connect(next_page)
	_skip.pressed.connect(close)
	_build_pages()
	_show_page()
	_next.grab_focus()

## ¿Ya vio el tutorial alguna vez?
static func was_seen() -> bool:
	return GameSettings.get_bool(SETTINGS_SECTION, SETTINGS_KEY, false)

static func mark_seen() -> void:
	GameSettings.set_value(SETTINGS_SECTION, SETTINGS_KEY, true)

func next_page() -> void:
	if _page >= _pages.size() - 1:
		close()
		return
	_page += 1
	_show_page()

func previous_page() -> void:
	if _page > 0:
		_page -= 1
		_show_page()

func get_page() -> int:
	return _page

func get_page_count() -> int:
	return _pages.size()

## Cierra el tutorial, lo marca como visto y avisa a quien lo abrió.
func close() -> void:
	mark_seen()
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _build_pages() -> void:
	var minutes: int = 3
	var game: GameManager = GameManager.get_instance()
	if game != null and game.config != null:
		minutes = maxi(1, int(ceil(game.config.mission_duration / 60.0)))
	_pages = [
		{
			"title": tr("¡Bienvenido a la Base Lunar Selene!"),
			"body": tr("Eres un [b]astronauta junior[/b] y hoy estás a cargo de la base.\n\nTu misión: mantener a la tripulación con vida durante [b]%d minutos[/b], hasta que llegue el relevo desde la Tierra.\n\nCada dato que verás (radiación, tormentas solares, cultivos) viene de estudios reales de la NASA.") % minutes,
		},
		{
			"title": tr("Controles"),
			"body": tr("[b]W A S D[/b]: caminar\n[b]Ratón[/b]: mirar\n[b]E[/b]: usar una consola\n[b]ESPACIO[/b]: saltar · acción en los minijuegos\n[b]R[/b]: reiniciar la misión\n[b]ESC[/b]: pausa (continuar, cómo jugar, idioma y volumen)"),
		},
		{
			"title": tr("Los recursos de la base"),
			"body": tr("Arriba a la izquierda ves cinco barras:\n\n[color=#4fc2f7]■ OXÍGENO[/color]   [color=#ffc947]■ ENERGÍA[/color]   [color=#47dbbf]■ AGUA[/color]\n[color=#c28cff]■ ESCUDO ANTIRRADIACIÓN[/color]   [color=#8ce04d]■ COMIDA[/color]\n\nTodas bajan con el tiempo. Si [b]una llega a cero[/b], la misión falla. Cuando una barra se pone roja, ¡corre a repararla!"),
		},
		{
			"title": tr("Consolas y reparaciones"),
			"body": tr("Cada recurso tiene su consola en una sala. Acércate y pulsa [b]E[/b].\n\n• [b]Oxígeno[/b]: purga la presión cuando la aguja del manómetro esté en la zona verde.\n• [b]Energía[/b]: conecta cada cable con su letra.\n• [b]Huerto[/b]: elige la luz, riega y cosecha como en la ISS.\n• [b]Agua y escudo[/b]: se reparan al instante."),
		},
		{
			"title": tr("Emergencias"),
			"body": tr("La base puede sufrir [b]tormentas solares[/b] (llamaradas reales registradas por la NASA), micrometeoritos, fugas de agua y sobrecargas.\n\nLee las alertas en rojo: te dicen qué recurso se dañó. Mantén el escudo alto para soportar la radiación.\n\n[b]¡Suerte, astronauta![/b]"),
		},
	]

func _show_page() -> void:
	var page: Dictionary = _pages[_page]
	_step.text = tr("CONTROL DE MISIÓN · %d / %d") % [_page + 1, _pages.size()]
	_title.text = str(page["title"])
	_body.text = str(page["body"])
	_back.disabled = _page == 0
	_next.text = tr("¡A la misión!") if _page == _pages.size() - 1 else tr("Siguiente")
