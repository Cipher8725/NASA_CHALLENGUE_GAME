class_name RadiationData
extends RefCounted

## Datos reales de radiación del espacio, descargados de la NASA.
##
## Este script NO inventa cifras: lee los JSON que hay en `resources/radiacion/`
## (descargados una vez con `tools/descargar_datos_nasa.py`) y expone helpers
## para que el juego pueda usarlos.
##
## Fuentes:
##  * RadLab (NASA/OSDR): dosis absorbida medida en la ISS.
##  * DONKI (NASA/CCMC): tormentas solares y eyecciones de masa coronal.
##
## Si un archivo falta o está mal escrito, se avisa y el juego sigue
## funcionando con valores por defecto marcados como aproximados.

const RADLAB_PATH: String = "res://resources/radiacion/radlab_iss.json"
const DONKI_PATH: String = "res://resources/radiacion/donki_eventos.json"

## Evento de clima espacial real.
class SpaceWeatherEvent extends RefCounted:
	var tipo: String = ""
	var id_donki: String = ""
	var fecha: String = ""
	var clase: String = ""
	var familia_clase: String = ""
	var severidad: float = 0.0
	var etiqueta_severidad: String = ""
	var velocidad_km_s: int = 0

	func get_titulo() -> String:
		if tipo == "tormenta_solar":
			return "Tormenta solar clase %s" % clase
		return "Eyeccion de masa coronal"

	## Texto del aviso que se muestra en el HUD.
	func get_aviso() -> String:
		var texto: String = get_titulo()
		if tipo == "eyeccion_masa_coronal" and velocidad_km_s > 0:
			texto = "Eyeccion de masa coronal a %d km/s" % velocidad_km_s
		return "%s (DONKI, %s)" % [texto, fecha]

static var _instance: RadiationData = null

## Instancia compartida (los datos no cambian durante la partida).
static func get_instance() -> RadiationData:
	if _instance == null:
		_instance = RadiationData.new()
		_instance._cargar()
	return _instance

# --- Datos cargados ---

## Dosis absorbida media diaria medida en la ISS, en µGy/día.
var dosis_media_ugy_dia: float = 0.0
## Dosis absorbida media diaria, en mGy/día.
var dosis_media_mgy_dia: float = 0.0
## Número de mediciones diarias usadas para la media.
var numero_mediciones: int = 0
## Instrumentos que tomaron las mediciones.
var instrumentos: Array[String] = []
## URL de la API de RadLab.
var url_radlab: String = ""
## Fecha en que se descargaron los datos.
var fecha_descarga_radlab: String = ""

## Eventos de clima espacial (tormentas solares y CMEs), del más reciente al más antiguo.
var eventos: Array[SpaceWeatherEvent] = []
## Tabla clase -> severidad (aproximada, es la decisión de diseño del juego).
var clase_a_severidad: Dictionary = {}
## URL de la API de DONKI.
var url_donki: String = ""
## Fecha en que se descargaron los eventos.
var fecha_descarga_donki: String = ""

# --- API pública ---

## Devuelve el evento real que corresponde a una clase de tormenta solar.
## Si no hay ninguno con esa clase, devuelve null.
func get_evento_de_clase(familia: String) -> SpaceWeatherEvent:
	for evento: SpaceWeatherEvent in eventos:
		if evento.familia_clase == familia:
			return evento
	return null

## Devuelve el evento real con la mayor severidad de su clase.
## Se usa para que la tormenta mas fuerte sea la que castiga mas.
func get_evento_mas_severo() -> SpaceWeatherEvent:
	var mejor: SpaceWeatherEvent = null
	for evento: SpaceWeatherEvent in eventos:
		if mejor == null or evento.severidad > mejor.severidad:
			mejor = evento
	return mejor

## Texto con el dato real de radiacion para la pantalla de resultado.
func get_texto_dosis_iss() -> String:
	if dosis_media_ugy_dia <= 0.0:
		return ""
	return "En la ISS un astronauta recibe unos %.0f µGy al día (RadLab, NASA)" % dosis_media_ugy_dia

## Texto corto con el dato real, para la pantalla de resultado.
func get_texto_dosis_iss_corto() -> String:
	if dosis_media_mgy_dia <= 0.0:
		return ""
	return "Dosis real en la ISS: %.3f mGy/día (RadLab, NASA)" % dosis_media_mgy_dia

# --- Carga ---

func _cargar() -> void:
	_cargar_radlab()
	_cargar_donki()

func _cargar_radlab() -> void:
	var datos: Dictionary = _leer_json(RADLAB_PATH)
	if datos.is_empty():
		push_warning("RadiationData: no se pudo leer %s" % RADLAB_PATH)
		return
	var estadisticas: Dictionary = datos.get("estadisticas", {}) as Dictionary
	dosis_media_ugy_dia = float(estadisticas.get("dosis_absorbida_media_ugy_dia", 0.0))
	dosis_media_mgy_dia = float(estadisticas.get("dosis_absorbida_media_mgy_dia", 0.0))
	numero_mediciones = int((datos.get("periodo", {}) as Dictionary).get("numero_de_mediciones_diarias", 0))
	instrumentos.assign(Array(datos.get("instrumentos", [])))
	url_radlab = str(datos.get("url_consulta", ""))
	fecha_descarga_radlab = str(datos.get("fecha_descarga", ""))

func _cargar_donki() -> void:
	var datos: Dictionary = _leer_json(DONKI_PATH)
	if datos.is_empty():
		push_warning("RadiationData: no se pudo leer %s" % DONKI_PATH)
		return
	clase_a_severidad = datos.get("clase_a_severidad", {}) as Dictionary
	url_donki = str((datos.get("urls_consulta", {}) as Dictionary).get("tormentas_solares", ""))
	fecha_descarga_donki = str(datos.get("fecha_descarga", ""))
	var lista: Array = datos.get("eventos", []) as Array
	for item: Variant in lista:
		if not (item is Dictionary):
			continue
		var dato: Dictionary = item as Dictionary
		var evento := SpaceWeatherEvent.new()
		evento.tipo = str(dato.get("tipo", ""))
		evento.id_donki = str(dato.get("id_donki", ""))
		evento.fecha = str(dato.get("fecha", ""))
		evento.clase = str(dato.get("clase", ""))
		evento.familia_clase = str(dato.get("familia_clase", ""))
		evento.velocidad_km_s = int(dato.get("velocidad_km_s", 0))
		var regla: Dictionary = clase_a_severidad.get(evento.familia_clase, {}) as Dictionary
		# La clase B no tiene severidad definida por la NASA: se deja vacia
		# (no se inventa) y el evento no genera tormenta.
		var severidad: Variant = regla.get("severidad", null)
		if severidad == null:
			continue
		evento.severidad = float(severidad)
		evento.etiqueta_severidad = str(regla.get("etiqueta", ""))
		eventos.append(evento)
	# Los eventos mas recientes primero: son los mas relevantes para la partida.
	eventos.sort_custom(func(a: SpaceWeatherEvent, b: SpaceWeatherEvent) -> bool:
		return a.fecha > b.fecha)

func _leer_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var texto: String = FileAccess.get_file_as_string(path)
	var datos: Variant = JSON.parse_string(texto)
	if not (datos is Dictionary):
		push_warning("RadiationData: %s no contiene un objeto JSON válido." % path)
		return {}
	return datos as Dictionary
