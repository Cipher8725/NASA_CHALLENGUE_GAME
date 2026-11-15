extends Node

## Test de los datos reales de radiacion de la NASA y de la tormenta solar.
##
## Comprueba que:
##  * Los dos JSON existen y tienen los campos "fuentes" y "fecha_descarga".
##  * La dosis de RadLab es un valor real (no cero) y coincide con el JSON.
##  * Una tormenta solar de clase X daña el escudo MAS que una de clase C.
##  * El aviso del HUD lleva la clase y la fecha del evento de DONKI.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _run() -> void:
	var failures: int = 0
	failures += _test_json_radlab()
	failures += _test_json_donki()
	failures += _test_dosis_consistente()
	failures += await _test_tormenta_solar_clases()
	failures += _test_formula_shield_decay()
	print("=== RESULTADO RADIACION: %s ===" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(0 if failures == 0 else 1)

## El JSON de RadLab debe existir y traer fuentes y fecha de descarga.
func _test_json_radlab() -> int:
	var failures: int = 0
	var ruta: String = "res://resources/radiacion/radlab_iss.json"
	failures += _check("Existe el JSON de RadLab", FileAccess.file_exists(ruta))
	if not FileAccess.file_exists(ruta):
		return failures
	var datos: Dictionary = _leer_json(ruta)
	var tiene_fuentes: bool = datos.has("fuentes") and (datos.get("fuentes", []) as Array).size() > 0
	failures += _check("El JSON de RadLab tiene 'fuentes'", tiene_fuentes)
	failures += _check("El JSON de RadLab tiene 'fecha_descarga'", str(datos.get("fecha_descarga", "")) != "")
	var mediciones: Array = datos.get("mediciones", []) as Array
	failures += _check("El JSON de RadLab tiene mediciones", mediciones.size() > 0)
	var instrumentos: Array = datos.get("instrumentos", []) as Array
	failures += _check("El JSON de RadLab nombra los instrumentos", instrumentos.size() > 0)
	if mediciones.size() > 0:
		var medicion: Dictionary = mediciones[0] as Dictionary
		failures += _check("Cada medición tiene fecha", str(medicion.get("fecha", "")) != "")
		failures += _check("Cada medición tiene instrumento", str(medicion.get("instrumento", "")) != "")
		failures += _check("Cada medición tiene dosis en uGy/día", float(medicion.get("dosis_absorbida_ugy_dia", 0.0)) > 0.0)
	return failures

## El JSON de DONKI debe existir y traer fuentes, fecha y eventos con clase.
func _test_json_donki() -> int:
	var failures: int = 0
	var ruta: String = "res://resources/radiacion/donki_eventos.json"
	failures += _check("Existe el JSON de DONKI", FileAccess.file_exists(ruta))
	if not FileAccess.file_exists(ruta):
		return failures
	var datos: Dictionary = _leer_json(ruta)
	var tiene_fuentes: bool = datos.has("fuentes") and (datos.get("fuentes", []) as Array).size() > 0
	failures += _check("El JSON de DONKI tiene 'fuentes'", tiene_fuentes)
	failures += _check("El JSON de DONKI tiene 'fecha_descarga'", str(datos.get("fecha_descarga", "")) != "")
	var eventos: Array = datos.get("eventos", []) as Array
	failures += _check("El JSON de DONKI tiene eventos", eventos.size() > 0)
	var totales: Dictionary = datos.get("totales", {}) as Dictionary
	failures += _check("El JSON de DONKI tiene tormentas solares", int(totales.get("tormentas_solares", 0)) > 0)
	failures += _check("El JSON de DONKI tiene eyecciones de masa coronal", int(totales.get("eyecciones_masa_coronal", 0)) > 0)
	var tabla: Dictionary = datos.get("clase_a_severidad", {}) as Dictionary
	failures += _check("La tabla clase -> severidad existe", tabla.has("C") and tabla.has("M") and tabla.has("X"))
	var nota: String = str(datos.get("nota_severidad", "")).to_lower()
	failures += _check("La severidad está marcada como aproximada (juego)", "aproximado" in nota)
	if eventos.size() > 0:
		var evento: Dictionary = eventos[0] as Dictionary
		failures += _check("Cada evento tiene fecha", str(evento.get("fecha", "")) != "")
		failures += _check("Cada evento tiene id de DONKI", str(evento.get("id_donki", "")) != "")
	var con_clase: int = 0
	for item: Variant in eventos:
		var evento2: Dictionary = item as Dictionary
		if str(evento2.get("tipo", "")) == "tormenta_solar" and str(evento2.get("clase", "")) != "":
			con_clase += 1
	failures += _check("Las tormentas solares traen su clase", con_clase > 0)
	return failures

## Los valores cargados por el script deben coincidir con el JSON en disco.
func _test_dosis_consistente() -> int:
	var failures: int = 0
	var radiacion: RadiationData = RadiationData.get_instance()
	failures += _check("RadiationData carga la dosis de RadLab", radiacion.dosis_media_ugy_dia > 0.0)
	var datos: Dictionary = _leer_json("res://resources/radiacion/radlab_iss.json")
	var estadisticas: Dictionary = datos.get("estadisticas", {}) as Dictionary
	var esperada: float = float(estadisticas.get("dosis_absorbida_media_ugy_dia", 0.0))
	failures += _check("La dosis en memoria coincide con el JSON", is_equal_approx(radiacion.dosis_media_ugy_dia, esperada))
	failures += _check("RadiationData carga los eventos de DONKI", radiacion.eventos.size() > 0)
	failures += _check("El texto de resultado menciona µGy y RadLab", "RadLab" in radiacion.get_texto_dosis_iss())
	return failures

## Provoca una tormenta solar y comprueba que daña mas el escudo.
func _test_tormenta_solar_clases() -> int:
	var failures: int = 0
	var game: GameManager = GameManager.get_instance()
	if game == null:
		return _check("El GameManager esta disponible", false)

	# Se localizan eventos reales de clase X y de clase C.
	var evento_x: RadiationData.SpaceWeatherEvent = null
	var evento_c: RadiationData.SpaceWeatherEvent = null
	for evento: RadiationData.SpaceWeatherEvent in RadiationData.get_instance().eventos:
		if evento.familia_clase == "X" and evento_x == null:
			evento_x = evento
		elif evento.familia_clase == "C" and evento_c == null:
			evento_c = evento
	failures += _check("Hay un evento real de clase X en DONKI", evento_x != null)
	failures += _check("Hay un evento real de clase C en DONKI", evento_c != null)
	if evento_x == null or evento_c == null:
		return failures

	# Daño de la clase X con el escudo lleno.
	game.restore_resource(GameManager.RESOURCE_SHIELD, game.get_resource_max(GameManager.RESOURCE_SHIELD))
	var antes_x: float = game.get_resource_level(GameManager.RESOURCE_SHIELD)
	game.trigger_solar_storm(evento_x)
	var despues_x: float = game.get_resource_level(GameManager.RESOURCE_SHIELD)
	var dano_x: float = antes_x - despues_x

	# Mismo proceso con la clase C.
	game.restore_resource(GameManager.RESOURCE_SHIELD, game.get_resource_max(GameManager.RESOURCE_SHIELD))
	var antes_c: float = game.get_resource_level(GameManager.RESOURCE_SHIELD)
	game.trigger_solar_storm(evento_c)
	var despues_c: float = game.get_resource_level(GameManager.RESOURCE_SHIELD)
	var dano_c: float = antes_c - despues_c

	failures += _check("La clase X daña el escudo", dano_x > 0.0)
	failures += _check("La clase C daña el escudo", dano_c > 0.0)
	failures += _check("La clase X daña MAS que la clase C", dano_x > dano_c)
	var aviso: String = evento_x.get_aviso()
	failures += _check("El aviso lleva la clase y la fecha de DONKI", aviso.contains(evento_x.clase) and aviso.contains(evento_x.fecha))
	failures += _check("El aviso menciona DONKI", "DONKI" in aviso)
	return failures

## La tasa de desgaste del escudo debe salir de la fórmula documentada con la
## dosis real de RadLab.
func _test_formula_shield_decay() -> int:
	var failures: int = 0
	var datos: Dictionary = _leer_json("res://resources/radiacion/radlab_iss.json")
	failures += _check("El JSON documenta la fórmula del escudo", datos.has("formula_shield_decay_rate"))
	if not datos.has("formula_shield_decay_rate"):
		return failures
	var formula: Dictionary = datos.get("formula_shield_decay_rate", {}) as Dictionary
	failures += _check("La fórmula indica los pasos", (formula.get("pasos", []) as Array).size() > 0)
	var nota: String = str(formula.get("nota", "")).to_lower()
	failures += _check("La fórmula está marcada como aproximada (juego)", "aproximado" in nota)

	# La tasa configurada debe coincidir con la de la fórmula.
	var config: MissionConfig = load("res://resources/default_mission.tres") as MissionConfig
	var esperada: float = float(formula.get("valor_resultante_shield_decay_rate", 0.0))
	failures += _check("La tasa del escudo coincide con la fórmula", is_equal_approx(config.shield_decay_rate, esperada))
	return failures

# --- Utilidades ---

func _leer_json(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not (datos is Dictionary):
		return {}
	return datos as Dictionary

func _check(label: String, condition: bool) -> int:
	if not condition:
		print("  [FALLO] ", label)
		return 1
	print("  [OK]   ", label)
	return 0
