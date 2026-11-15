extends Node
# Prueba de los tutoriales paso a paso de cada parte del juego: se muestran, avanzan,
# retroceden, se saltan, quedan marcados como vistos y cada paso ilumina lo que explica.

const SCENES: Array[String] = [
	"res://scenes/main_menu.tscn",
	"res://scenes/rover_workshop.tscn",
	"res://scenes/simulacion_despegue_3d.tscn",
	"res://scenes/simulacion_despegue.tscn",
	"res://scenes/biblioteca.tscn",
	"res://scenes/card_editor.tscn",
]
const MINIGAMES: Array[String] = [
	"res://scenes/ui/minigame_oxygen.tscn",
	"res://scenes/ui/minigame_cables.tscn",
	"res://scenes/ui/minigame_hydroponics.tscn",
]

var _fails: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GuideOverlay.reset_all()
	# En las escenas de prueba los tutoriales no aparecen solos.
	var menu: Node = (load(SCENES[0]) as PackedScene).instantiate()
	add_child(menu)
	await _frames(3)
	_check(not GuideOverlay.is_active(get_tree()), "en las pruebas el tutorial no aparece solo")
	menu.queue_free()
	await _frames(2)

	for path: String in SCENES:
		var scene: Node = (load(path) as PackedScene).instantiate()
		add_child(scene)
		await _frames(3)
		var guide: GuideOverlay = scene.call("show_guide", true) as GuideOverlay
		_check(guide != null and guide.get_step_count() >= 2, "%s: tutorial con %d pasos" % [path.get_file(), guide.get_step_count() if guide else 0])
		if guide != null:
			await _walk(guide, path.get_file())
		scene.queue_free()
		await _frames(2)

	# Minijuegos: cada paso señala una parte visible del minijuego.
	for path: String in MINIGAMES:
		var minigame: RepairMinigame = (load(path) as PackedScene).instantiate() as RepairMinigame
		add_child(minigame)
		await _frames(2)
		minigame.begin()
		var guide: GuideOverlay = GuideOverlay.start(self, minigame.guide_id(), minigame.guide_steps(), true, true)
		_check(guide != null and guide.get_step_count() == 4, "%s: tutorial de 4 pasos" % path.get_file())
		_check(get_tree().paused, "%s: el minijuego espera en pausa mientras se lee" % path.get_file())
		if guide != null:
			await _walk(guide, path.get_file())
		_check(not get_tree().paused, "%s: al terminar el tutorial el juego sigue" % path.get_file())
		minigame.queue_free()
		await _frames(2)

	# Atrás, saltar y marcar como visto.
	var steps: Array[Dictionary] = [GuideOverlay.step("A", "a"), GuideOverlay.step("B", "b"), GuideOverlay.step("C", "c")]
	var g: GuideOverlay = GuideOverlay.start(self, "prueba_guia", steps, false, true)
	await _frames(1)
	g.next()
	g.next()
	g.previous()
	_check(g.get_step_index() == 1, "Siguiente y Atrás cambian de paso")
	var skipped: Array[bool] = [false]
	g.finished.connect(func(was_skipped: bool) -> void: skipped[0] = was_skipped)
	(g.get_node("%GuideSkip") as Button).pressed.emit()
	await _frames(1)
	_check(skipped[0] and GuideOverlay.was_seen("prueba_guia"), "Saltar tutorial lo cierra y lo marca como visto")
	_check(GuideOverlay.start(self, "prueba_guia", steps) == null, "un tutorial visto no vuelve a salir solo")
	GuideOverlay.reset_all()
	print("=== RESULTADO TUTORIALES: %s ===" % ("TODO OK" if _fails == 0 else "%d FALLOS" % _fails))
	get_tree().quit()

## Recorre todos los pasos y comprueba que los que señalan algo lo iluminan.
func _walk(guide: GuideOverlay, label: String) -> void:
	var lit: int = 0
	var count: int = guide.get_step_count()
	for i: int in count:
		await _frames(2)
		if guide.get_highlight().has_area():
			lit += 1
		if i < count - 1:
			guide.next()
	_check(lit >= 1, "%s: %d pasos iluminan una parte de la pantalla" % [label, lit])
	guide.next()
	await _frames(2)
	_check(not GuideOverlay.is_active(get_tree()), "%s: el último paso cierra el tutorial" % label)

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _check(ok: bool, what: String) -> void:
	print(("[OK] " if ok else "[FALLO] ") + what)
	if not ok:
		_fails += 1
