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
@onready var _medal_row: HBoxContainer = %Row
@onready var _certificate_button: Button = %CertificateButton
@onready var _certificate_hint: Label = %CertificateHint

const CERTIFICATE_SCENE: String = "res://scenes/certificate.tscn"

func _ready() -> void:
	AudioManager.music(&"menu")
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_name_edit.max_length = MAX_NAME_LENGTH
	_card = AstronautCard.load_saved()
	if _card == null:
		_card = AstronautCard.create("", 1)
		_message.text = tr("Escribe tu nombre, elige tu foto y pulsa GUARDAR.")
		_try_button.disabled = true
	else:
		_message.text = tr("Este es tu carnet. Puedes cambiar tu nombre o tu foto.")
	_name_edit.text = _card.nombre
	_build_avatar_buttons()
	_remove_photo_button.disabled = not _card.has_photo()
	_preview.show_card(_card)
	refresh_medals()
	show_guide.call_deferred(false)

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
		_message.text = tr("¡Foto lista! Pulsa GUARDAR para ponerla en tu carnet.")
	else:
		_message.text = tr("No se pudo guardar la foto.")
	_preview.show_card(_card)

func _on_remove_photo_pressed() -> void:
	_card.remove_photo()
	_remove_photo_button.disabled = true
	_message.text = tr("Foto quitada. Ahora se usa tu dibujo. Pulsa GUARDAR.")
	_preview.show_card(_card)

func _on_save_pressed() -> void:
	if _card.nombre.is_empty():
		_message.text = tr("Falta tu nombre: escríbelo arriba.")
		return
	if _card.save_card():
		_message.text = tr("¡Carnet guardado! Nivel %d: %s. Aprueba la EVALUACIÓN del Taller del Rover para subir a nivel 2.") % [_card.nivel_acceso, tr(_card.get_rank())]
		_try_button.disabled = false
	else:
		_message.text = tr("No se pudo guardar el carnet.")

## Pinta las medallas ganadas y habilita el certificado si ya se ganó.
func refresh_medals() -> void:
	for i: int in PlayerProgress.MODULES.size():
		var icon: MedalIcon = _medal_row.get_child(i).get_node("Icon") as MedalIcon
		var module: StringName = PlayerProgress.MODULES[i]
		icon.medal = PlayerProgress.get_medal(module)
		icon.tooltip_text = "%s: %s" % [tr(String(PlayerProgress.MODULE_NAMES[module])), tr(PlayerProgress.MEDAL_NAMES[icon.medal])]
	var earned: bool = PlayerProgress.has_certificate()
	_certificate_button.disabled = not earned
	if earned:
		_certificate_hint.text = tr("¡Felicidades, astronauta!")
	else:
		var missing: PackedStringArray = []
		for module: StringName in PlayerProgress.missing_for_certificate():
			missing.append(tr(String(PlayerProgress.MODULE_NAMES[module])))
		_certificate_hint.text = tr("Falta: %s") % ", ".join(missing)

func _on_certificate_pressed() -> void:
	get_tree().change_scene_to_file(CERTIFICATE_SCENE)

func _on_try_pressed() -> void:
	get_tree().change_scene_to_file(DOORS_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

# --- Tutorial ---

## Tutorial de "Mi carnet".
func show_guide(force: bool = true) -> GuideOverlay:
	return GuideOverlay.start(self, "carnet", [
		GuideOverlay.step(tr("1. Tu nombre"),
			tr("Escribe tu nombre de astronauta."), _name_edit),
		GuideOverlay.step(tr("2. Tu foto"),
			tr("Elige un dibujo o pulsa [b]TOMAR MI FOTO[/b] para usar la cámara."), %AvatarRow),
		GuideOverlay.step(tr("Tu carnet"),
			tr("Así queda tu carnet. Pulsa [b]GUARDAR MI CARNET[/b] para conservarlo: abre las puertas de la base y sube de nivel cuando completas misiones."), _preview),
		GuideOverlay.step(tr("Medallas y certificado"),
			tr("Aquí aparecen tus medallas de cada misión. Con medalla en Base, Rover y Despegue se desbloquea tu [b]Certificado de Astronauta Junior[/b]."), %Row),
	], false, force)
