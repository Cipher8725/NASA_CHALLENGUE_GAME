class_name CardEditor
extends Control

## Pantalla "MI CARNET": el jugador escribe su nombre, se toma una foto con la
## cámara (o sube una, o elige un dibujo) y guarda su carnet de astronauta. Desde aquí también puede probarlo en la
## sala de puertas.

const MENU_SCENE: String = "res://scenes/main_menu.tscn"
const DOORS_SCENE: String = "res://scenes/doors_demo.tscn"
## Largo máximo del nombre en el carnet.
const MAX_NAME_LENGTH: int = 22

var _card: AstronautCard

@onready var _name_edit: LineEdit = %NameEdit
@onready var _avatar_row: HBoxContainer = %AvatarRow
@onready var _avatar_template: Button = %AvatarTemplate
@onready var _preview: AstronautCardView = %CardPreview
@onready var _message: Label = %MessageLabel
@onready var _try_button: Button = %TryButton
@onready var _booth: PhotoBooth = %PhotoBooth
@onready var _remove_photo_button: Button = %RemovePhotoButton

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_name_edit.max_length = MAX_NAME_LENGTH
	_card = AstronautCard.load_saved()
	if _card == null:
		_card = AstronautCard.create("", 1)
		_message.text = "Escribe tu nombre, elige tu foto y pulsa GUARDAR."
		_try_button.disabled = true
	else:
		_message.text = "Este es tu carnet. Puedes cambiar tu nombre o tu foto."
	_name_edit.text = _card.nombre
	_build_avatar_buttons()
	_remove_photo_button.disabled = not _card.has_photo()
	_preview.show_card(_card)

## Un botón por avatar, copiando la plantilla de la escena.
func _build_avatar_buttons() -> void:
	for i: int in range(1, AstronautCard.AVATAR_COUNT + 1):
		var button: Button = _avatar_template.duplicate() as Button
		button.visible = true
		button.icon = load(AstronautCard.AVATAR_PATH % i) as Texture2D
		button.pressed.connect(_on_avatar_pressed.bind(i))
		_avatar_row.add_child(button)
	_avatar_template.visible = false

func _on_name_changed(new_text: String) -> void:
	_card.nombre = new_text.strip_edges()
	_preview.show_card(_card)

func _on_avatar_pressed(number: int) -> void:
	_card.avatar = number
	if _card.has_photo():
		_card.remove_photo()
		_remove_photo_button.disabled = true
	_preview.show_card(_card)

func _on_photo_pressed() -> void:
	_booth.open_booth()

## La cabina entrega la foto ya recortada (y con casco si el jugador quiso).
func _on_photo_taken(photo: Image) -> void:
	if _card.set_photo(photo):
		_remove_photo_button.disabled = false
		_message.text = "¡Foto lista! Pulsa GUARDAR para ponerla en tu carnet."
	else:
		_message.text = "No se pudo guardar la foto."
	_preview.show_card(_card)

func _on_remove_photo_pressed() -> void:
	_card.remove_photo()
	_remove_photo_button.disabled = true
	_message.text = "Foto quitada. Ahora se usa tu dibujo. Pulsa GUARDAR."
	_preview.show_card(_card)

func _on_save_pressed() -> void:
	if _card.nombre.is_empty():
		_message.text = "Falta tu nombre: escríbelo arriba."
		return
	if _card.save_card():
		_message.text = "¡Carnet guardado! Nivel %d: %s. Aprueba la EVALUACIÓN del Taller del Rover para subir a nivel 2." % [_card.nivel_acceso, _card.get_rank()]
		_try_button.disabled = false
	else:
		_message.text = "No se pudo guardar el carnet."

func _on_try_pressed() -> void:
	get_tree().change_scene_to_file(DOORS_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
