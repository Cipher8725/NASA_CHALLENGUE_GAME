extends Node

## Herramienta de desarrollo: captura pantallas de las funciones nuevas del
## Hito 20 (Recursos de la NASA y la CSA) en `docs/capturas/`.
##
## Se ejecuta con una ventana real (no headless), porque necesita que el
## renderizador produzca una imagen del viewport:
##
##   godot --path . --rendering-driver opengl3 res://tools/capturas/capturar_nasa.tscn
##
## Cada captura espera unos fotogramas para que la escena se asiente y luego
## guarda el PNG.

## Carpeta donde se guardan las capturas.
const OUT_DIR: String = "res://docs/capturas/"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _captura_hud()
	await _captura_tormenta_solar()
	await _captura_hidroponia()
	await _captura_biblioteca()
	await _captura_lector_clima()
	await _captura_taller_foto()
	print("=== CAPTURAS TERMINADAS ===")
	get_tree().quit(0)

# --- Capturas ---

## HUD de la misión con las cinco barras de recursos (incluida la comida).
func _captura_hud() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	# La misión arranca 0,5 s después: se espera a que esté en curso.
	await _esperar(1.2)
	var game: GameManager = GameManager.get_instance()
	# Se gastan algo de agua, comida y energía para que las barras se vean
	# distintas entre sí (las cifras siguen siendo las del juego).
	game.consume_resource(GameManager.RESOURCE_WATER, 34.0)
	game.consume_resource(GameManager.RESOURCE_FOOD, 46.0)
	game.consume_resource(GameManager.RESOURCE_ENERGY, 18.0)
	await _esperar(0.3)
	await _guardar("nasa_hud_recursos")
	main.queue_free()
	await _esperar(0.2)

## Aviso de tormenta solar real de DONKI en el HUD.
func _captura_tormenta_solar() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _esperar(1.2)
	var game: GameManager = GameManager.get_instance()
	# Se busca el evento real de clase X más severo del catálogo DONKI.
	var radiacion: RadiationData = RadiationData.get_instance()
	var evento: RadiationData.SpaceWeatherEvent = radiacion.get_evento_mas_severo()
	var hud: MissionHud = main.get_node("UILayer/HUD") as MissionHud
	if evento != null:
		game.trigger_solar_storm(evento)
		hud.show_solar_storm(evento)
	await _esperar(0.3)
	await _guardar("nasa_tormenta_solar")
	main.queue_free()
	await _esperar(0.2)

## Minijuego de hidroponía (luz y agua del cultivo de la CSA).
func _captura_hidroponia() -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	var minigame: HydroponicsMinigame = (load("res://scenes/ui/minigame_hydroponics.tscn") as PackedScene).instantiate() as HydroponicsMinigame
	capa.add_child(minigame)
	minigame.result_display_time = 999.0
	minigame.begin()
	# Se deja una planta a medio crecer para que se vea el cultivo.
	minigame.set_crecimiento(0.62)
	await _esperar(0.4)
	await _guardar("nasa_hidroponia_minijuego")
	capa.queue_free()
	await _esperar(0.2)

## Estantería de la biblioteca con los once libros (cuatro por columna).
func _captura_biblioteca() -> void:
	var lib: Library = (load("res://scenes/biblioteca.tscn") as PackedScene).instantiate() as Library
	add_child(lib)
	await _esperar(0.5)
	await _guardar("nasa_biblioteca_estante")
	lib.queue_free()
	await _esperar(0.2)

## Lector con el libro "El clima del espacio" y su página de fuentes.
func _captura_lector_clima() -> void:
	var lib: Library = (load("res://scenes/biblioteca.tscn") as PackedScene).instantiate() as Library
	add_child(lib)
	await _esperar(0.4)
	lib.open_book("clima_espacio")
	lib.next_spread()
	lib.next_spread()
	await _esperar(0.4)
	await _guardar("nasa_biblioteca_clima_espacio")
	lib.queue_free()
	await _esperar(0.2)

## Taller del rover con una foto real del Perseverance (NASA).
func _captura_taller_foto() -> void:
	var taller: RoverWorkshop = (load("res://scenes/rover_workshop.tscn") as PackedScene).instantiate() as RoverWorkshop
	add_child(taller)
	await _esperar(0.6)
	taller.show_rover_photo()
	await _esperar(0.4)
	await _guardar("nasa_rover_foto_perseverance")
	taller.queue_free()
	await _esperar(0.2)

# --- Utilidades ---

## Espera un numero de segundos (tiempo real) dejando correr los fotogramas.
func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
	for _i: int in range(3):
		await get_tree().process_frame

## Guarda el fotograma actual del viewport como PNG.
func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	var ruta: String = OUT_DIR + nombre + ".png"
	var error: int = imagen.save_png(ruta)
	if error == OK:
		print("  captura guardada: ", nombre)
	else:
		push_error("No se pudo guardar la captura %s (error %d)" % [nombre, error])
