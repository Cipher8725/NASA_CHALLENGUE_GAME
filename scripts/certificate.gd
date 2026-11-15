class_name Certificate
extends Control

## Certificado de Astronauta Junior: se gana con medalla en la Base Lunar, el Taller del Rover
## y el Despegue del Apolo 8. Muestra el nombre y la foto del carnet, las medallas y la fecha.
## "Guardar imagen" lo guarda como PNG en la carpeta Imágenes del jugador (o en user://).
## Es un diploma del juego: no es un documento oficial de la NASA.

const CARD_SCENE: String = "res://scenes/card_editor.tscn"
const FILE_NAME: String = "certificado_astronauta_junior.png"

@onready var _paper: Control = %Paper
@onready var _name: Label = %NameLabel
@onready var _photo: TextureRect = %Photo
@onready var _date: Label = %DateLabel
@onready var _number: Label = %NumberLabel
@onready var _medals: HBoxContainer = %Medals
@onready var _seal: MedalIcon = %Seal
@onready var _message: Label = %MessageLabel
@onready var _save: Button = %SaveButton
@onready var _back: Button = %BackButton

var _saved_path: String = ""

func _ready() -> void:
	AudioManager.music(&"menu")
	_save.pressed.connect(save_image)
	_back.pressed.connect(func() -> void: get_tree().change_scene_to_file(CARD_SCENE))
	fill()

## Rellena el certificado con el carnet y el progreso guardados.
func fill() -> void:
	var card: AstronautCard = AstronautCard.load_saved()
	var player_name: String = card.nombre if card != null and not card.nombre.is_empty() else tr("Astronauta")
	_name.text = player_name.to_upper()
	_photo.texture = card.get_avatar_texture() if card != null else load(AstronautCard.AVATAR_PATH % 1) as Texture2D
	_number.text = tr("Carnet N.º %s") % card.numero if card != null and not card.numero.is_empty() else ""
	var date: String = PlayerProgress.get_certificate_date()
	_date.text = tr("Fecha: %s") % (date if not date.is_empty() else Time.get_date_string_from_system())
	var best: int = PlayerProgress.GOLD
	for i: int in PlayerProgress.MODULES.size():
		var module: StringName = PlayerProgress.MODULES[i]
		var medal: int = PlayerProgress.get_medal(module)
		var box: Node = _medals.get_child(i)
		(box.get_node("Icon") as MedalIcon).medal = medal
		(box.get_node("Name") as Label).text = tr(String(PlayerProgress.MODULE_NAMES[module]))
		(box.get_node("Level") as Label).text = tr(PlayerProgress.MEDAL_NAMES[medal])
		if PlayerProgress.CERTIFICATE_MODULES.has(module):
			best = mini(best, medal)
	# El sello toma el nivel más bajo de los tres módulos obligatorios.
	_seal.medal = maxi(best, PlayerProgress.BRONZE)
	if not PlayerProgress.has_certificate():
		_message.text = tr("Aún te falta completar algún módulo para ganar el certificado.")

## Guarda el certificado como imagen PNG. Devuelve la ruta donde quedó.
func save_image() -> String:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var rect: Rect2i = Rect2i(_paper.get_global_rect())
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var cropped: Image = image.get_region(rect) if rect.size.x > 0 and rect.size.y > 0 else image
	var folder: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		folder = ProjectSettings.globalize_path("user://")
	_saved_path = folder.path_join(FILE_NAME)
	if cropped.save_png(_saved_path) == OK:
		_message.text = tr("Guardado en: %s") % _saved_path
		AudioManager.sfx(&"shutter")
	else:
		_message.text = tr("No se pudo guardar la imagen.")
		_saved_path = ""
	return _saved_path

func get_saved_path() -> String:
	return _saved_path
