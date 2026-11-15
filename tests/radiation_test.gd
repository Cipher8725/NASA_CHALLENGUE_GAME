extends Node

## Test de la radiación con datos reales (RadLab + DONKI).
##
## Comprueba que los JSON de la NASA existen y traen sus fuentes, que el escudo se
## gasta más en los picos reales de radiación de la ISS y que una tormenta solar
## de clase X daña más el escudo que una de clase M.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _run() -> void:
	var failures: int = 0
	var game: GameManager = GameManager.get_instance()
	failures += _check("Gestor disponible", game != null)

	# --- Datos de RadLab ---
	var radlab: Dictionary = RadiationData.radlab()
	failures += _check("radlab_iss.json tiene fuentes", not (radlab.get("fuentes", []) as Array).is_empty())
	failures += _check("radlab_iss.json tiene fecha de descarga", radlab.has("fecha_descarga"))
	failures += _check("Perfil real de 24 horas", RadiationData.hourly_profile().size() == 24)
	failures += _check("Dosis diaria real (%.1f µGy)" % RadiationData.daily_dose(), RadiationData.daily_dose() > 100.0)

	# --- Datos de DONKI ---
	var donki: Dictionary = RadiationData.donki()
	failures += _check("donki_eventos.json tiene fuentes", not (donki.get("fuentes", []) as Array).is_empty())
	failures += _check("Hay erupciones solares reales (%d)" % RadiationData.flares().size(), RadiationData.flares().size() > 0)
	var all_have_id: bool = true
	for flare: Variant in RadiationData.flares():
		if String((flare as Dictionary).get("id", "")).is_empty() or String((flare as Dictionary).get("url", "")).is_empty():
			all_have_id = false
	failures += _check("Cada erupción tiene ID y enlace de DONKI", all_have_id)

	# --- El escudo sigue la radiación real ---
	var peak_factor: float = RadiationData.shield_factor(4.5 / 24.0)
	var quiet_factor: float = RadiationData.shield_factor(8.5 / 24.0)
	failures += _check("Pico real (hora 4): factor %.1f" % peak_factor, peak_factor > RadiationData.HIGH_RADIATION_FACTOR)
	failures += _check("Hora tranquila (hora 8): factor %.2f" % quiet_factor, quiet_factor < 1.0)

	# --- Severidad por clase ---
	var sev_c: float = RadiationData.severity_for_class("C3.0")
	var sev_m: float = RadiationData.severity_for_class("M5.9")
	var sev_x: float = RadiationData.severity_for_class("X8.1")
	failures += _check("Clase X > M > C (%.2f > %.2f > %.2f)" % [sev_x, sev_m, sev_c], sev_x > sev_m and sev_m > sev_c)

	# --- Daño real en el escudo ---
	var shield: StringName = GameManager.RESOURCE_SHIELD
	game.restore_resource(shield, 1000.0)
	var before_m: float = game.get_resource_level(shield)
	game.trigger_solar_flare({"clase": "M5.9", "pico": "2025-11-28T22:22Z"})
	var loss_m: float = before_m - game.get_resource_level(shield)
	game.restore_resource(shield, 1000.0)
	var before_x: float = game.get_resource_level(shield)
	game.trigger_solar_flare({"clase": "X8.1", "pico": "2026-02-01T23:57Z"})
	var loss_x: float = before_x - game.get_resource_level(shield)
	failures += _check("La tormenta X quita más escudo (%.1f) que la M (%.1f)" % [loss_x, loss_m], loss_x > loss_m and loss_m > 0.0)
	failures += _check("El gestor recuerda la última tormenta", String(game.get_last_solar_flare().get("clase", "")) == "X8.1")
	failures += _check("Texto del HUD con fecha real", RadiationData.flare_label(game.get_last_solar_flare()).contains("2026-02-01"))
	game.restore_resource(shield, 1000.0)

	# --- El sistema de emergencias usa erupciones reales ---
	var system: EmergencySystem = (load("res://scenes/emergency_system.tscn") as PackedScene).instantiate() as EmergencySystem
	add_child(system)
	failures += _check("Las tormentas solares están habilitadas", system.enabled_emergency_types.has(GameManager.EMERGENCY_SOLAR_STORM))
	system.trigger_now(GameManager.EMERGENCY_SOLAR_STORM, 0.0)
	var used: Dictionary = game.get_last_solar_flare()
	failures += _check("trigger_now usa una erupción de DONKI (%s)" % used.get("id", "?"), RadiationData.flares().has(used))
	game.restore_resource(shield, 1000.0)

	print("=== RESULTADO RADIACION: %s ===" % ("TODO OK" if failures == 0 else "FALLOS (%d)" % failures))
	get_tree().quit(1 if failures > 0 else 0)

func _check(label: String, condition: bool) -> int:
	if condition:
		print("  [OK]   ", label)
		return 0
	print("  [FALLO] ", label)
	return 1
