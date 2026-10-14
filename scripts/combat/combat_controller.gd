class_name CombatController
extends Node

## Responsabilidad: Máquina de estados de combate, aproximación automática, cadencia de ataques
## y coordinación de impactos individuales y multi-strike (Ghost Slashes) con CombatCalculator.

signal target_acquired(target: Node3D)
signal target_lost()
signal attack_executed(target: Node3D, damage: float)
signal multi_strike_triggered(num_hits: int)

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
var _target_combat_target: CombatTarget = null

func _ready() -> void:
	if combat_config == null:
		combat_config = DEFAULT_COMBAT_CONFIG.duplicate()
	if combat_config.has_method("apply_json_overrides"):
		combat_config.apply_json_overrides()
	_get_parent_body()
	get_stats()

func _get_parent_body() -> CharacterBody3D:
	if _parent_body == null or not is_instance_valid(_parent_body):
		_parent_body = get_parent() as CharacterBody3D
	return _parent_body

## Obtiene o inicializa las estadísticas de combate del atacante
func get_stats() -> CharacterStats:
	if stats != null:
		return stats
	var p := _get_parent_body()
	if p != null:
		var sibling_target := p.get_node_or_null("CombatTarget") as CombatTarget
		if sibling_target and sibling_target.get_stats() != null:
			stats = sibling_target.get_stats()
			return stats
	stats = CharacterStats.create_player_default()
	return stats

## Calcula el radio físico horizontal del objetivo para ajustar el rango de ataque superficie-a-superficie.
static func get_target_bounding_radius(target_node: Node3D) -> float:
	if not is_instance_valid(target_node):
		return 0.0

	if target_node.has_method("get_bounding_radius"):
		return float(target_node.get_bounding_radius())

	# 1. Buscar CollisionShape3D en el objetivo
	var col_shape := target_node.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col_shape and col_shape.shape:
		var global_scale := target_node.global_transform.basis.get_scale()
		var h_scale := maxf(absf(global_scale.x), absf(global_scale.z))

		if col_shape.shape is CapsuleShape3D:
			return (col_shape.shape as CapsuleShape3D).radius * h_scale
		elif col_shape.shape is CylinderShape3D:
			return (col_shape.shape as CylinderShape3D).radius * h_scale
		elif col_shape.shape is SphereShape3D:
			return (col_shape.shape as SphereShape3D).radius * h_scale
		elif col_shape.shape is BoxShape3D:
			var box := col_shape.shape as BoxShape3D
			return maxf(box.size.x, box.size.z) * 0.5 * h_scale

	# 2. Si no hay colisión, buscar MeshInstance3D para calcular AABB
	var mesh_inst := target_node.find_child("*Mesh*", true, false) as MeshInstance3D
	if mesh_inst and mesh_inst.mesh:
		var aabb := mesh_inst.mesh.get_aabb()
		var global_scale := target_node.global_transform.basis.get_scale()
		var h_scale := maxf(absf(global_scale.x), absf(global_scale.z))
		return maxf(aabb.size.x, aabb.size.z) * 0.5 * h_scale

	return 0.45

## Calcula dinámicamente el rango efectivo de ataque considerando el radio físico y escala del objetivo.
## Esto previene que enemigos de gran tamaño (como jefes o dragones) bloqueen físicamente al atacante antes de entrar en rango.
func get_effective_attack_range(target_node: Node3D = null) -> float:
	var tgt := target_node if target_node != null else current_target
	var base_range: float = combat_config.attack_range if combat_config else 1.8
	if not is_instance_valid(tgt):
		return base_range

	var target_radius := get_target_bounding_radius(tgt)
	return base_range + target_radius

## Determina si el objetivo sigue con vida y activo para combate
static func is_target_alive(tgt: Node) -> bool:
	if not is_instance_valid(tgt) or tgt.is_queued_for_deletion():
		return false
	if tgt.has_method("is_alive") and not tgt.is_alive():
		return false
	if tgt.has_method("is_removable") and tgt.is_removable():
		return false
	var ct := tgt.get_node_or_null("CombatTarget") as CombatTarget
	if ct == null and tgt is CombatTarget:
		ct = tgt as CombatTarget
	if ct == null:
		for child in tgt.get_children():
			if child is CombatTarget:
				ct = child as CombatTarget
				break
	if ct:
		if ct.current_health <= 0.0:
			return false
		if ct.stats and ct.stats.current_hp <= 0:
			return false
		if ct.has_method("is_dead") and ct.is_dead():
			return false
	return true

func _connect_target(new_target: Node3D) -> void:
	_disconnect_target()
	current_target = new_target
	if is_instance_valid(new_target):
		_target_combat_target = new_target.get_node_or_null("CombatTarget") as CombatTarget
		if _target_combat_target and _target_combat_target.has_signal("died"):
			if not _target_combat_target.died.is_connected(_on_target_died):
				_target_combat_target.died.connect(_on_target_died)

func _disconnect_target() -> void:
	if is_instance_valid(_target_combat_target):
		if _target_combat_target.died.is_connected(_on_target_died):
			_target_combat_target.died.disconnect(_on_target_died)
	_target_combat_target = null

func _on_target_died() -> void:
	var next_target := _find_next_active_combatant()
	if next_target != null:
		select_target(next_target)
	else:
		clear_target()

## Busca el siguiente enemigo activo en combate con el jugador dentro del rango.
func _find_next_active_combatant(max_distance: float = 25.0) -> Node3D:
	var p := _get_parent_body()
	if p == null or not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null

	var candidates: Array[Node3D] = []
	var targetable_nodes := tree.get_nodes_in_group("targetable")
	var processed: Array[Node3D] = []

	for node in targetable_nodes:
		var entity: Node3D = null
		if node is CombatTarget:
			entity = node.get_parent() as Node3D
		elif node is Node3D:
			entity = node
		elif node.get_parent() is Node3D:
			entity = node.get_parent() as Node3D

		if entity == null or not is_instance_valid(entity) or entity == p or entity == current_target:
			continue
		if processed.has(entity):
			continue
		processed.append(entity)

		if not is_target_alive(entity):
			continue

		var dist := p.global_position.distance_to(entity.global_position)
		if dist <= max_distance and _is_hostile_to_player(entity, p):
			candidates.append(entity)

	if candidates.is_empty():
		return null

	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return p.global_position.distance_squared_to(a.global_position) < p.global_position.distance_squared_to(b.global_position)
	)

	return candidates[0]

## Selecciona un objetivo sin iniciar aproximación ni auto-ataque inmediato.
func select_target(new_target: Node3D) -> void:
	var p := _get_parent_body()
	if new_target == null or new_target == p or not is_target_alive(new_target):
		clear_target()
		return

	_connect_target(new_target)
	state = State.IDLE
	target_acquired.emit(current_target)

## Inicia aproximación y auto-ataque hacia el objetivo indicado o actual.
func attack_target(new_target: Node3D = null) -> void:
	var p := _get_parent_body()
	if new_target != null:
		if new_target == p or not is_target_alive(new_target):
			clear_target()
			return

	var target_to_attack: Node3D = new_target if new_target != null else current_target
	if not is_instance_valid(target_to_attack) or not is_target_alive(target_to_attack):
		clear_target()
		return

	# Si ya estamos enfocando a este mismo objetivo y el combate está activo:
	if current_target == target_to_attack and is_active():
		var dist_horiz := 999.0
		if p != null:
			dist_horiz = Vector2(
				current_target.global_position.x - p.global_position.x,
				current_target.global_position.z - p.global_position.z
			).length()
		var attack_range := get_effective_attack_range(current_target)

		# Si ya estamos en rango de ataque o en estado ATTACKING:
		# Ignorar clicks repetidos: no alterar estado, no reiniciar animación, no acercarse más al mob.
		if state == State.ATTACKING or dist_horiz <= attack_range:
			state = State.ATTACKING
			return

		# Si todavía estamos en aproximación hacia este mismo objetivo, continuar sin reiniciar
		if state == State.APPROACHING:
			return

	# Si es un nuevo objetivo diferente al actual:
	if new_target != null and new_target != current_target:
		_connect_target(new_target)

	if not is_instance_valid(current_target) or not is_target_alive(current_target):
		clear_target()
		return

	# Comprobar inmediatamente si ya estamos en rango de ataque antes de entrar en aproximación
	if p != null:
		var dist_horiz := Vector2(
			current_target.global_position.x - p.global_position.x,
			current_target.global_position.z - p.global_position.z
		).length()
		var attack_range := get_effective_attack_range(current_target)
		if dist_horiz <= attack_range:
			state = State.ATTACKING
			target_acquired.emit(current_target)
			return

	state = State.APPROACHING
	target_acquired.emit(current_target)

## Establece objetivo e inicia aproximación de combate (retrocompatibilidad).
func set_target(new_target: Node3D) -> void:
	attack_target(new_target)

## Selecciona el objetivo enemigo más cercano o cicla entre los disponibles dentro del rango (Tab targeting).
func cycle_target(max_distance: float = 30.0) -> Node3D:
	var p := _get_parent_body()
	if p == null or not is_inside_tree():
		return null

	var tree := get_tree()
	if tree == null:
		return null

	var candidates: Array[Node3D] = []
	var targetable_nodes := tree.get_nodes_in_group("targetable")
	var processed: Array[Node3D] = []

	for node in targetable_nodes:
		var entity: Node3D = null
		if node is CombatTarget:
			entity = node.get_parent() as Node3D
		elif node is Node3D:
			entity = node
		elif node.get_parent() is Node3D:
			entity = node.get_parent() as Node3D

		if entity == null or not is_instance_valid(entity) or entity == p:
			continue
		if processed.has(entity):
			continue
		processed.append(entity)

		if not is_target_alive(entity):
			continue

		var dist := p.global_position.distance_to(entity.global_position)
		if dist <= max_distance:
			candidates.append(entity)

	if candidates.is_empty():
		return null

	# Priorizar jefes primero, luego enemigos hostiles en combate con el jugador, y luego por cercanía horizontal
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var a_boss: bool = ("is_boss" in a and a.is_boss) or ("mIsBoss" in a and a.mIsBoss)
		var b_boss: bool = ("is_boss" in b and b.is_boss) or ("mIsBoss" in b and b.mIsBoss)
		if a_boss != b_boss:
			return a_boss

		var a_hostile := _is_hostile_to_player(a, p)
		var b_hostile := _is_hostile_to_player(b, p)
		if a_hostile != b_hostile:
			return a_hostile

		return p.global_position.distance_squared_to(a.global_position) < p.global_position.distance_squared_to(b.global_position)
	)

	var next_target: Node3D = null
	if current_target != null and candidates.has(current_target):
		var curr_idx := candidates.find(current_target)
		var next_idx := (curr_idx + 1) % candidates.size()
		next_target = candidates[next_idx]
	else:
		next_target = candidates[0]

	if next_target != null:
		select_target(next_target)

	return next_target

static func _is_hostile_to_player(entity: Node3D, player: Node3D) -> bool:
	if entity == null or player == null:
		return false
	if ("is_boss" in entity and entity.is_boss) or ("mIsBoss" in entity and entity.mIsBoss):
		return true
	if "mAggroTarget" in entity and entity.mAggroTarget == player:
		return true
	if "aggro_pool" in entity and entity.aggro_pool != null:
		if entity.aggro_pool.has_method("has_threat") and entity.aggro_pool.has_threat(player):
			return true
	var ct := entity.get_node_or_null("CombatTarget") as CombatTarget
	if ct != null:
		if ct.is_in_combat and (ct.last_attacker == player or ct.last_attacker == null):
			return true
		if ct.is_in_combat:
			return true
	return false

func clear_target() -> void:
	if current_target == null and state == State.IDLE:
		return
	_disconnect_target()
	var had_target := (current_target != null or state != State.IDLE)
	current_target = null
	state = State.IDLE
	_pending_impacts.clear()

	if had_target:
		target_lost.emit()

## Pausa la aproximación o el auto-ataque activo sin deseleccionar el objetivo actual (usado por movimiento WASD, Dash, Click-to-Move).
func pause_combat() -> void:
	state = State.IDLE
	_pending_impacts.clear()

func is_active() -> bool:
	return state != State.IDLE and is_instance_valid(current_target) and is_target_alive(current_target)

func is_approaching() -> bool:
	return state == State.APPROACHING and is_instance_valid(current_target) and is_target_alive(current_target)

func is_attacking() -> bool:
	return state == State.ATTACKING and is_instance_valid(current_target) and is_target_alive(current_target)

## Retorna el vector de dirección horizontal hacia el objetivo si está en aproximación.
func get_approach_direction() -> Vector3:
	var p := _get_parent_body()
	if not is_approaching() or p == null:
		return Vector3.ZERO

	var diff := current_target.global_position - p.global_position
	diff.y = 0.0
	return diff.normalized()

func update_combat(delta: float, visuals: PlayerVisuals) -> void:
	_time_since_last_attack += delta

	# Procesar impactos pendientes (tanto principales como ghost slashes)
	for i in range(_pending_impacts.size() - 1, -1, -1):
		_pending_impacts[i]["time_left"] -= delta
		if _pending_impacts[i]["time_left"] <= 0.0:
			var info: Dictionary = _pending_impacts[i]
			_pending_impacts.remove_at(i)
			var tgt: Node3D = info.get("target")
			if is_instance_valid(tgt) and is_target_alive(tgt):
				var hit_idx: int = int(info.get("hit_index", 0))
				var allow_td: bool = bool(info.get("allow_true_damage", true))
				var dmg_scale: float = float(info.get("damage_scale", 1.0))
				_apply_impact(tgt, hit_idx, allow_td, dmg_scale)

	# Si no hay combate activo o no hay objetivo, nada que procesar
	if state == State.IDLE or not is_instance_valid(current_target):
		return

	# Si el objetivo murió, detener combate inmediatamente
	if not is_target_alive(current_target):
		clear_target()
		return

	var p := _get_parent_body()
	if p == null:
		return

	var dist_horiz := Vector2(
		current_target.global_position.x - p.global_position.x,
		current_target.global_position.z - p.global_position.z
	).length()

	# Rango dinámico ajustado al tamaño físico del enemigo
	var attack_range := get_effective_attack_range(current_target)

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

			# Verificar si el atacante se encuentra aturdido (Stun)
			var status_ctrl: Node = null
			if _parent_body:
				status_ctrl = _parent_body.get_node_or_null("StatusEffectController")
			if status_ctrl and status_ctrl.has_method("is_stunned") and status_ctrl.is_stunned():
				return

			# Orientar al atacante hacia el objetivo durante el combate
			_face_target()

			# Chequear cadencia de ataque según attack_speed y ralentizaciones activas
			var attack_interval := get_current_attack_interval()
			var atk_speed := 1.0 / attack_interval
			if _time_since_last_attack >= attack_interval:
				# Si todavía se está reproduciendo activamente un ataque previo o de habilidad, no solapar
				if visuals and visuals.has_method("is_playing_attack") and visuals.is_playing_attack():
					return
				_time_since_last_attack = 0.0
				_execute_attack(visuals, atk_speed)

## Retorna el intervalo actual de ataque en segundos (1.0 / attacks_per_second), considerando stats y ralentizaciones.
func get_current_attack_interval() -> float:
	var status_ctrl: Node = null
	if _parent_body:
		status_ctrl = _parent_body.get_node_or_null("StatusEffectController")
	var atk_speed_mult: float = status_ctrl.get_attack_speed_multiplier() if (status_ctrl and status_ctrl.has_method("get_attack_speed_multiplier")) else 1.0
	var current_stats := get_stats()
	var base_atk_spd: float = current_stats.attack_speed if current_stats else 1.2
	var atk_speed: float = base_atk_spd * atk_speed_mult
	return 1.0 / maxf(0.05, atk_speed)

## Cancela cualquier impacto pendiente del auto-ataque (Windup Cancel) y resetea temporizadores (AA-Reset).
func cancel_pending_attack() -> void:
	_pending_impacts.clear()
	_time_since_last_attack = 0.0

## Reinicia el temporizador de cadencia del ataque básico (usado por habilidades o reinicios de ataque)
func reset_attack_timer() -> void:
	_time_since_last_attack = 0.0

## Prepara el auto-ataque para ejecutarse inmediatamente (apenas concluya cualquier animación de ataque en curso)
func ready_next_attack() -> void:
	_time_since_last_attack = maxf(_time_since_last_attack, get_current_attack_interval())

func _face_target() -> void:
	if _parent_body == null or not is_instance_valid(current_target):
		return
	var diff := current_target.global_position - _parent_body.global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		var target_yaw := atan2(-diff.x, -diff.z)
		_parent_body.rotation.y = target_yaw

func _execute_attack(visuals: PlayerVisuals, atk_speed: float = 1.0) -> void:
	var current_stats := get_stats()
	var speed_scale: float = 1.0
	if visuals:
		speed_scale = visuals.get_attack_speed_scale(atk_speed)

	if _can_broadcast_rpc():
		rpc("rpc_play_attack", speed_scale)
	else:
		rpc_play_attack(speed_scale)

	# El retardo del impacto principal se escala con la velocidad de la animación
	var base_delay: float = combat_config.impact_delay if combat_config else 0.58
	var real_delay: float = base_delay / speed_scale

	# Tiradas de Multi-Strike (Sección 6: Multi-Strike & Ghost Slashes)
	var num_hits: int = 1
	var triple_chance: float = current_stats.triple_strike_chance if current_stats else 0.0
	var double_chance: float = current_stats.double_strike_chance if current_stats else 0.0

	if randf() * 100.0 <= triple_chance:
		num_hits = 3
	elif randf() * 100.0 <= double_chance:
		num_hits = 2

	if num_hits > 1:
		multi_strike_triggered.emit(num_hits)

	# 1. Impacto Principal (Hit 0): frame clave de animación, Daño Verdadero permitido
	_pending_impacts.append({
		"target": current_target,
		"time_left": real_delay,
		"hit_index": 0,
		"allow_true_damage": true,
		"damage_scale": 1.0
	})

	var ghost_delay_1 := float(GameConfig.get_combat_value("multi_strike", "ghost_delay_1", 0.03))
	var ghost_delay_2 := float(GameConfig.get_combat_value("multi_strike", "ghost_delay_2", 0.12))
	var ghost_scale := float(GameConfig.get_combat_value("multi_strike", "ghost_damage_scale", 0.85))

	# 2. Impacto Secundario (Ghost 1): +0.03s, sin Daño Verdadero, escala de daño bonus
	if num_hits >= 2:
		_pending_impacts.append({
			"target": current_target,
			"time_left": real_delay + ghost_delay_1,
			"hit_index": 1,
			"allow_true_damage": false,
			"damage_scale": ghost_scale
		})
		if _can_broadcast_rpc():
			rpc("rpc_spawn_ghost_slash", speed_scale, 1)
		else:
			rpc_spawn_ghost_slash(speed_scale, 1)

	# 3. Impacto Terciario (Ghost 2): +0.12s, sin Daño Verdadero, escala de daño bonus
	if num_hits >= 3:
		_pending_impacts.append({
			"target": current_target,
			"time_left": real_delay + ghost_delay_2,
			"hit_index": 2,
			"allow_true_damage": false,
			"damage_scale": ghost_scale
		})
		if _can_broadcast_rpc():
			rpc("rpc_spawn_ghost_slash", speed_scale, 2)
		else:
			rpc_spawn_ghost_slash(speed_scale, 2)

## RPC sincronizado para que todos los clientes vean el clon fantasma del golpe adicional.
@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_ghost_slash(speed_scale: float = 1.0, hit_index: int = 1) -> void:
	if _parent_body == null:
		return
	var visuals := _parent_body.get_node_or_null("Visuals") as PlayerVisuals
	if visuals:
		visuals.spawn_ghost_slash(speed_scale, hit_index)


func _apply_impact(target: Node3D, hit_index: int = 0, allow_true_damage: bool = true, damage_scale: float = 1.0) -> void:
	if not is_instance_valid(target) or not is_target_alive(target):
		if target == current_target:
			clear_target()
		return

	var offset_y := float(GameConfig.get_combat_value("combat", "impact_height_offset", 1.1))
	var hit_pos := target.global_position + Vector3(0, offset_y, 0)

	# Ligera variación espacial para impactos secundarios para evitar que números flotantes se solapen
	if hit_index > 0:
		hit_pos += Vector3(randf_range(-0.18, 0.18), randf_range(-0.06, 0.12), randf_range(-0.18, 0.18))

	var target_path := target.get_path()
	var target_comp := _find_combat_target(target)
	var defender_stats: CharacterStats = target_comp.get_stats() if target_comp else null
	var attacker_stats: CharacterStats = get_stats()

	# Cada impacto realiza su propia tirada independiente de acierto
	if not CombatCalculator.try_to_hit(attacker_stats, defender_stats):
		var miss_res := DamageResult.new()
		miss_res.is_miss = true
		_broadcast_combat_result(hit_pos, target_path, miss_res)
		return

	# Resolución de daño mediante CombatCalculator
	var result := CombatCalculator.calculate_damage(attacker_stats, defender_stats, allow_true_damage, 0.0, -1)
	if damage_scale != 1.0:
		result.total_damage = maxi(1, int(round(float(result.total_damage) * damage_scale)))
		result.physical_damage = maxi(0, int(round(float(result.physical_damage) * damage_scale)))
		result.true_damage = maxi(0, int(round(float(result.true_damage) * damage_scale)))

	_broadcast_combat_result(hit_pos, target_path, result)


	# Si el objetivo murió a raíz de este impacto, detener el combate o transicionar al siguiente objetivo
	if not is_target_alive(target):
		if target == current_target:
			_on_target_died()

	# 7.6 Ondas Expansivas / Cleave en Área (AoE Cleave Waves)
	# Se ejecuta únicamente con el impacto principal (hit_index == 0) para evitar duplicación exponencial
	if hit_index == 0 and attacker_stats and attacker_stats.aoe_radius > 0.5 and attacker_stats.aoe_damage_percent > 0.0 and result.total_damage > 0:
		_apply_aoe_cleave(target, result, attacker_stats)

func _broadcast_combat_result(hit_pos: Vector3, target_path: NodePath, result: DamageResult) -> void:
	if _can_broadcast_rpc():
		rpc("rpc_apply_combat_impact", hit_pos, target_path, result.total_damage, result.physical_damage, result.true_damage, result.is_crit, result.is_blocked, result.is_miss)
	else:
		rpc_apply_combat_impact(hit_pos, target_path, result.total_damage, result.physical_damage, result.true_damage, result.is_crit, result.is_blocked, result.is_miss)

## RPC sincronizado para que todos los clientes reproduzcan la animación del golpe con su escala de velocidad.
@rpc("any_peer", "call_local", "reliable")
func rpc_play_attack(speed_scale: float = 1.0) -> void:
	var p := _get_parent_body()
	if p == null:
		return
	var visuals := p.get_node_or_null("Visuals") as PlayerVisuals
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

		# Si el impacto provocó la muerte del objetivo, detener inmediatamente el combate o transicionar
		if not is_target_alive(target_node):
			if target_node == current_target:
				_on_target_died()

## RPC legacy para compatibilidad con código que invoque daño plano.
@rpc("any_peer", "call_local", "reliable")
func rpc_apply_impact(hit_pos: Vector3, target_path: NodePath, dmg: float) -> void:
	rpc_apply_combat_impact(hit_pos, target_path, int(round(dmg)), int(round(dmg)), 0, false, false, false)

func _can_broadcast_rpc() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _find_combat_target(node: Node) -> CombatTarget:
	if node == null:
		return null
	if node is CombatTarget:
		return node
	if node.has_node("CombatTarget"):
		var ct := node.get_node_or_null("CombatTarget") as CombatTarget
		if ct:
			return ct
	for child in node.get_children():
		if child is CombatTarget:
			return child
	return null

## Aplica onda expansiva de daño (Cleave) a enemigos cercanos al objetivo primario.
func _apply_aoe_cleave(primary_target: Node3D, primary_result: DamageResult, attacker_stats: CharacterStats) -> void:
	if primary_target == null:
		return

	var tree := get_tree()
	if tree == null and primary_target.is_inside_tree():
		tree = primary_target.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var center := primary_target.global_position if primary_target.is_inside_tree() else primary_target.position
	var aoe_radius := attacker_stats.aoe_radius
	var aoe_pct := attacker_stats.aoe_damage_percent / 100.0
	var offset_y := float(GameConfig.get_combat_value("combat", "impact_height_offset", 1.1))

	var raw_cleave_damage := float(primary_result.total_damage) * aoe_pct
	if raw_cleave_damage <= 0.0:
		return

	var targetable_nodes := tree.get_nodes_in_group("targetable")
	var processed_targets: Array[CombatTarget] = []

	# Excluir el objetivo principal
	var primary_comp := _find_combat_target(primary_target)
	if primary_comp:
		processed_targets.append(primary_comp)

	for candidate in targetable_nodes:
		if candidate == primary_target or candidate == _parent_body:
			continue

		var cand_target := _find_combat_target(candidate)
		if cand_target == null or cand_target in processed_targets:
			continue

		# Obtener la posición espacial del objetivo secundario
		var cand_spatial: Node3D = null
		if candidate is Node3D:
			cand_spatial = candidate
		elif cand_target.get_parent() is Node3D:
			cand_spatial = cand_target.get_parent() as Node3D

		if cand_spatial == null:
			continue

		if cand_spatial == _parent_body:
			continue

		var cand_pos := cand_spatial.global_position if cand_spatial.is_inside_tree() else cand_spatial.position
		var dist := cand_pos.distance_to(center)
		if dist <= aoe_radius:
			processed_targets.append(cand_target)

			var sec_stats := cand_target.get_stats()
			var cleave_res := CombatCalculator.calculate_mitigated_damage(
				attacker_stats,
				sec_stats,
				raw_cleave_damage,
				true,
				false,
				false
			)

			var sec_hit_pos := cand_pos + Vector3(0, offset_y, 0)
			_broadcast_combat_result(sec_hit_pos, cand_spatial.get_path(), cleave_res)


