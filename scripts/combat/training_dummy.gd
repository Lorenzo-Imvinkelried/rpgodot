class_name TrainingDummy
extends StaticBody3D

## Responsabilidad: Muñeco de práctica para pruebas de combate y feedback visual de impacto.

@onready var combat_target: CombatTarget = $CombatTarget
@onready var label: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

var _default_mat: StandardMaterial3D = null

func _ready() -> void:
	if mesh:
		_default_mat = mesh.get_surface_override_material(0)
		if _default_mat == null and mesh.mesh:
			_default_mat = mesh.mesh.surface_get_material(0)

	if combat_target:
		combat_target.hit_received.connect(_on_hit_received)
	_update_label()

func _on_hit_received(damage: float, _hit_pos: Vector3, _attacker: Node) -> void:
	_update_label()
	_flash_red()

func _update_label() -> void:
	if label and combat_target:
		label.text = "Muñeco (HP: %d/%d)" % [int(combat_target.current_health), int(combat_target.max_health)]

func _flash_red() -> void:
	if mesh == null:
		return
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.25, 0.25)
	mesh.material_override = flash_mat

	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func(): mesh.material_override = null)
