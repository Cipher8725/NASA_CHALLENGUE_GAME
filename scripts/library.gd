class_name Library
extends Control

## Biblioteca de estudio: estantería con 9 libros (3 por nivel) y lector.
##
## Los textos vienen de `catalogo.json` (cada libro: 3 páginas con título y
## texto, fuentes de la NASA y, a veces, una actividad del juego para practicar).
## Al abrir un libro se muestra como libro abierto, dos páginas a la vez:
##   1. Portada y nivel        | Página 1
##   2. Página 2               | Página 3
##   3. Fuentes (enlaces)      | ¡Libro terminado! (+ botón para practicar)

signal book_opened(book_id: String)
signal book_closed

const CATALOG_PATH: String = "res://resources/biblioteca/catalogo.json"
const MENU_SCENE: String = "res://scenes/main_menu.tscn"
## Columnas y filas de la estantería (esquina superior izquierda de cada libro).
## Cuatro columnas: la cuarta (x 942) entra en el mismo estante sin tapar otros libros.
const SHELF_COLUMNS: Array[int] = [454, 616, 779, 942]
const SHELF_ROWS: Dictionary = {"Básico": 165, "Intermedio": 316, "Avanzado": 470}
## Cuánto crece un libro al pasar el ratón.
const HOVER_SCALE: float = 1.08

var _books: Array[Dictionary] = []
var _book: Dictionary = {}
var _spreads: Array[Dictionary] = []
var _spread: int = 0

@onready var _shelf: Control = %Shelf
@onready var _template: TextureButton = %BookTemplate
@onready var _book_info: Label = %BookInfoText
@onready var _reader: Control = %Reader
@onready var _left_title: Label = %LeftTitle
@onready var _left_image: TextureRect = %LeftImage
@onready var _left_text: RichTextLabel = %LeftText
@onready var _right_title: Label = %RightTitle
@onready var _right_image: TextureRect = %RightImage
@onready var _right_text: RichTextLabel = %RightText
@onready var _activity_button: Button = %ActivityButton
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _page_label: Label = %PageLabel

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_books = load_catalog(CATALOG_PATH)
	_build_shelf()
	_reader.visible = false

## Lee el catálogo JSON. Devuelve una lista vacía si no existe o está mal escrito.
static func load_catalog(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_warning("Library: no existe %s" % path)
		return result
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Array:
		for item: Variant in data:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result

# --- API pública (la usan las pruebas) ---

func get_books() -> Array[Dictionary]:
	return _books

func get_book_button(book_id: String) -> TextureButton:
	return _shelf.get_node_or_null("Book_" + book_id) as TextureButton

func is_reading() -> bool:
	return _reader.visible

func get_current_book_id() -> String:
	return str(_book.get("id", ""))

func get_spread_index() -> int:
	return _spread

func get_spread_count() -> int:
	return _spreads.size()

func open_book(book_id: String) -> bool:
	for book: Dictionary in _books:
		if str(book.get("id", "")) == book_id:
			_book = book
			_spreads = _build_spreads(book)
			_spread = 0
			_reader.visible = true
			_show_spread()
			book_opened.emit(book_id)
			return true
	return false

func close_book() -> void:
	_reader.visible = false
	_book = {}
	book_closed.emit()

func next_spread() -> void:
	if _spread < _spreads.size() - 1:
		_spread += 1
		_show_spread()

func prev_spread() -> void:
	if _spread > 0:
		_spread -= 1
		_show_spread()

# --- Estantería ---

func _build_shelf() -> void:
	var per_level: Dictionary = {}
	for book: Dictionary in _books:
		var level: String = str(book.get("nivel", ""))
		if not SHELF_ROWS.has(level):
			continue
		var column: int = int(per_level.get(level, 0))
		per_level[level] = column + 1
		if column >= SHELF_COLUMNS.size():
			continue
		var button: TextureButton = _template.duplicate() as TextureButton
		button.name = "Book_" + str(book["id"])
		button.visible = true
		button.texture_normal = load(str(book["portada"])) as Texture2D
		button.position = Vector2(SHELF_COLUMNS[column], int(SHELF_ROWS[level]))
		button.tooltip_text = str(book["titulo"])
		button.pressed.connect(open_book.bind(str(book["id"])))
		button.mouse_entered.connect(_on_book_hover.bind(button, book, true))
		button.mouse_exited.connect(_on_book_hover.bind(button, book, false))
		_shelf.add_child(button)
	_template.visible = false

func _on_book_hover(button: TextureButton, book: Dictionary, entered: bool) -> void:
	create_tween().tween_property(button, "scale", Vector2.ONE * (HOVER_SCALE if entered else 1.0), 0.12)
	if entered:
		_book_info.text = "%s  ·  Nivel %s  ·  %d páginas" % [book["titulo"], book["nivel"], (book["paginas"] as Array).size()]
	else:
		_book_info.text = "Elige un libro para leerlo"

# --- Lector ---

func _build_spreads(book: Dictionary) -> Array[Dictionary]:
	var pages: Array = book.get("paginas", []) as Array
	var spreads: Array[Dictionary] = []
	var cover: Dictionary = {
		"titulo": str(book["titulo"]),
		"texto": "[b]Nivel %s[/b]\n\n%d páginas para leer. Usa [b]Siguiente[/b] para avanzar." % [book["nivel"], pages.size()],
		"imagen": str(book["portada"]),
	}
	var flat: Array[Dictionary] = [cover]
	for page: Variant in pages:
		flat.append(page as Dictionary)
	var links: PackedStringArray = []
	for url: Variant in book.get("fuentes", []) as Array:
		links.append("• [url=%s]%s[/url]" % [url, url])
	flat.append({"titulo": "Fuentes", "texto": "Este libro se escribió con información de la NASA:\n\n" + "\n".join(links)})
	flat.append({"titulo": "¡Libro terminado!", "texto": "Leíste «%s». Vuelve a la estantería para elegir otro libro." % book["titulo"], "final": true})
	for i: int in range(0, flat.size(), 2):
		spreads.append({"izquierda": flat[i], "derecha": flat[i + 1] if i + 1 < flat.size() else {}})
	return spreads

func _show_spread() -> void:
	var spread: Dictionary = _spreads[_spread]
	_fill_page(spread["izquierda"] as Dictionary, _left_title, _left_image, _left_text)
	var right: Dictionary = spread["derecha"] as Dictionary
	_fill_page(right, _right_title, _right_image, _right_text)
	var activity: Dictionary = _book.get("actividad", {}) as Dictionary
	_activity_button.visible = bool(right.get("final", false)) and not activity.is_empty()
	if _activity_button.visible:
		_activity_button.text = str(activity.get("texto", "Practicar"))
	_prev_button.disabled = _spread == 0
	_next_button.disabled = _spread >= _spreads.size() - 1
	_page_label.text = "%d / %d" % [_spread + 1, _spreads.size()]

func _fill_page(page: Dictionary, title: Label, image: TextureRect, text: RichTextLabel) -> void:
	title.text = str(page.get("titulo", ""))
	var image_path: String = str(page.get("imagen", ""))
	image.texture = load(image_path) as Texture2D if not image_path.is_empty() else null
	image.visible = image.texture != null
	text.text = str(page.get("texto", ""))

# --- Botones ---

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _on_close_pressed() -> void:
	close_book()

func _on_prev_pressed() -> void:
	prev_spread()

func _on_next_pressed() -> void:
	next_spread()

func _on_activity_pressed() -> void:
	var scene: String = str((_book.get("actividad", {}) as Dictionary).get("escena", ""))
	if ResourceLoader.exists(scene):
		get_tree().change_scene_to_file(scene)

func _on_link_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))

func _unhandled_input(event: InputEvent) -> void:
	if not _reader.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_book()
	elif event.is_action_pressed("ui_right"):
		next_spread()
	elif event.is_action_pressed("ui_left"):
		prev_spread()
	else:
		return
	get_viewport().set_input_as_handled()
