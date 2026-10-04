class_name CombatTarget
extends Node

## Responsabilidad: Identifica a una entidad como objetivo atacable y gestiona la recepción de impactos y estadísticas.
## Puede adjuntarse a personajes, muñecos de práctica o enemigos.

signal hit_received(damage: float, hit_position: Vector3, attacker: Node)
signal miss_received(hit_position: Vector3, attacker: Node)
signal health_changed(current_health: float, max_health: float)
signal died()
signal invulnerability_started(duration: float)
signal invulnerability_ended()
signal guard_changed(is_guarding: bool)
signal combat_entered(instigator: Node)
signal combat_exited()
signal combat_state_changed(in_combat: bool)

const DAMAGE_NUMBER_FX_SCENE = preload("res://scenes/combat/damage_number_fx.tscn")
const StatusEffectControllerScript = preload("res://scripts/combat/status_effect_controller.gd")

@export var target_name: String = "Objetivo"
@export var max_health: float = 100.0
@export var spawn_damage_numbers: bool = true
@export var combat_timeout: float = 5.0
@export var stats: CharacterStats = null:
	set(val):
		stats = val
		if stats != null:
			max_health = float(stats.max_hp)
			current_health = float(stats.current_hp)

var current_health: float = 100.0
var last_attacker: Node = null

# --- Estado de Combate (In-Combat / Out-of-Combat) ---
var is_in_combat: bool = false
var combat_timer: float = 0.0

# --- Mecánicas Defensivas Activas (I-Frames / Guardia) ---
var is_invulnerable: bool = false
var _invulnerability_timer: float = 0.0

@export var is_guarding: bool = false:
	set = set_guarding

func set_guarding(val: bool) -> void:
	if is_guarding == val:
		return
	is_guarding = val
	var bonus_block: float = float(GameConfig.get_combat_value("defense_mechanics", "guard_block_bonus", 40.0))
	var bonus_val: float = float(GameConfig.get_combat_value("defense_mechanics", "guard_block_value_bonus", 25.0))
	if stats != null:
		if is_guarding:
			stats.block_chance += bonus_block
			stats.block_value_percent += bonus_val
		else:
			stats.block_chance = maxf(0.0, stats.block_chance - bonus_block)
			stats.block_value_percent = maxf(0.0, stats.block_value_percent - bonus_val)
	guard_changed.emit(is_guarding)

func trigger_invulnerability(duration: float = 0.20) -> void:
	is_invulnerable = true
	_invulnerability_timer = duration
	invulnerability_started.emit(duration)

## Activa o renueva el estado en combate ante una acción hostil
func enter_combat(instigator: Node = null) -> void:
	combat_timer = combat_timeout
	if not is_in_combat:
		is_in_combat = true
		combat_entered.emit(instigator)
		combat_state_changed.emit(true)

## Finaliza el estado en combate tras expirar el temporizador o al morir
func exit_combat() -> void:
	if is_in_combat:
		is_in_combat = false
		combat_timer = 0.0
		combat_exited.emit()
		combat_state_changed.emit(false)

## Refresca la duración del estado en combate
func refresh_combat(duration: float = -1.0) -> void:
	combat_timer = combat_timeout if duration <= 0.0 else duration
	if not is_in_combat:
		enter_combat()

func _process(delta: float) -> void:
	if _invulnerability_timer > 0.0:
		_invulnerability_timer -= delta
		if _invulnerability_timer <= 0.0:
			_invulnerability_timer = 0.0
			is_invulnerable = false
			invulnerability_ended.emit()

	if is_in_combat:
		combat_timer -= delta
		if combat_timer <= 0.0:
			exit_combat()

func _enter_tree() -> void:
	_init_stats()

func _ready() -> void:
	_init_stats()
	add_to_group("targetable")
	_get_status_controller()

func _init_stats() -> void:
	if stats != null:
		max_health = float(stats.max_hp)
		current_health = float(stats.current_hp)
		return

	if target_name == "Player":
		stats = CharacterStats.create_player_default()
	elif target_name.findn("dummy") != -1 or target_name.findn("muñeco") != -1:
		stats = CharacterStats.create_dummy_default()
	else:
		stats = CharacterStats.create_from_config("dummy_default_stats", target_name)

	max_health = float(stats.max_hp)
	current_health = float(stats.current_hp)

func get_stats() -> CharacterStats:
	if stats == null:
		_init_stats()
	return stats

## Actualiza y recalcula las estadísticas desde un diccionario serializado recibido por red.
func update_stats_from_dict(dict: Dictionary) -> void:
	if stats == null:
		_init_stats()
	stats.load_from_dictionary(dict)
	max_health = float(stats.max_hp)
	if dict.has("current_health"):
		current_health = float(dict["current_health"])
	else:
		current_health = float(stats.current_hp)
	health_changed.emit(current_health, max_health)

## Procesa un resultado de combate (DamageResult) calculado por CombatCalculator.
func take_combat_result(result: DamageResult, hit_position: Vector3, attacker: Node) -> void:
	if attacker:
		last_attacker = attacker

	if result == null:
		return

	# 8.1 I-Frames durante Esquiva / Dash
	if is_invulnerable:
		if spawn_damage_numbers:
			_spawn_damage_number(0.0, hit_position, false, false, false, false, false, false, "ESQUIVADO")
		return

	if result.is_miss:
		miss_received.emit(hit_position, attacker)
		if spawn_damage_numbers:
			_spawn_damage_number(0.0, hit_position, false, false, true)
		return

	var dmg := float(result.total_damage)
	var prev_hp := current_health
	if stats:
		stats.apply_damage(result.total_damage)
		current_health = float(stats.current_hp)
	else:
		current_health = maxf(0.0, current_health - dmg)

	hit_received.emit(dmg, hit_position, attacker)
	health_changed.emit(current_health, max_health)

	enter_combat(attacker)
	if attacker != null:
		var atk_tgt := _find_combat_target(attacker)
		if atk_tgt:
			atk_tgt.enter_combat(get_parent())

	if spawn_damage_numbers and dmg > 0.0:
		_spawn_damage_number(dmg, hit_position, result.is_crit, result.is_blocked, false, false, result.is_thorns, result.is_bleed)

	# 7.1 Robo de Vida y Maná (Lifesteal & Mana Steal)
	if attacker and dmg > 0.0 and not result.is_thorns and not result.is_bleed:
		var attacker_target := _find_combat_target(attacker)
		if attacker_target:
			var atk_stats := attacker_target.get_stats()
			var heal_amount := CombatCalculator.calculate_lifesteal(atk_stats, result.total_damage)
			if heal_amount > 0:
				attacker_target.heal(float(heal_amount))
				var atk_pos := (attacker as Node3D).global_position if (attacker is Node3D and (attacker as Node3D).is_inside_tree()) else hit_position
				attacker_target._spawn_damage_number(float(heal_amount), atk_pos + Vector3(0, 1.2, 0), false, false, false, true)
			var mana_amount := CombatCalculator.calculate_mana_steal(atk_stats, result.total_damage)
			if mana_amount > 0 and atk_stats:
				atk_stats.restore_mana(mana_amount)

	# 7.2 Espinas (Thorns)
	if stats and stats.thorns_percent > 0.0 and dmg > 0.0 and not result.is_thorns and attacker:
		var attacker_target := _find_combat_target(attacker)
		if attacker_target:
			var atk_stats := attacker_target.get_stats()
			var is_pure_true := (result.true_damage >= result.total_damage and result.physical_damage == 0)
			var thorns_res := CombatCalculator.calculate_thorns_damage(stats, atk_stats, result.total_damage, is_pure_true)
			if thorns_res and thorns_res.total_damage > 0:
				var atk_pos := (attacker as Node3D).global_position if (attacker is Node3D and (attacker as Node3D).is_inside_tree()) else hit_position
				attacker_target.take_combat_result(thorns_res, atk_pos + Vector3(0, 1.0, 0), get_parent())

	# 7.3 Aturdimiento y Tenacidad (Stun & Tenacity)
	if attacker and dmg > 0.0 and not result.is_thorns and not result.is_bleed:
		var attacker_target := _find_combat_target(attacker)
		if attacker_target:
			var atk_stats := attacker_target.get_stats()
			var stun_dur := CombatCalculator.calculate_stun_duration(atk_stats, stats)
			if stun_dur > 0.0:
				var status_ctrl := _get_status_controller()
				if status_ctrl:
					status_ctrl.apply_stun(stun_dur)
					if spawn_damage_numbers:
						_spawn_damage_number(0.0, hit_position, false, false, false, false, false, false, "¡ATURDIDO!")

	# 7.4 Sangrado Continuo (Bleed sin Snapshotting)
	if attacker and dmg > 0.0 and not result.is_thorns and not result.is_bleed:
		var attacker_target := _find_combat_target(attacker)
		if attacker_target:
			var atk_stats := attacker_target.get_stats()
			if atk_stats.bleed_chance > 0.0 and (randf() * 100.0 <= atk_stats.bleed_chance):
				var status_ctrl := _get_status_controller()
				if status_ctrl:
					status_ctrl.apply_bleed(atk_stats, atk_stats.bleed_duration, atk_stats.bleed_flat, atk_stats.bleed_percent, attacker)
					if spawn_damage_numbers:
						_spawn_damage_number(0.0, hit_position, false, false, false, false, false, false, "SANGRADO 🩸")

	# 7.5 Ralentización (Slow)
	if attacker and dmg > 0.0 and not result.is_thorns and not result.is_bleed:
		var attacker_target := _find_combat_target(attacker)
		if attacker_target:
			var atk_stats := attacker_target.get_stats()
			if atk_stats.slow_chance > 0.0 and (randf() * 100.0 <= atk_stats.slow_chance):
				var status_ctrl := _get_status_controller()
				if status_ctrl:
					status_ctrl.apply_slow(atk_stats.slow_move_percent, atk_stats.slow_attack_percent, atk_stats.slow_duration)
					if spawn_damage_numbers:
						_spawn_damage_number(0.0, hit_position, false, false, false, false, false, false, "RALENTIZADO ❄")

	if prev_hp > 0.0 and current_health <= 0.0:
		died.emit()
		exit_combat()

## Registra un impacto plano recibido (mantenido por compatibilidad).
func take_hit(damage: float, hit_position: Vector3, attacker: Node) -> void:
	if attacker:
		last_attacker = attacker
	var res := DamageResult.new()
	res.total_damage = int(round(damage))
	res.physical_damage = res.total_damage
	take_combat_result(res, hit_position, attacker)

## Restaura la salud al valor máximo y notifica el cambio.
func reset_health() -> void:
	exit_combat()
	if stats:
		stats.recalculate_stats(true)
		max_health = float(stats.max_hp)
		current_health = float(stats.current_hp)
	else:
		current_health = max_health
	health_changed.emit(current_health, max_health)

## Sincroniza la restauración de salud en toda la red si hay multijugador activo.
func sync_reset_health() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc("rpc_reset_health")
	else:
		reset_health()

@rpc("any_peer", "call_local", "reliable")
func rpc_reset_health() -> void:
	reset_health()

## Incrementa la salud en una cantidad fija sin superar el valor máximo.
func heal(amount: float) -> void:
	if stats:
		stats.heal(int(round(amount)))
		current_health = float(stats.current_hp)
	else:
		current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	_broadcast_health_if_network()

func _broadcast_health_if_network() -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var p := get_parent()
		if p is CharacterBody3D and (p as CharacterBody3D).is_multiplayer_authority():
			rpc("rpc_sync_health", current_health, max_health)

@rpc("any_peer", "call_remote", "reliable")
func rpc_sync_health(curr: float, max_h: float) -> void:
	current_health = curr
	max_health = max_h
	if stats:
		stats.current_hp = int(round(curr))
		stats.max_hp = int(round(max_h))
	health_changed.emit(current_health, max_health)

func _spawn_damage_number(
	damage: float,
	hit_position: Vector3,
	is_crit: bool = false,
	is_blocked: bool = false,
	is_miss: bool = false,
	is_heal: bool = false,
	is_thorns: bool = false,
	is_bleed: bool = false,
	custom_text: String = ""
) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return

	var spawn_pos := hit_position
	if spawn_pos == Vector3.ZERO:
		var parent_3d := get_parent() as Node3D
		if parent_3d:
			spawn_pos = parent_3d.global_position + Vector3(0.0, 1.2, 0.0)

	var fx := DAMAGE_NUMBER_FX_SCENE.instantiate()
	tree.root.add_child(fx)
	if fx is Node3D:
		fx.global_position = spawn_pos + Vector3(0.0, 0.35, 0.0)
	if fx.has_method("setup"):
		fx.setup(damage, is_crit, is_blocked, is_miss, is_heal, is_thorns, is_bleed, custom_text)

func _find_combat_target(node: Node) -> CombatTarget:
	if node == null:
		return null
	var tgt := node.get_node_or_null("CombatTarget") as CombatTarget
	if tgt:
		return tgt
	for child in node.get_children():
		if child is CombatTarget:
			return child
	return null

func _get_status_controller() -> Node:
	var p := get_parent()
	if p == null:
		return null
	var ctrl := p.get_node_or_null("StatusEffectController")
	if ctrl:
		return ctrl
	for child in p.get_children():
		if child is StatusEffectControllerScript:
			return child
	# Creación automática bajo demanda para máxima resiliencia
	ctrl = StatusEffectControllerScript.new()
	ctrl.name = "StatusEffectController"
	if p.is_node_ready():
		p.add_child(ctrl)
	else:
		p.add_child.call_deferred(ctrl)
	return ctrl
