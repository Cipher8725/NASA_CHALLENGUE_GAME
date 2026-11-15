class_name MissionConfig
extends Resource

## Configuración data-driven de una misión.
## Todos los valores ajustables del juego viven aquí (regla "gameplay.md": sin números mágicos).

@export_group("Objetivo de misión")
## Duración de la misión en segundos. Sobrevivir este tiempo = victoria.
@export var mission_duration: float = 240.0
## Segundos que debe durar el estado BRIEFING antes de iniciar la mission activa.
@export var briefing_duration: float = 3.0

@export_group("Capacidades máximas")
@export var max_oxygen: float = 100.0
@export var max_energy: float = 100.0
@export var max_water: float = 100.0
@export var max_shield: float = 100.0
@export var max_food: float = 100.0

@export_group("Tasas de decaimiento (unidades por segundo)")
@export var oxygen_decay_rate: float = 0.5
@export var energy_decay_rate: float = 0.3
@export var water_decay_rate: float = 0.2
## Desgaste del escudo radioactivo.
##
## Se calcula desde la dosis REAL medida en la ISS por el RadLab de la NASA
## (instrumentos TEPC): 327,412 µGy/día de media.
##
##   dosis_real_mision_µGy = 327,412 × (180 s ÷ 86 400 s/día) = 0,682108 µGy
##   presupuesto_escudo_µGy = 100 puntos × 6,82108 µGy = 682,108 µGy
##        (cada punto cubre 10 veces la dosis real de una partida)
##   tasa_escudo = max_shield ÷ (mission_duration × 10)
##               = 100 ÷ (180 × 10) = 0,0556 puntos/s
##
## El factor 10 es un APROXIMADO (juego): convierte la escala de tiempo real
## (180 s son 0,00208 de un día) en una escala jugable. La dosis de RadLab
## que aparece arriba es el dato real; la compresión para la partida, no.
## La fórmula completa está también en `resources/radiacion/radlab_iss.json`.
@export var shield_decay_rate: float = 0.0556
## Decaimiento de la comida: se consume al preparar y comer raciones.
@export var food_decay_rate: float = 0.12

@export_group("Emergencias")
## Segundos mínimos y máximos entre eventos de emergencia.
@export var emergency_interval_min: float = 25.0
@export var emergency_interval_max: float = 45.0
## Rango de severidad (0.0 = leve, 1.0 = catastrófico).
@export var emergency_severity_min: float = 0.3
@export var emergency_severity_max: float = 0.8
## Daño que aplica una tormenta solar al escudo, en puntos, con severidad 1.0.
## La severidad real sale de la clase del evento DONKI (C, M o X).
@export var shield_solar_storm_damage: float = 22.0

@export_group("Puntuación")
## Puntos por segundo survival durante la misión.
@export var score_per_second: float = 1.0
## Bonus de puntuación por cada punto de recurso restante al completar.
@export var score_per_remaining_resource: float = 2.0

@export_group("Umbrales")
## Porcentaje por debajo del cual un recurso se considera crítico.
@export_range(0.0, 100.0, 1.0) var critical_threshold: float = 20.0
## Cantidad restaurada por cada interacción con una consola.
@export var console_restore_amount: float = 25.0
