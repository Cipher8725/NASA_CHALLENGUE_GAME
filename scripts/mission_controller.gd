class_name MissionController
extends Node3D

## Controlador raíz de la misión.
##
## Orquesta el arranque de la partida, la cuenta atrás y el reinicio.
## No implementa reglas de juego: delega todo en el `GameManager` (Autoload "Game").

const GUIDE_ID: String = "base_lunar"
const MAIN_SCENE: String = "res://scenes/main.tscn"

@onready var _game: GameManager = GameManager.get_instance()

func _ready() -> void:
	AudioManager.music(&"base")
	# El HUD se registra como observador del gestor global.
	_game.mission_failed.connect(_on_mission_failed)
	_game.mission_completed.connect(_on_mission_completed)

	# La primera vez se explica la base paso a paso (el juego espera en pausa).
	# Solo en la partida real (no en las escenas de prueba que reutilizan este controlador).
	if _is_real_game() and not GuideOverlay.was_seen(GUIDE_ID):
		await get_tree().process_frame
		var guide: GuideOverlay = show_guide(false)
		if guide != null:
			await guide.finished
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Consejos que salen una sola vez, cuando pasa algo por primera vez.
	_game.emergency_triggered.connect(_on_first_emergency)
	_game.resource_critical.connect(_on_first_critical)

	# Pequeña demora para que la cámara se estabilice antes de la cuenta atrás.
	await get_tree().create_timer(0.5, false).timeout
	_game.start_mission()

## Tutorial de la Base Lunar: recursos, tiempo, controles, consolas, emergencias y pausa.
## Con `force` se muestra aunque ya se haya visto (lo usa "Cómo jugar" en la pausa).
func show_guide(force: bool = true) -> GuideOverlay:
	var hud: Control = get_node_or_null("UILayer/HUD") as Control
	var minutes: int = maxi(1, int(ceil(_game.config.mission_duration / 60.0))) if _game.config != null else 3
	var endless: bool = _game.config != null and _game.config.endless_mission
	var goal: String = tr("Tu misión: mantener a la tripulación con vida [b]el mayor tiempo posible[/b]. Aguanta 3, 6 o 10 minutos para ganar medalla de bronce, plata u oro.") if endless \
		else tr("Tu misión: mantener a la tripulación con vida durante [b]%d minutos[/b], hasta que llegue el relevo desde la Tierra.") % minutes
	var steps: Array[Dictionary] = [
		GuideOverlay.step(tr("¡Bienvenido a la Base Lunar Selene!"),
			tr("Eres un [b]astronauta junior[/b] y hoy estás a cargo de la base.") + "\n\n" + goal),
		GuideOverlay.step(tr("Tus cinco recursos"),
			tr("Arriba, [b]oxígeno, energía y escudo[/b] son burbujas que se van gastando. Si el oxígeno, el agua, el escudo o la comida [b]llegan a cero[/b], la misión falla (la energía se recarga con los paneles solares)."),
			_hud_part(hud, "ResourcePanel")),
		GuideOverlay.step(tr("Agua, comida y minimapa"),
			tr("Abajo a la izquierda ves el [b]agua[/b] y la [b]comida[/b] en porcentaje, y el [b]minimapa[/b]: la flecha amarilla eres tú y cada sala tiene su nombre."),
			_hud_part(hud, "Minimap")),
		GuideOverlay.step(tr("Tiempo y puntos"),
			tr("Aquí ves el estado de la misión, [b]cuánto tiempo falta[/b] para el relevo y tus [b]puntos[/b]. Mientras mejor cuides la base, más puntos y mejor medalla."),
			_hud_part(hud, "InfoPanel")),
		GuideOverlay.step(tr("Cómo moverte"),
			tr("[b]W A S D[/b]: caminar · [b]Ratón[/b]: mirar\n[b]E[/b]: usar una consola · [b]R[/b]: reiniciar\n[b]ESC[/b]: pausa\n\nLas puertas se abren solas cuando te acercas."),
			_hud_part(hud, "HintBar")),
		GuideOverlay.step(tr("Las consolas"),
			tr("Cada recurso tiene su [b]consola[/b] en una sala. Acércate y pulsa [b]E[/b].\n\n• [b]Oxígeno, energía y huerto[/b] abren un minijuego (la primera vez te explicamos cómo se juega).\n• El [b]agua[/b] se repara al instante.\n• El [b]escudo[/b] se recarga en la consola del [b]DOMO[/b] (sala del generador): eliges cuánta energía desviar."),
			_nearest_console),
		GuideOverlay.step(tr("Emergencias"),
			tr("Pueden llegar [b]tormentas solares[/b] (llamaradas reales registradas por la NASA), micrometeoritos o fugas. La alerta roja aparece aquí y te dice qué recurso se dañó."),
			func() -> Variant: return _alert_area(hud)),
		GuideOverlay.step(tr("¡A la misión!"),
			tr("Si te pierdes, pulsa [b]ESC[/b] y elige [b]Cómo jugar[/b] para ver este tutorial otra vez.\n\n[b]¡Suerte, astronauta![/b]")),
	]
	return GuideOverlay.start(self, GUIDE_ID, steps, true, force)

func _is_real_game() -> bool:
	return get_tree().current_scene == self and scene_file_path == MAIN_SCENE

func _hud_part(hud: Control, path: String) -> Control:
	return hud.get_node_or_null(path) as Control if hud != null else null

## Zona donde salen las alertas (aunque la etiqueta esté vacía en ese momento).
func _alert_area(hud: Control) -> Variant:
	var alert: Control = _hud_part(hud, "AlertLabel")
	if alert == null:
		return null
	var rect: Rect2 = alert.get_global_rect()
	return rect if rect.has_area() else null

## Consola más cercana al jugador que se vea en pantalla (para señalarla en el tutorial).
func _nearest_console() -> Variant:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return null
	var best: ResourceConsole = null
	var best_distance: float = INF
	for node: Node in find_children("*", "ResourceConsole", true, false):
		var console: ResourceConsole = node as ResourceConsole
		var point: Vector3 = console.global_position + Vector3(0.0, 0.9, 0.0)
		if camera.is_position_behind(point):
			continue
		var distance: float = camera.global_position.distance_to(point)
		if distance < best_distance and get_viewport().get_visible_rect().has_point(camera.unproject_position(point)):
			best = console
			best_distance = distance
	return best

func _on_first_emergency(_type: StringName, _severity: float) -> void:
	if not _is_real_game() or _game.get_mission_state() != GameManager.MissionState.ACTIVE:
		return
	var hud: Control = get_node_or_null("UILayer/HUD") as Control
	var guide: GuideOverlay = GuideOverlay.start(self, "base_emergencia", [
		GuideOverlay.step(tr("¡Tu primera emergencia!"),
			tr("Lee la [b]alerta roja[/b]: dice qué pasó y qué recurso bajó. Busca la consola de ese recurso y repáralo antes de que llegue a cero."),
			func() -> Variant: return _alert_area(hud)),
	], true)
	if guide != null:
		await guide.finished
		_recapture_mouse()

func _on_first_critical(resource_type: StringName) -> void:
	if not _is_real_game() or _game.get_mission_state() != GameManager.MissionState.ACTIVE:
		return
	var hud: Control = get_node_or_null("UILayer/HUD") as Control
	var rows: Dictionary = {
		GameManager.RESOURCE_OXYGEN: "OxygenRow", GameManager.RESOURCE_ENERGY: "EnergyRow",
		GameManager.RESOURCE_SHIELD: "ShieldRow",
	}
	# Agua y comida están abajo a la izquierda (LifeSupportPanel), sin barra.
	var part: String = "ResourcePanel/ResourceList/" + String(rows.get(resource_type, "OxygenRow"))
	if resource_type == GameManager.RESOURCE_WATER or resource_type == GameManager.RESOURCE_FOOD:
		part = "LifeSupportPanel/LifeSupportList/" + ("WaterRow" if resource_type == GameManager.RESOURCE_WATER else "FoodRow")
	var guide: GuideOverlay = GuideOverlay.start(self, "base_recurso_bajo", [
		GuideOverlay.step(tr("¡Un recurso está muy bajo!"),
			tr("Este recurso está muy bajo. Ve a su consola y pulsa [b]E[/b] para repararlo. ¡Si llega a cero, la misión falla!"),
			_hud_part(hud, part)),
	], true)
	if guide != null:
		await guide.finished
		_recapture_mouse()

## Tras un consejo, el ratón vuelve a controlar la cámara (salvo que haya un minijuego abierto).
func _recapture_mouse() -> void:
	if not _is_minigame_open() and _game.get_mission_state() == GameManager.MissionState.ACTIVE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Con un minijuego de reparación abierto el reinicio se ignora: el jugador
	# está interactuando con la consola, no reiniciando la partida.
	if _is_minigame_open():
		return
	# Reinicio de la misión con la tecla configurada "restart_mission".
	if event.is_action_pressed("restart_mission"):
		_restart_mission()

## Indica si hay algún minijuego de reparación en pantalla.
func _is_minigame_open() -> bool:
	if not is_inside_tree():
		return false
	var manager: RepairMinigameManager = get_tree().get_first_node_in_group("repair_minigames") as RepairMinigameManager
	return manager != null and manager.is_open()

## Reinicia la partida actual desde el principio.
func _restart_mission() -> void:
	get_tree().reload_current_scene()

# --- Callbacks de señal ---

func _on_mission_failed(_reason: String) -> void:
	# Se libera el ratón para que el jugador pueda interactuar con el HUD.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Misión sin fin: no hay victoria por tiempo, así que la medalla de la base
	# se gana según cuánto se aguantó (ver PlayerProgress.medal_for_survival).
	if _game.config != null and _game.config.endless_mission:
		var medal: int = PlayerProgress.medal_for_survival(_game.get_mission_time())
		if medal > PlayerProgress.NONE:
			PlayerProgress.award_and_notify(PlayerProgress.BASE, medal)

func _on_mission_completed(_final_score: float) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Medalla de la base según cuánto quedó, en promedio, de cada recurso.
	PlayerProgress.award_and_notify(PlayerProgress.BASE, PlayerProgress.medal_for_base(average_resource_percent()))

## Promedio (0 a 100) de todos los recursos de la base en este momento.
func average_resource_percent() -> float:
	var types: Array[StringName] = [GameManager.RESOURCE_OXYGEN, GameManager.RESOURCE_ENERGY, GameManager.RESOURCE_WATER,
		GameManager.RESOURCE_SHIELD, GameManager.RESOURCE_FOOD]
	var total: float = 0.0
	for resource_type: StringName in types:
		total += _game.get_resource_percentage(resource_type)
	return total / types.size()
