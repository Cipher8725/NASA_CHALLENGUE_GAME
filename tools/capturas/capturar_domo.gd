extends Node

## Herramienta de desarrollo: captura el domo de la estación (Hito 24) desde
## fuera y desde dentro en `docs/capturas/`. Necesita ventana real:
##
##   godot --path . --rendering-driver opengl3 res://tools/capturas/capturar_domo.tscn

const OUT_DIR: String = "res://docs/capturas/"

## Puntos de vista: nombre del archivo, posición de la cámara y punto al que mira.
const VIEWS: Array[Dictionary] = [
	{"file": "hito24_domo_exterior.png", "from": Vector3(150, 80, -150), "to": Vector3(0, 5, 37)},
	{"file": "hito24_domo_lateral.png", "from": Vector3(-170, 18, 37), "to": Vector3(0, 12, 37)},
	{"file": "hito24_domo_interior.png", "from": Vector3(0, 1.7, -30), "to": Vector3(0, 25, 10)},
]

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var habitat: Node3D = (load("res://scenes/habitat.tscn") as PackedScene).instantiate() as Node3D
	add_child(habitat)
	var camera: Camera3D = Camera3D.new()
	camera.far = 2000.0
	add_child(camera)
	camera.make_current()
	for view: Dictionary in VIEWS:
		camera.look_at_from_position(view["from"], view["to"])
		for _i: int in range(20):
			await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(OUT_DIR + String(view["file"])))
		print("Captura: ", view["file"])
	get_tree().quit(0)
