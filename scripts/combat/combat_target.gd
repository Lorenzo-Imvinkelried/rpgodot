class_name CombatTarget
extends Node

## Responsabilidad: Identifica a una entidad como objetivo atacable y gestiona la recepción de impactos.
## Puede adjuntarse a personajes, muñecos de práctica o enemigos.

signal hit_received(damage: float, hit_position: Vector3, attacker: Node)

@export var target_name: String = "Objetivo"
@export var max_health: float = 100.0

var current_health: float = 100.0

func _ready() -> void:
	current_health = max_health
	add_to_group("targetable")

## Registra un impacto recibido y emite la señal correspondiente.
func take_hit(damage: float, hit_position: Vector3, attacker: Node) -> void:
	current_health = maxf(0.0, current_health - damage)
	hit_received.emit(damage, hit_position, attacker)
	_play_hit_feedback()

func _play_hit_feedback() -> void:
	var parent_3d := get_parent() as Node3D
	if parent_3d == null:
		return

	# Buscar nodo visual (Visuals o MeshInstance3D) para escalar sin alterar el CollisionShape en Jolt
	var visual_node: Node3D = null
	if parent_3d.has_node("Visuals"):
		visual_node = parent_3d.get_node("Visuals") as Node3D
	elif parent_3d.has_node("MeshInstance3D"):
		visual_node = parent_3d.get_node("MeshInstance3D") as Node3D

	if visual_node:
		var tween := visual_node.create_tween()
		var orig_scale := visual_node.scale
		tween.tween_property(visual_node, "scale", orig_scale * 1.08, 0.06)
		tween.tween_property(visual_node, "scale", orig_scale, 0.12)
