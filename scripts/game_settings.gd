class_name GameSettings
extends RefCounted

## Ajustes del jugador guardados en `user://ajustes.cfg` (idioma, volumen, tutorial visto…).
## Cada escritura vuelve a leer el archivo para no borrar lo que guardó otra parte del juego.

const PATH: String = "user://ajustes.cfg"

static func get_value(section: String, key: String, default: Variant) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) != OK:
		return default
	return config.get_value(section, key, default)

static func get_float(section: String, key: String, default: float) -> float:
	return float(get_value(section, key, default))

static func get_bool(section: String, key: String, default: bool) -> bool:
	return bool(get_value(section, key, default))

static func set_value(section: String, key: String, value: Variant) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(PATH)
	config.set_value(section, key, value)
	config.save(PATH)
