class_name CombatController
extends Node

## Responsabilidad: Máquina de estados de combate, aproximación automática, cadencia de ataques y coordinación de impactos con CombatCalculator.

signal target_acquired(target: Node3D)
signal target_lost()
signal attack_executed(target: Node3D, damage: float)

enum State { IDLE, APPROACHING, ATTACKING }

const DEFAULT_COMBAT_CONFIG = preload("res://resources/combat/default_combat_config.tres")
const HIT_FX_SCENE = preload("res://scenes/combat/hit_fx.tscn")

@export var combat_config: CombatConfig = DEFAULT_COMBAT_CONFIG
@export var stats: CharacterStats = null

var current_target: Node3D = null
var state: State = State.IDLE

var _time_since_last_attack: float = 999.0
var _parent_body: CharacterBody3D = null
var _pending_impacts: Array[Dictionary] = []

func _ready() -> void:
	if combat_config == null:
		combat_config = DEFAULT_COMBAT_CONFIG.duplicate()
	if combat_config.has_method("apply_json_overrides"):
		combat_config.apply_json_overrides()
	_parent_body = get_parent() as CharacterBody3D
	get_stats()

## Obtiene o inicializa las estadísticas de combate del atacante
func get_stats() -> CharacterStats:
	if stats != null:
		return stats
	if _parent_body != null:
		var sibling_target := _parent_body.get_node_or_null("CombatTarget") as CombatTarget
		if sibling_target and sibling_target.get_stats() != null:
			stats = sibling_target.get_stats()
			return stats
	stats = CharacterStats.create_player_default()
	return stats

func set_target(new_target: Node3D) -> void:
	if new_target == null or new_target == _parent_body:
		clear_target()
		return

	# Si ya estamos enfocados en este mismo objetivo, ignorar clics repetidos
	if current_target == new_target and is_active():
		return

	current_target = new_target
	state = State.APPROACHING
	target_acquired.emit(current_target)

func clear_target() -> void:
	if current_target != null:
		current_target = null
		state = State.IDLE
		_pending_impacts.clear()
		target_lost.emit()

func is_active() -> bool:
	return state != State.IDLE and is_instance_valid(current_target)

func is_approaching() -> bool:
	return state == State.APPROACHING and is_instance_valid(current_target)

func is_attacking() -> bool:
	return state == State.ATTACKING and is_instance_valid(current_target)

## Retorna el vector de dirección horizontal hacia el objetivo si está en aproximación.
func get_approach_direction() -> Vector3:
	if not is_approaching() or _parent_body == null:
		return Vector3.ZERO

	var diff := current_target.global_position - _parent_body.global_position
	diff.y = 0.0
	return diff.normalized()

func update_combat(delta: float, visuals: PlayerVisuals) -> void:
	_time_since_last_attack += delta

	# Procesar impactos pendientes programados por la animación
	for i in range(_pending_impacts.size() - 1, -1, -1):
		_pending_impacts[i]["time_left"] -= delta
		if _pending_impacts[i]["time_left"] <= 0.0:
			var tgt: Node3D = _pending_impacts[i]["target"]
			_pending_impacts.remove_at(i)
			if is_instance_valid(tgt):
				_apply_impact(tgt)

	if not is_instance_valid(current_target):
		clear_target()
		return

	if _parent_body == null:
		return

	var dist_horiz := Vector2(
		current_target.global_position.x - _parent_body.global_position.x,
		current_target.global_position.z - _parent_body.global_position.z
	).length()

	var attack_range := combat_config.attack_range if combat_config else 1.8

	match state:
		State.APPROACHING:
			if dist_horiz <= attack_range:
				state = State.ATTACKING

		State.ATTACKING:
			# Si el objetivo se aleja, volver a perseguir
			var approach_mult := float(GameConfig.get_combat_value("combat", "approach_range_multiplier", 1.3))
			if dist_horiz > attack_range * approach_mult:
				state = State.APPROACHING
				return

			# Orientar al atacante hacia el objetivo durante el combate
			_face_target()

			# Chequear cadencia de ataque según attack_speed de las estadísticas
			var current_stats := get_stats()
			var atk_speed: float = current_stats.attack_speed if current_stats else 1.2
			var attack_interval := 1.0 / maxf(0.05, atk_speed)
			if _time_since_last_attack >= attack_interval:
				_time_since_last_attack = 0.0
				_execute_attack(visuals)

func _face_target() -> void:
	if _parent_body == null or not is_instance_valid(current_target):
		return
	var diff := current_target.global_position - _parent_body.global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		var target_yaw := atan2(-diff.x, -diff.z)
		_parent_body.rotation.y = target_yaw

func _execute_attack(visuals: PlayerVisuals) -> void:
	var current_stats := get_stats()
	var atk_speed: float = current_stats.attack_speed if current_stats else 1.0
	var speed_scale: float = 1.0
	if visuals:
		speed_scale = visuals.get_attack_speed_scale(atk_speed)

	if _can_broadcast_rpc():
		rpc("rpc_play_attack", speed_scale)
	else:
		rpc_play_attack(speed_scale)

	# El retardo de impacto se escala en la misma proporción que la velocidad de la animación
	var base_delay: float = combat_config.impact_delay if combat_config else 0.58
	var real_delay: float = base_delay / speed_scale
	_pending_impacts.append({
		"target": current_target,
		"time_left": real_delay
	})

func _apply_impact(target: Node3D) -> void:
	var offset_y := float(GameConfig.get_combat_value("combat", "impact_height_offset", 1.1))
	var hit_pos := target.global_position + Vector3(0, offset_y, 0)
	var target_path := target.get_path()

	var target_comp := _find_combat_target(target)
	var defender_stats: CharacterStats = target_comp.get_stats() if target_comp else null
	var attacker_stats: CharacterStats = get_stats()

	# Resolución mediante CombatCalculator
	var result := CombatCalculator.perform_attack(attacker_stats, defender_stats)

	if _can_broadcast_rpc():
		rpc("rpc_apply_combat_impact", hit_pos, target_path, result.total_damage, result.physical_damage, result.true_damage, result.is_crit, result.is_blocked, result.is_miss)
	else:
		rpc_apply_combat_impact(hit_pos, target_path, result.total_damage, result.physical_damage, result.true_damage, result.is_crit, result.is_blocked, result.is_miss)

## RPC sincronizado para que todos los clientes reproduzcan la animación del golpe con su escala de velocidad.
@rpc("any_peer", "call_local", "reliable")
func rpc_play_attack(speed_scale: float = 1.0) -> void:
	if _parent_body == null:
		return
	var visuals := _parent_body.get_node_or_null("Visuals") as PlayerVisuals
	if visuals:
		visuals.play_attack(speed_scale)

## RPC sincronizado para que todos los clientes vean el FX de impacto y reciban el resultado detallado de combate.
@rpc("any_peer", "call_local", "reliable")
func rpc_apply_combat_impact(
	hit_pos: Vector3,
	target_path: NodePath,
	total_damage: int,
	physical_damage: int,
	true_damage: int,
	is_crit: bool,
	is_blocked: bool,
	is_miss: bool
) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return

	# 1. Instanciar FX en el mundo solo si conectó el impacto
	if not is_miss:
		var fx := HIT_FX_SCENE.instantiate() as Node3D
		tree.root.add_child(fx)
		fx.global_position = hit_pos

	# 2. Aplicar resultado de daño al objetivo si existe en la escena
	var target_node: Node3D = null
	if not target_path.is_empty():
		target_node = tree.root.get_node_or_null(target_path) as Node3D
		if target_node == null and is_inside_tree():
			target_node = get_node_or_null(target_path) as Node3D

	if target_node:
		var target_comp := _find_combat_target(target_node)
		if target_comp:
			var res := DamageResult.new()
			res.total_damage = total_damage
			res.physical_damage = physical_damage
			res.true_damage = true_damage
			res.is_crit = is_crit
			res.is_blocked = is_blocked
			res.is_miss = is_miss
			target_comp.take_combat_result(res, hit_pos, _parent_body)
		attack_executed.emit(target_node, float(total_damage))

## RPC legacy para compatibilidad con código que invoque daño plano.
@rpc("any_peer", "call_local", "reliable")
func rpc_apply_impact(hit_pos: Vector3, target_path: NodePath, dmg: float) -> void:
	rpc_apply_combat_impact(hit_pos, target_path, int(round(dmg)), int(round(dmg)), 0, false, false, false)

func _can_broadcast_rpc() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _find_combat_target(node: Node) -> CombatTarget:
	if node is CombatTarget:
		return node
	for child in node.get_children():
		if child is CombatTarget:
			return child
	return null
