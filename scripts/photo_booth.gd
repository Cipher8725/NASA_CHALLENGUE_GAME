class_name PhotoBooth
extends Control

## Cabina de fotos del carnet.
##
## Muestra la cámara de la computadora en vivo, cuenta 3, 2, 1 y toma la foto.
## Si no hay cámara (o no da permiso), el jugador puede SUBIR una foto desde
## sus archivos. La foto se puede usar con el casco de astronauta puesto.
## La foto solo se guarda en esta computadora: no se envía a internet.
##
## Nota: la cámara usa CameraServer de Godot. Funciona según el sistema y la
## versión de Godot; si no aparece ninguna cámara, queda la opción de subir foto.

signal photo_taken(photo: Image)
signal cancelled

## Segundos de la cuenta regresiva.
@export var countdown_seconds: int = 3
## La vista previa se ve como un espejo (más natural para una selfie).
@export var mirror_preview: bool = true
## Segundos que espera a que el sistema encuentre la cámara.
@export var camera_wait_seconds: float = 2.0

var _feed: CameraFeed
var _captured: Image
var _counting: bool = false

@onready var _viewport: SubViewport = %CaptureViewport
@onready var _live: TextureRect = %LiveView
@onready var _helmet_view: TextureRect = %HelmetPreview
@onready var _result: TextureRect = %ResultView
@onready var _countdown: Label = %CountdownLabel
@onready var _status: Label = %StatusLabel
@onready var _helmet_toggle: CheckButton = %HelmetToggle
@onready var _shoot_button: Button = %ShootButton
@onready var _upload_button: Button = %UploadButton
@onready var _use_button: Button = %UseButton
@onready var _retry_button: Button = %RetryButton
@onready var _file_dialog: FileDialog = %FileDialog

func _ready() -> void:
	_file_dialog.file_selected.connect(_on_file_selected)
	_helmet_toggle.toggled.connect(_on_helmet_toggled)
	_show_live_mode()

## Abre la cabina y enciende la cámara si hay una.
func open_booth() -> void:
	visible = true
	_captured = null
	_show_live_mode()
	await start_camera()

func has_camera() -> bool:
	return _feed != null

func get_captured() -> Image:
	return _captured

## Busca una cámara y la enciende. Devuelve true si hay imagen en vivo.
func start_camera() -> bool:
	_status.text = tr("Buscando tu cámara...")
	CameraServer.monitoring_feeds = true
	var waited: float = 0.0
	while CameraServer.get_feed_count() == 0 and waited < camera_wait_seconds and is_inside_tree():
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if CameraServer.get_feed_count() == 0:
		_feed = null
		_shoot_button.disabled = true
		_status.text = tr("No encontramos una cámara. Pulsa SUBIR UNA FOTO para elegir una imagen tuya.")
		return false
	_feed = _pick_front_feed()
	_choose_format(_feed)
	_feed.feed_is_active = true
	_connect_preview(_feed)
	_shoot_button.disabled = false
	_status.text = tr("Mira a la cámara, sonríe y pulsa TOMAR FOTO.")
	return true

func stop_camera() -> void:
	if _feed:
		_feed.feed_is_active = false
	_feed = null
	CameraServer.monitoring_feeds = false

## Toma la foto con cuenta regresiva.
func shoot() -> void:
	if _counting or _feed == null:
		return
	_counting = true
	_shoot_button.disabled = true
	for i: int in range(countdown_seconds, 0, -1):
		_countdown.text = str(i)
		await get_tree().create_timer(1.0).timeout
	_countdown.text = ""
	await RenderingServer.frame_post_draw
	_set_captured(_viewport.get_texture().get_image())
	_counting = false

## Usa una imagen ya cargada (foto subida o de la cámara).
func use_image(source: Image) -> void:
	_set_captured(PhotoTools.crop_to_card(source))

# --- Botones ---

func _on_shoot_pressed() -> void:
	shoot()

func _on_upload_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.7)

func _on_file_selected(path: String) -> void:
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		_status.text = tr("No se pudo abrir esa imagen. Prueba con un archivo PNG o JPG.")
		return
	use_image(image)

func _on_use_pressed() -> void:
	if _captured == null:
		return
	var final_photo: Image = PhotoTools.add_helmet(_captured) if _helmet_toggle.button_pressed else _captured
	stop_camera()
	visible = false
	photo_taken.emit(final_photo)

func _on_retry_pressed() -> void:
	_captured = null
	_show_live_mode()
	if _feed:
		_status.text = tr("Otra vez: mira a la cámara y pulsa TOMAR FOTO.")

func _on_cancel_pressed() -> void:
	stop_camera()
	visible = false
	cancelled.emit()

func _on_helmet_toggled(on: bool) -> void:
	_helmet_view.visible = on

# --- Ayudas ---

func _set_captured(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	if image.get_size() != PhotoTools.CARD_PHOTO_SIZE:
		image = PhotoTools.crop_to_card(image)
	_captured = image
	_result.texture = ImageTexture.create_from_image(image)
	_result.visible = true
	_live.visible = false
	_use_button.visible = true
	_retry_button.visible = true
	_shoot_button.visible = false
	_status.text = tr("¿Te gusta? Pulsa USAR ESTA FOTO o REPETIR.")

func _show_live_mode() -> void:
	_result.visible = false
	_live.visible = true
	_use_button.visible = false
	_retry_button.visible = false
	_shoot_button.visible = true
	_countdown.text = ""
	_helmet_view.visible = _helmet_toggle.button_pressed

func _pick_front_feed() -> CameraFeed:
	for i: int in CameraServer.get_feed_count():
		var feed: CameraFeed = CameraServer.get_feed(i)
		if feed.get_position() == CameraFeed.FEED_FRONT:
			return feed
	return CameraServer.get_feed(0)

## Elige el formato más cercano a 640 x 480 (suficiente para el carnet y liviano).
func _choose_format(feed: CameraFeed) -> void:
	var formats: Array = feed.get_formats()
	if formats.is_empty():
		return
	var best: int = 0
	var best_score: int = 1 << 30
	for i: int in formats.size():
		var f: Dictionary = formats[i]
		var score: int = absi(int(f.get("width", 0)) - 640) + absi(int(f.get("height", 0)) - 480)
		if score < best_score:
			best_score = score
			best = i
	feed.set_format(best, {})

func _connect_preview(feed: CameraFeed) -> void:
	var material: ShaderMaterial = _live.material as ShaderMaterial
	var ycbcr: bool = feed.get_datatype() == CameraFeed.FEED_YCBCR_SEP
	var main_tex: CameraTexture = CameraTexture.new()
	main_tex.camera_feed_id = feed.get_id()
	main_tex.which_feed = CameraServer.FEED_Y_IMAGE if ycbcr else CameraServer.FEED_RGBA_IMAGE
	_live.texture = main_tex
	if material:
		material.set_shader_parameter("use_ycbcr", ycbcr)
		material.set_shader_parameter("mirror", mirror_preview)
		if ycbcr:
			var cbcr: CameraTexture = CameraTexture.new()
			cbcr.camera_feed_id = feed.get_id()
			cbcr.which_feed = CameraServer.FEED_CBCR_IMAGE
			material.set_shader_parameter("tex_cbcr", cbcr)

func _exit_tree() -> void:
	if _feed:
		_feed.feed_is_active = false
