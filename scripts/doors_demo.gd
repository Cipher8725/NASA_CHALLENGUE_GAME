class_name DoorsDemo
extends Node3D

## Sala de prueba de puertas: una puerta automática (zona común) y una puerta
## restringida (laboratorio) que pide carnet de nivel 2.
## Muestra el carnet del jugador cuando lo pasa por el lector.

const MENU_SCENE: String = "res://scenes/main_menu.tscn"
## Segundos que el carnet queda en pantalla después de pasarlo.
@export var card_show_time: float = 3.5

@onready var _restricted_door: SlidingDoor = %RestrictedDoor
@onready var _card_view: AstronautCardView = %CardView
@onready var _card_message: Label = %CardMessage
@onready var _card_panel: Control = %CardPanel

func _ready() -> void:
	_card_panel.visible = false
	_restricted_door.access_granted.connect(_on_access_granted)
	_restricted_door.access_denied.connect(_on_access_denied)

func _unhandled_input(event: InputEvent) -> void:
	# Clic en la pantalla: captura el ratón para mirar alrededor (Esc lo libera).
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_access_granted(card: AstronautCard) -> void:
	_show_card(card, tr("ACCESO CONCEDIDO"))

func _on_access_denied(reason: String) -> void:
	_show_card(AstronautCard.load_saved(), reason.replace("\n", " · "))

func _show_card(card: AstronautCard, message: String) -> void:
	_card_message.text = message
	_card_panel.visible = true
	if card != null:
		_card_view.visible = true
		_card_view.show_card(card)
	else:
		_card_view.visible = false
	var timer: SceneTreeTimer = get_tree().create_timer(card_show_time)
	timer.timeout.connect(func() -> void: _card_panel.visible = false)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
