class_name AstronautCard
extends Resource

## Carnet del astronauta (jugador).
##
## Guarda quién es el jugador y qué zonas puede abrir. Se guarda en el equipo
## del jugador (`user://`) para que el carnet siga ahí la próxima vez que juegue.
## Nivel de acceso:
##   1 = Cadete: puertas normales.
##   2 = Técnico de rover: también zonas restringidas. Se gana aprobando la
##       evaluación del Taller del Rover con 2 estrellas o más.

## Dónde se guarda el carnet del jugador.
const SAVE_PATH: String = "user://carnet_astronauta.tres"
## Nombre de cada nivel de acceso (el índice es el nivel).
const RANKS: Array[String] = ["Sin acceso", "Cadete astronauta", "Técnico de rover", "Comandante de base"]
## Cantidad de avatares disponibles en `res://ai_assets/textures/avatares/`.
const AVATAR_COUNT: int = 6
const AVATAR_PATH: String = "res://ai_assets/textures/avatares/avatar_%d.png"
## Dónde se guarda la foto real del jugador (solo en su computadora; no se envía a internet).
const PHOTO_PATH: String = "user://carnet_foto.png"

@export var nombre: String = ""
## Número de avatar (1 a AVATAR_COUNT). Se usa cuando no hay foto.
@export var avatar: int = 1
## Ruta de la foto del jugador (vacía = usar el avatar).
@export var foto: String = ""
## Número de identificación único, por ejemplo "SEL-2026-4821".
@export var numero: String = ""
@export var nivel_acceso: int = 1
## Base a la que pertenece el astronauta.
@export var base: String = "Base Lunar Selene"
## Fechas en formato AAAA-MM-DD.
@export var fecha_emision: String = ""
@export var fecha_vencimiento: String = ""

## Crea un carnet nuevo de nivel 1 con un número aleatorio y la fecha de hoy.
static func create(player_name: String, avatar_number: int) -> AstronautCard:
	var card: AstronautCard = AstronautCard.new()
	card.nombre = player_name.strip_edges()
	card.avatar = clampi(avatar_number, 1, AVATAR_COUNT)
	var today: Dictionary = Time.get_date_dict_from_system()
	card.numero = "SEL-%d-%04d" % [int(today["year"]), randi_range(1000, 9999)]
	card.fecha_emision = "%04d-%02d-%02d" % [int(today["year"]), int(today["month"]), int(today["day"])]
	card.fecha_vencimiento = "%04d-%02d-%02d" % [int(today["year"]) + 1, int(today["month"]), int(today["day"])]
	card.nivel_acceso = 1
	return card

## Carga el carnet guardado (null si el jugador todavía no creó uno).
static func load_saved(path: String = SAVE_PATH) -> AstronautCard:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AstronautCard

func save_card(path: String = SAVE_PATH) -> bool:
	return ResourceSaver.save(self, path) == OK

func get_rank() -> String:
	return tr(RANKS[clampi(nivel_acceso, 0, RANKS.size() - 1)])

func has_photo() -> bool:
	return not foto.is_empty() and FileAccess.file_exists(foto)

## Foto del jugador si tiene una; si no, su avatar dibujado.
func get_avatar_texture() -> Texture2D:
	if has_photo():
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(foto))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return load(AVATAR_PATH % clampi(avatar, 1, AVATAR_COUNT)) as Texture2D

## Guarda una foto ya recortada y la usa en el carnet.
func set_photo(image: Image, path: String = PHOTO_PATH) -> bool:
	if image == null or image.is_empty():
		return false
	if image.save_png(path) != OK:
		return false
	foto = path
	return true

## Vuelve a usar el avatar dibujado (la foto guardada se borra del equipo).
func remove_photo() -> void:
	if not foto.is_empty() and FileAccess.file_exists(foto):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(foto))
	foto = ""

func can_open(required_level: int) -> bool:
	return nivel_acceso >= required_level
