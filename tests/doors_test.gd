extends Node

## Test de puertas y carnet.
##
## Comprueba que:
##  * el carnet se crea, se guarda y se vuelve a cargar con sus datos,
##  * los 6 avatares cargan y la vista del carnet muestra los datos,
##  * la puerta automática se abre al acercarse el jugador y se cierra al irse,
##    y no reacciona a cuerpos que no son el jugador,
##  * la puerta restringida no se abre sola, rechaza sin carnet y con nivel 1,
##    y se abre con nivel 2,
##  * la colisión de la hoja se desactiva al abrir,
##  * la sala de prueba y la pantalla "MI CARNET" cargan.

const TEST_PHOTO_PATH: String = "user://carnet_foto_prueba.png"
const TEST_CARD_PATH: String = "user://carnet_prueba.tres"

func _ready() -> void:
	await get_tree().process_frame
	await _run()

func _run() -> void:
	var failures: int = 0
	if FileAccess.file_exists(TEST_CARD_PATH):
		DirAccess.remove_absolute(TEST_CARD_PATH)

	# --- Carnet ---
	var card: AstronautCard = AstronautCard.create("  Ana Quispe ", 3)
	failures += _check("El carnet nuevo limpia el nombre", card.nombre == "Ana Quispe")
	failures += _check("El carnet nuevo es nivel 1 (cadete)", card.nivel_acceso == 1 and card.get_rank() == "Cadete astronauta")
	failures += _check("El carnet tiene número SEL-AAAA-NNNN", card.numero.begins_with("SEL-") and card.numero.length() == 13)
	failures += _check("El carnet tiene fecha de emisión y vencimiento", card.fecha_emision.length() == 10 and card.fecha_vencimiento.length() == 10)
	failures += _check("El carnet se guarda", card.save_card(TEST_CARD_PATH))
	var loaded: AstronautCard = AstronautCard.load_saved(TEST_CARD_PATH)
	failures += _check("El carnet se vuelve a cargar igual", loaded != null and loaded.nombre == "Ana Quispe" and loaded.avatar == 3 and loaded.numero == card.numero)
	var avatars_ok: bool = true
	for i: int in range(1, AstronautCard.AVATAR_COUNT + 1):
		if load(AstronautCard.AVATAR_PATH % i) == null:
			avatars_ok = false
	failures += _check("Los 6 avatares cargan", avatars_ok)

	# --- Foto del carnet ---
	var big: Image = Image.create(800, 600, false, Image.FORMAT_RGBA8)
	big.fill(Color(0.2, 0.5, 0.8))
	var cropped: Image = PhotoTools.crop_to_card(big)
	failures += _check("La foto se recorta al tamaño del carnet sin deformarse", cropped.get_size() == PhotoTools.CARD_PHOTO_SIZE)
	var helmet: Image = PhotoTools.add_helmet(cropped)
	failures += _check("El casco cubre los bordes y deja ver la cara", helmet.get_pixel(5, 5).r > 0.6 and helmet.get_pixel(170, 170).b > 0.6 and helmet.get_pixel(170, 170).r < 0.4)
	failures += _check("La foto se guarda en el carnet", loaded.set_photo(helmet, TEST_PHOTO_PATH) and loaded.has_photo())
	failures += _check("El carnet muestra la foto en vez del dibujo", loaded.get_avatar_texture() is ImageTexture and loaded.get_avatar_texture().get_size() == Vector2(PhotoTools.CARD_PHOTO_SIZE))
	loaded.remove_photo()
	failures += _check("Al quitar la foto vuelve el dibujo y se borra el archivo", not loaded.has_photo() and not FileAccess.file_exists(TEST_PHOTO_PATH) and not (loaded.get_avatar_texture() is ImageTexture))
	var booth: PhotoBooth = (load("res://scenes/ui/photo_booth.tscn") as PackedScene).instantiate() as PhotoBooth
	booth.camera_wait_seconds = 0.25
	add_child(booth)
	var has_cam: bool = await booth.start_camera()
	failures += _check("Sin cámara, la cabina ofrece SUBIR UNA FOTO", has_cam or (not (booth.get_node("%UploadButton") as Button).disabled and (booth.get_node("%ShootButton") as Button).disabled))
	booth.use_image(big)
	failures += _check("Una foto subida queda lista para usar", booth.get_captured() != null and booth.get_captured().get_size() == PhotoTools.CARD_PHOTO_SIZE and (booth.get_node("%UseButton") as Button).visible)
	booth.stop_camera()
	booth.queue_free()

	var view: AstronautCardView = (load("res://scenes/ui/astronaut_card_view.tscn") as PackedScene).instantiate() as AstronautCardView
	add_child(view)
	view.show_card(loaded)
	failures += _check("La vista del carnet muestra nombre y nivel", (view.get_node("%NameValue") as Label).text == "ANA QUISPE" and (view.get_node("%LevelValue") as Label).text == "NIVEL 1")
	view.queue_free()

	# --- Puerta automática ---
	var player: CharacterBody3D = CharacterBody3D.new()
	player.add_to_group("player")
	add_child(player)
	var other: CharacterBody3D = CharacterBody3D.new()
	add_child(other)

	var auto_door: SlidingDoor = (load("res://scenes/doors/auto_door.tscn") as PackedScene).instantiate() as SlidingDoor
	auto_door.move_time = 0.0
	auto_door.close_delay = 0.0
	add_child(auto_door)
	await get_tree().process_frame
	failures += _check("La puerta automática empieza cerrada", not auto_door.is_open() and not auto_door.is_restricted())
	auto_door._on_detect_body_entered(other)
	failures += _check("No se abre con algo que no es el jugador", not auto_door.is_open())
	auto_door._on_detect_body_entered(player)
	await get_tree().process_frame
	var leaf_collision: CollisionShape3D = auto_door.get_node("%LeafCollision") as CollisionShape3D
	failures += _check("Se abre cuando el jugador se acerca", auto_door.is_open())
	failures += _check("Al abrirse se puede atravesar (sin colisión en la hoja)", leaf_collision.disabled)
	auto_door._on_detect_body_exited(player)
	await get_tree().process_frame
	failures += _check("Se cierra cuando el jugador se aleja", not auto_door.is_open() and not leaf_collision.disabled)

	# --- Puerta restringida ---
	var lab_door: SlidingDoor = (load("res://scenes/doors/restricted_door.tscn") as PackedScene).instantiate() as SlidingDoor
	lab_door.move_time = 0.0
	lab_door.close_delay = 0.0
	lab_door.card_path = TEST_CARD_PATH
	add_child(lab_door)
	await get_tree().process_frame
	failures += _check("La puerta restringida pide nivel 2", lab_door.is_restricted() and lab_door.required_access_level == 2)
	lab_door._on_detect_body_entered(player)
	failures += _check("La puerta restringida NO se abre sola", not lab_door.is_open())
	failures += _check("Sin carnet no se abre", not lab_door.try_card(null) and not lab_door.is_open())
	failures += _check("Con carnet nivel 1 no se abre", not lab_door.try_card(loaded) and not lab_door.is_open())
	loaded.nivel_acceso = 2
	loaded.save_card(TEST_CARD_PATH)
	failures += _check("Con carnet nivel 2 se abre", lab_door.try_card(AstronautCard.load_saved(TEST_CARD_PATH)) and lab_door.is_open())
	lab_door._on_detect_body_exited(player)
	await get_tree().process_frame
	failures += _check("Se cierra cuando el jugador se aleja", not lab_door.is_open())

	# --- Tamaño ajustable ---
	var small_door: SlidingDoor = (load("res://scenes/doors/auto_door.tscn") as PackedScene).instantiate() as SlidingDoor
	small_door.move_time = 0.0
	small_door.close_delay = 0.0
	add_child(small_door)
	await get_tree().process_frame
	var other_door: SlidingDoor = (load("res://scenes/doors/auto_door.tscn") as PackedScene).instantiate() as SlidingDoor
	add_child(other_door)
	small_door.set_door_size(1.1, 1.9, 0.2)
	var model: Node3D = small_door.get_node("%Model") as Node3D
	failures += _check("Al cambiar el tamaño, el modelo se escala", model.scale.is_equal_approx(Vector3(1.1 / 1.7, 1.9 / 2.2, 0.2 / 0.3)))
	var top_box: BoxShape3D = (small_door.get_node("FrameBody/Top") as CollisionShape3D).shape as BoxShape3D
	failures += _check("La colisión del marco toma el nuevo ancho", is_equal_approx(top_box.size.x, 1.1) and is_equal_approx(top_box.size.z, 0.2))
	var other_top: BoxShape3D = (other_door.get_node("FrameBody/Top") as CollisionShape3D).shape as BoxShape3D
	failures += _check("Cambiar una puerta no cambia las demás", is_equal_approx(other_top.size.x, 1.7))
	failures += _check("La puerta ARRIBA pide espacio libre igual a la hoja", absf(small_door.get_required_clearance() - 1.94 * 1.9 / 2.2) < 0.01)
	small_door.slide_direction = SlidingDoor.Slide.LEFT
	var leaf_node: Node3D = model.find_child("HojaPuerta", true, false) as Node3D
	var closed_pos: Vector3 = leaf_node.position
	small_door.open_door()
	failures += _check("Con techo bajo la hoja se desliza de lado", leaf_node.position.x < closed_pos.x - 1.0 and is_equal_approx(leaf_node.position.y, closed_pos.y))
	small_door.close_door()
	failures += _check("Al cerrar, la hoja vuelve a su sitio", leaf_node.position.is_equal_approx(closed_pos))
	small_door.queue_free()
	other_door.queue_free()

	# --- Escenas ---
	var demo: Node = (load("res://scenes/doors_demo.tscn") as PackedScene).instantiate()
	add_child(demo)
	await get_tree().process_frame
	failures += _check("La sala de prueba de puertas carga", demo.get_node_or_null("%RestrictedDoor") != null)
	demo.queue_free()
	var editor: Node = (load("res://scenes/card_editor.tscn") as PackedScene).instantiate()
	failures += _check("La pantalla MI CARNET carga", editor is CardEditor)
	editor.free()

	DirAccess.remove_absolute(TEST_CARD_PATH)
	_finish(failures)

func _finish(failures: int) -> void:
	print("=== RESULTADO PUERTAS Y CARNET: %s ===" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(0 if failures == 0 else 1)

func _check(label: String, condition: bool) -> int:
	if condition:
		print("  [OK]   ", label)
		return 0
	print("  [FALLO] ", label)
	return 1
