class_name TrainingDummy
extends StaticBody3D

## Responsabilidad: Muñeco de práctica para pruebas de combate y feedback visual de impacto.

@onready var combat_target: CombatTarget = $CombatTarget
@onready var health_bar: HealthBar3D = get_node_or_null("HealthBar3D")
@onready var mesh: MeshInstance3D = $MeshInstance3D

var _default_mat: StandardMaterial3D = null
var _reset_timer: SceneTreeTimer = null

func _ready() -> void:
	if mesh:
		_default_mat = mesh.get_surface_override_material(0)
		if _default_mat == null and mesh.mesh:
			_default_mat = mesh.mesh.surface_get_material(0)

	if combat_target:
		var stats := combat_target.get_stats()
		if stats:
			combat_target.max_health = float(stats.max_hp)
			combat_target.current_health = float(stats.current_hp)
		combat_target.hit_received.connect(_on_hit_received)
		combat_target.died.connect(_on_dummy_died)

	if health_bar and combat_target:
		health_bar.set_entity_name(combat_target.target_name, Color(1.0, 0.8, 0.55))
		health_bar.set_health(combat_target.current_health, combat_target.max_health, false)

func _on_hit_received(_damage: float, _hit_pos: Vector3, _attacker: Node) -> void:
	_flash_red()

func _on_dummy_died() -> void:
	# Al llegar a 0 HP, restaurar la salud tras el tiempo configurado para permitir entrenamiento continuo
	if _reset_timer != null:
		return
	var delay := float(GameConfig.get_combat_value("targets", "dummy_respawn_delay", 2.0))
	_reset_timer = get_tree().create_timer(delay)
	_reset_timer.timeout.connect(func():
		_reset_timer = null
		if combat_target:
			combat_target.reset_health()
	)

func _flash_red() -> void:
	if mesh == null:
		return
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.25, 0.25)
	mesh.material_override = flash_mat

	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func(): mesh.material_override = null)
