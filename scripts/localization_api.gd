class_name Localization
extends RefCounted

## API estática de idioma que usan los tutoriales, la pausa, la biblioteca y el
## taller (parche de tutoriales). No guarda nada por su cuenta: delega en el
## autoload `Lang` (`scripts/localization.gd`), que es el sistema de idioma del
## juego (diccionario `Lang.EN` + `locale/en.po` registrado en project.godot).

const SPANISH: String = "es"
const ENGLISH: String = "en"

## El autoload `Lang`, o null si todavía no existe (p. ej. en el editor).
static func _lang() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Lang") if tree != null else null

## El idioma guardado ya lo aplica `Lang` al arrancar; se deja por compatibilidad.
static func apply_saved_language() -> void:
	pass

## Cambia el idioma (lo guarda `Lang`).
static func set_language(language: String) -> void:
	var lang: Node = _lang()
	if lang != null:
		lang.call("set_language", language)
	else:
		TranslationServer.set_locale(language)

## Idioma actual: "es" o "en".
static func get_language() -> String:
	return ENGLISH if TranslationServer.get_locale().begins_with(ENGLISH) else SPANISH

static func is_english() -> bool:
	return get_language() == ENGLISH

## Versión en inglés de una imagen si existe y el juego está en inglés. Acepta
## las dos convenciones del proyecto: `nombre_en.png` junto a la original o
## `en/nombre.png` en una subcarpeta.
static func localized_path(path: String) -> String:
	if not is_english() or path.is_empty():
		return path
	var suffixed: String = "%s_en.%s" % [path.get_basename(), path.get_extension()]
	if ResourceLoader.exists(suffixed):
		return suffixed
	var folder: String = path.get_base_dir().path_join("en").path_join(path.get_file())
	return folder if ResourceLoader.exists(folder) else path
