class_name CombatTarget
extends Node

## Responsabilidad: Identifica a una entidad como objetivo atacable y gestiona la recepción de impactos y estadísticas.
## Puede adjuntarse a personajes, muñecos de práctica o enemigos.

signal hit_received(damage: float, hit_position: Vector3, attacker: Node)
signal miss_received(hit_position: Vector3, attacker: Node)
signal health_changed(current_health: float, max_health: float)
signal died()

const DAMAGE_NUMBER_FX_SCENE = preload("res://scenes/combat/damage_number_fx.tscn")

@export var target_name: String = "Objetivo"
@export var max_health: float = 100.0
@export var spawn_damage_numbers: bool = true
@export var stats: CharacterStats = null

var current_health: float = 100.0

func _enter_tree() -> void:
	_init_stats()

func _ready() -> void:
	_init_stats()
	add_to_group("targetable")

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

## Procesa un resultado de combate (DamageResult) calculado por CombatCalculator.
func take_combat_result(result: DamageResult, hit_position: Vector3, attacker: Node) -> void:
	if result == null:
		return

	if result.is_miss:
		miss_received.emit(hit_position, attacker)
		if spawn_damage_numbers:
			_spawn_damage_number(0.0, hit_position, false, false, true)
		return

	var dmg := float(result.total_damage)
	var prev_hp := current_health
	current_health = maxf(0.0, current_health - dmg)
	if stats:
		stats.apply_damage(result.total_damage)

	hit_received.emit(dmg, hit_position, attacker)
	health_changed.emit(current_health, max_health)

	if spawn_damage_numbers and dmg > 0.0:
		_spawn_damage_number(dmg, hit_position, result.is_crit, result.is_blocked, false)

	if prev_hp > 0.0 and current_health <= 0.0:
		died.emit()

## Registra un impacto plano recibido (mantenido por compatibilidad).
func take_hit(damage: float, hit_position: Vector3, attacker: Node) -> void:
	var res := DamageResult.new()
	res.total_damage = int(round(damage))
	res.physical_damage = res.total_damage
	take_combat_result(res, hit_position, attacker)

## Restaura la salud al valor máximo y notifica el cambio.
func reset_health() -> void:
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
	current_health = minf(max_health, current_health + amount)
	if stats:
		stats.heal(int(round(amount)))
	health_changed.emit(current_health, max_health)

func _spawn_damage_number(damage: float, hit_position: Vector3, is_crit: bool = false, is_blocked: bool = false, is_miss: bool = false) -> void:
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
		fx.setup(damage, is_crit, is_blocked, is_miss)
