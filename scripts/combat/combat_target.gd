class_name CombatTarget
extends Node

## Responsabilidad: Identifica a una entidad como objetivo atacable y gestiona la recepción de impactos.
## Puede adjuntarse a personajes, muñecos de práctica o enemigos.

signal hit_received(damage: float, hit_position: Vector3, attacker: Node)
signal health_changed(current_health: float, max_health: float)
signal died()

const DAMAGE_NUMBER_FX_SCENE = preload("res://scenes/combat/damage_number_fx.tscn")

@export var target_name: String = "Objetivo"
@export var max_health: float = 100.0
@export var spawn_damage_numbers: bool = true

var current_health: float = 100.0

func _enter_tree() -> void:
	if target_name == "Player" or target_name == "Objetivo":
		max_health = float(GameConfig.get_combat_value("targets", "player_max_health", max_health))
	current_health = max_health

func _ready() -> void:
	current_health = max_health
	add_to_group("targetable")

## Registra un impacto recibido, emite señales y genera feedback de combate (números flotantes).
func take_hit(damage: float, hit_position: Vector3, attacker: Node) -> void:
	var prev_hp := current_health
	current_health = maxf(0.0, current_health - damage)
	hit_received.emit(damage, hit_position, attacker)
	health_changed.emit(current_health, max_health)

	if spawn_damage_numbers and damage > 0.0:
		_spawn_damage_number(damage, hit_position)

	if prev_hp > 0.0 and current_health <= 0.0:
		died.emit()

## Restaura la salud al valor máximo y notifica el cambio.
func reset_health() -> void:
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
	health_changed.emit(current_health, max_health)

const DamageNumberFXScript = preload("res://scripts/combat/damage_number_fx.gd")

func _spawn_damage_number(damage: float, hit_position: Vector3) -> void:
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
		var crit_thresh := float(GameConfig.get_combat_value("targets", "crit_damage_threshold", 30.0))
		var is_crit := damage >= crit_thresh
		fx.setup(damage, is_crit)
