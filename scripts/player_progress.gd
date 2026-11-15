class_name PlayerProgress
extends RefCounted

## Medallas del jugador y Certificado de Astronauta Junior.
##
## Cada módulo da una medalla según cómo se jugó (se guarda la mejor):
##   - Base Lunar: % medio de recursos al terminar la misión (≥ 60 % oro, ≥ 35 % plata, si no bronce).
##   - Taller del Rover y Despegue del Apolo 8: las estrellas obtenidas (1 bronce, 2 plata, 3 oro).
##   - Biblioteca: libros leídos hasta el final (1 bronce, 4 plata, 8 oro).
## El certificado se gana con medalla en Base Lunar, Taller del Rover y Despegue.
## Todo se guarda en `user://progreso.cfg`.

const PATH: String = "user://progreso.cfg"
const BASE: StringName = &"base"
const ROVER: StringName = &"rover"
const LAUNCH: StringName = &"despegue"
const LIBRARY: StringName = &"biblioteca"
const MODULES: Array[StringName] = [BASE, ROVER, LAUNCH, LIBRARY]
## Módulos necesarios para el certificado.
const CERTIFICATE_MODULES: Array[StringName] = [BASE, ROVER, LAUNCH]
const MODULE_NAMES: Dictionary = {
	BASE: "Base Lunar",
	ROVER: "Taller del Rover",
	LAUNCH: "Despegue del Apolo 8",
	LIBRARY: "Biblioteca",
}
const NONE: int = 0
const BRONZE: int = 1
const SILVER: int = 2
const GOLD: int = 3
const MEDAL_NAMES: Array[String] = ["Sin medalla", "Bronce", "Plata", "Oro"]
const MEDAL_TITLES: Array[String] = ["", "¡Medalla de bronce!", "¡Medalla de plata!", "¡Medalla de oro!"]
const BOOKS_FOR_MEDAL: Array[int] = [0, 1, 4, 8]
const BASE_SILVER_PERCENT: float = 35.0
const BASE_GOLD_PERCENT: float = 60.0
## Misión sin límite de tiempo (`MissionConfig.endless_mission`): la medalla de la
## base se da al terminar según los segundos que se aguantó.
const BASE_SURVIVAL_SECONDS: Array[float] = [0.0, 180.0, 360.0, 600.0]

static var _path: String = PATH

## Permite a las pruebas usar otro archivo (y no tocar el progreso real).
static func use_file(path: String) -> void:
	_path = path

static func reset() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))

static func get_medal(module: StringName) -> int:
	return int(_load().get_value("medallas", String(module), NONE))

## Guarda la medalla si es mejor que la que había. Devuelve true si mejoró.
static func award(module: StringName, medal: int) -> bool:
	var value: int = clampi(medal, NONE, GOLD)
	var config: ConfigFile = _load()
	if value <= int(config.get_value("medallas", String(module), NONE)):
		return false
	var had_certificate: bool = has_certificate()
	config.set_value("medallas", String(module), value)
	config.save(_path)
	if not had_certificate and has_certificate():
		var today: Dictionary = Time.get_date_dict_from_system()
		config.set_value("certificado", "fecha", "%04d-%02d-%02d" % [int(today["year"]), int(today["month"]), int(today["day"])])
		config.save(_path)
	return true

## Guarda la medalla y, si mejoró, muestra el aviso con sonido (y el del certificado si se acaba de ganar).
static func award_and_notify(module: StringName, medal: int) -> bool:
	var had_certificate: bool = has_certificate()
	if not award(module, medal):
		return false
	var pause: PauseMenu = PauseMenu.get_instance()
	if pause != null:
		pause.show_medal(module, get_medal(module), not had_certificate and has_certificate())
	return true

static func medal_for_base(average_percent: float) -> int:
	if average_percent >= BASE_GOLD_PERCENT:
		return GOLD
	if average_percent >= BASE_SILVER_PERCENT:
		return SILVER
	return BRONZE

## Medalla de la base en misión sin fin: 3 min bronce, 6 min plata, 10 min oro.
static func medal_for_survival(seconds: float) -> int:
	for medal: int in [GOLD, SILVER, BRONZE]:
		if seconds >= BASE_SURVIVAL_SECONDS[medal]:
			return medal
	return NONE

static func medal_for_stars(stars: int) -> int:
	return clampi(stars, BRONZE, GOLD)

## Marca un libro como leído y actualiza la medalla de la biblioteca. Devuelve true si la medalla mejoró.
static func mark_book_read(book_id: String) -> bool:
	var config: ConfigFile = _load()
	var books: PackedStringArray = config.get_value("biblioteca", "leidos", PackedStringArray()) as PackedStringArray
	if not books.has(book_id):
		books.append(book_id)
		config.set_value("biblioteca", "leidos", books)
		config.save(_path)
	var medal: int = NONE
	for level: int in range(GOLD, NONE, -1):
		if books.size() >= BOOKS_FOR_MEDAL[level]:
			medal = level
			break
	return award_and_notify(LIBRARY, medal)

static func get_books_read() -> int:
	return (_load().get_value("biblioteca", "leidos", PackedStringArray()) as PackedStringArray).size()

static func has_certificate() -> bool:
	for module: StringName in CERTIFICATE_MODULES:
		if get_medal(module) == NONE:
			return false
	return true

static func get_certificate_date() -> String:
	return str(_load().get_value("certificado", "fecha", ""))

## Módulos del certificado que aún faltan (para decirle al jugador qué le queda).
static func missing_for_certificate() -> Array[StringName]:
	var missing: Array[StringName] = []
	for module: StringName in CERTIFICATE_MODULES:
		if get_medal(module) == NONE:
			missing.append(module)
	return missing

## Color de cada medalla (para dibujarla).
static func medal_color(medal: int) -> Color:
	match medal:
		BRONZE:
			return Color(0.8, 0.5, 0.25)
		SILVER:
			return Color(0.8, 0.84, 0.9)
		GOLD:
			return Color(1.0, 0.8, 0.25)
	return Color(0.3, 0.33, 0.38)

static func _load() -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	config.load(_path)
	return config
