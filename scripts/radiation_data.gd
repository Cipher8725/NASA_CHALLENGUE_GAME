class_name RadiationData
extends RefCounted

## Datos reales de radiación usados por la Base lunar.
##
## - `resources/radiacion/radlab_iss.json`: dosis medida en la ISS por los detectores
##   DosTel (NASA OSDR RadLab), 24 horas del 1 de abril de 2022.
## - `resources/radiacion/donki_eventos.json`: erupciones solares reales registradas por
##   DONKI (NASA CCMC).
##
## Ningún número de radiación se inventa aquí: solo se leen esos archivos. Lo que es
## regla de juego (escala de tiempo, daño por clase) está marcado como "aproximado"
## dentro de los propios JSON.

const RADLAB_PATH: String = "res://resources/radiacion/radlab_iss.json"
const DONKI_PATH: String = "res://resources/radiacion/donki_eventos.json"
## Detector cuyo perfil horario se usa en el juego.
const PROFILE_DETECTOR: String = "DosTel1"
## Factor (tasa / media del día) a partir del cual el HUD avisa de radiación alta.
const HIGH_RADIATION_FACTOR: float = 4.0

static var _radlab: Dictionary = {}
static var _donki: Dictionary = {}

## Lee y guarda en caché un JSON del proyecto.
static func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RadiationData: no se encontró %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

static func radlab() -> Dictionary:
	if _radlab.is_empty():
		_radlab = _load_json(RADLAB_PATH)
	return _radlab

static func donki() -> Dictionary:
	if _donki.is_empty():
		_donki = _load_json(DONKI_PATH)
	return _donki

static func _detector() -> Dictionary:
	var detectors: Dictionary = radlab().get("detectores", {})
	return detectors.get(PROFILE_DETECTOR, {})

## Perfil real de 24 valores (µGy/h), uno por hora UTC.
static func hourly_profile() -> Array:
	return _detector().get("media_por_hora_uGy_h", [])

## Tasa media del día medido (µGy/h).
static func mean_rate() -> float:
	return float(_detector().get("tasa_media_uGy_h", 0.0))

## Dosis total de las 24 horas medidas (µGy).
static func daily_dose() -> float:
	return float(_detector().get("dosis_24h_uGy", 0.0))

## Hora del día real (0-23) que representa una fracción de la misión (0-1).
static func hour_for_progress(progress: float) -> int:
	return clampi(int(floorf(clampf(progress, 0.0, 0.9999) * 24.0)), 0, 23)

## Tasa real (µGy/h) para un momento de la misión.
static func rate_for_progress(progress: float) -> float:
	var profile: Array = hourly_profile()
	if profile.is_empty():
		return mean_rate()
	return float(profile[hour_for_progress(progress)])

## Multiplicador del desgaste del escudo: tasa de ese momento / tasa media del día.
## Fórmula documentada en radlab_iss.json → uso_en_juego.formula.
static func shield_factor(progress: float) -> float:
	var mean: float = mean_rate()
	if mean <= 0.0:
		return 1.0
	return rate_for_progress(progress) / mean

## Lista de erupciones solares reales.
static func flares() -> Array:
	return donki().get("eventos", [])

## Elige una erupción real al azar (diccionario vacío si no hay datos).
static func random_flare() -> Dictionary:
	var list: Array = flares()
	if list.is_empty():
		return {}
	return list[randi() % list.size()] as Dictionary

## Severidad de juego (0-1) para una clase como "M5.9" o "X8.1".
static func severity_for_class(flare_class: String) -> float:
	var table: Dictionary = donki().get("severidad_por_clase", {})
	if flare_class.is_empty():
		return 0.5
	var letter: String = flare_class.substr(0, 1).to_upper()
	var magnitude: float = flare_class.substr(1).to_float()
	var base: float = float(table.get(letter, 0.5))
	var extra: float = float(table.get("extra_por_magnitud", 0.0)) * magnitude
	return minf(base + extra, float(table.get("maximo", 1.0)))

## Puntos de escudo que quita una tormenta de severidad 1.
static func shield_damage_per_severity() -> float:
	return float(donki().get("dano_escudo_por_severidad", 25.0))

## Texto corto de una erupción para el HUD.
static func flare_label(flare: Dictionary) -> String:
	var peak: String = String(flare.get("pico", flare.get("inicio", "")))
	return TranslationServer.translate("Tormenta solar clase %s (DONKI, %s)") % [flare.get("clase", "?"), peak.substr(0, 10)]
