extends Node
# Prueba del idioma: español por defecto, inglés con traducción completa e imágenes _en.

var _fails: int = 0

func _ready() -> void:
	var before: String = Localization.get_language()
	Localization.set_language(Localization.ENGLISH)
	_check(Localization.is_english(), "el idioma cambia a inglés")
	_check(tr("Biblioteca") == "Library", "tr traduce 'Biblioteca'")
	_check(tr("ESCUDO ANTIRRADIACIÓN") != "ESCUDO ANTIRRADIACIÓN", "nombre del escudo traducido")
	_check(Localization.localized_path("res://ai_assets/ui/biblioteca/portadas/sistema_solar.png").ends_with("_en.png"), "portada en inglés")
	var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check((menu.get_node("%LanguageButton") as Button).text == "Español", "el botón ofrece volver al español")
	menu.queue_free()
	Localization.set_language(Localization.SPANISH)
	_check(tr("Biblioteca") == "Biblioteca", "vuelve al español")
	Localization.set_language(before)
	print("=== RESULTADO IDIOMA: %s ===" % ("TODO OK" if _fails == 0 else "%d FALLOS" % _fails))
	get_tree().quit()

func _check(ok: bool, what: String) -> void:
	print(("[OK] " if ok else "[FALLO] ") + what)
	if not ok: _fails += 1
