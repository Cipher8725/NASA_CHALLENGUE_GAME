class_name StationDome
extends Node3D

## Domo geodésico que cubre toda la estación (modelo de Meshy en
## `res://ai_assets/models/domo/domo_estacion.glb`).
##
## - El tamaño y la posición del modelo están en `scenes/station_dome.tscn`
##   (nodo `Model`): 161 × 273 m de ancho máximo, 50 m de alto y una elipse
##   de 132 × 224 m en el suelo.
## - La colisión es una `ConcavePolygonShape3D` construida en `_ready()` con
##   los triángulos reales del modelo YA escalados: Godot no admite escala no
##   uniforme en formas cóncavas, así que la escala se aplica a los vértices y
##   el `CollisionShape3D` queda sin escalar. Es solo la cáscara: dentro del
##   domo nada choca con él.
## - El vidrio es translúcido (se ve la estación desde fuera y el cielo desde
##   dentro) y brilla más cuanto más escudo tiene: es el escudo del domo.

## Opacidad del vidrio (0 = invisible, 1 = opaco).
@export_range(0.0, 1.0, 0.01) var glass_alpha: float = 0.16
## Color del vidrio.
@export var glass_color: Color = Color(0.62, 0.84, 1.0)
## Color del brillo del escudo.
@export var shield_glow_color: Color = Color(0.35, 0.75, 1.0)
## Intensidad del brillo con el escudo al 100 %.
@export var max_glow_energy: float = 0.6

@onready var _model: Node3D = %Model
@onready var _collision: CollisionShape3D = %DomeCollision

var _material: StandardMaterial3D = null

func _ready() -> void:
	_build_collision()
	_apply_glass_material()
	var game: GameManager = GameManager.get_instance()
	if game != null:
		game.resource_changed.connect(_on_resource_changed)
		_set_glow(game.get_resource_percentage(GameManager.RESOURCE_SHIELD) / 100.0)

## Construye la cáscara de colisión con la geometría escalada del modelo.
func _build_collision() -> void:
	var faces: PackedVector3Array = PackedVector3Array()
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		# Transformación de la malla relativa al domo (incluye la escala del Model).
		var to_dome: Transform3D = _relative_transform(mesh_instance)
		for vertex: Vector3 in mesh_instance.mesh.get_faces():
			faces.append(to_dome * vertex)
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	# Se choca por las dos caras: desde dentro y desde fuera del domo.
	shape.backface_collision = true
	shape.set_faces(faces)
	_collision.shape = shape

## Vidrio translúcido conservando el relieve (normal/ORM) que generó Meshy.
func _apply_glass_material() -> void:
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: StandardMaterial3D = mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			var glass: StandardMaterial3D = source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			glass.albedo_color = Color(glass_color, glass_alpha)
			glass.emission_enabled = true
			glass.emission = shield_glow_color
			mesh_instance.set_surface_override_material(surface, glass)
			_material = glass

## Brillo proporcional al escudo (0-1).
func _set_glow(fraction: float) -> void:
	if _material != null:
		_material.emission_energy_multiplier = max_glow_energy * clampf(fraction, 0.0, 1.0)

## Transformación de un nodo relativa a este domo (sin depender del árbol global).
func _relative_transform(node: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != self:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

func _on_resource_changed(resource_type: StringName, current_value: float, max_value: float) -> void:
	if resource_type == GameManager.RESOURCE_SHIELD and max_value > 0.0:
		_set_glow(current_value / max_value)

## Número de triángulos de la cáscara de colisión (para las pruebas).
func get_collision_triangle_count() -> int:
	var shape: ConcavePolygonShape3D = _collision.shape as ConcavePolygonShape3D
	return 0 if shape == null else shape.get_faces().size() / 3
