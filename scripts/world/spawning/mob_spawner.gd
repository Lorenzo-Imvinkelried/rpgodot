class_name MobSpawner
extends Node3D

## Responsabilidad: Gestión de Spawns de mapa, Object Pooling (cero alocaciones en caliente),
## sistema de Respawn con tickets, jitter y throttling por fotograma, y Logic Culling con histeresis.

class RespawnTicket extends RefCounted:
	var blueprint_name: String = ""
	var spawn_pos: Vector3 = Vector3.ZERO
	var time_remaining: float = 0.0
	var level: int = -1
	var is_boss: bool = false

@export var mobs_config_path: String = "res://config/gameplay/mobs.json"
@export var level_spawns_path: String = "res://config/gameplay/level_spawns.json"
@export var mob_scene: PackedScene = preload("res://scenes/enemies/mob_goblin.tscn")

@export var base_respawn_time: float = 8.0
@export var respawn_jitter: float = 3.0
@export var max_respawns_per_frame: int = 5

# Distancias de Histeresis para Logic Culling (Sección 5.2)
const WAKE_RADIUS: float = 65.0
const SLEEP_RADIUS: float = 85.0

const MobScript = preload("res://scripts/gameplay/enemies/mob.gd")

const DEFAULT_SCENES: Dictionary = {
	"goblin": preload("res://scenes/enemies/mob_goblin.tscn"),
	"wolf": preload("res://scenes/enemies/mob_wolf.tscn"),
	"dragon_boss": preload("res://scenes/enemies/mob_dragon_boss.tscn")
}

# Almacenes de Object Pooling y Entidades Activas
var _blueprints: Dictionary = {} # type -> MobBlueprint
var _active_mobs: Array[CharacterBody3D] = []
var _mob_pool: Dictionary = {} # type -> Array[CharacterBody3D]
var _respawn_tickets: Array[RespawnTicket] = []

var _culling_check_timer: float = 0.0
const CULLING_CHECK_INTERVAL: float = 0.25 # Evaluación escalonada cada 250ms

func _ready() -> void:
	_load_blueprints()
	_load_initial_spawns()

func _load_blueprints() -> void:
	_blueprints = MobBlueprint.load_all_blueprints(mobs_config_path)

func _load_initial_spawns() -> void:
	var spawns_data = GameConfig.load_json_data(level_spawns_path)
	if spawns_data is Array:
		for spawn_entry in spawns_data:
			if spawn_entry is Dictionary:
				spawn_mob_from_entry(spawn_entry)

## Genera un mob en el mundo a partir de un descriptor de spawn
func spawn_mob_from_entry(entry: Dictionary) -> CharacterBody3D:
	var bp_type: String = str(entry.get("type", "goblin"))
	var pos_raw = entry.get("pos", [0.0, 0.0, 0.0])
	var spawn_pos := Vector3.ZERO
	if pos_raw is Array and pos_raw.size() >= 3:
		spawn_pos = Vector3(float(pos_raw[0]), float(pos_raw[1]), float(pos_raw[2]))

	var lvl: int = int(entry.get("level", -1))
	var boss: bool = bool(entry.get("isBoss", false))
	var stance_str: String = str(entry.get("stance", ""))

	var mob := spawn_mob(bp_type, spawn_pos, lvl, boss, false)
	if mob and stance_str != "" and "mStance" in mob:
		mob.mStance = MobBlueprint.stance_from_string(stance_str)
	return mob

## Genera o recicla un Mob del Object Pool (Sección 5.1)
func spawn_mob(bp_type: String, pos: Vector3, level: int = -1, is_boss: bool = false, fade_in: bool = true) -> CharacterBody3D:
	var mob: CharacterBody3D = null

	# 1. Buscar en el Object Pool reciclable
	if _mob_pool.has(bp_type) and not _mob_pool[bp_type].is_empty():
		mob = _mob_pool[bp_type].pop_back()
		mob.is_boss = is_boss
		mob.reset(pos, fade_in, level)
	else:
		# 2. Instanciación fresca si no hay instancias en el pool
		var selected_scene: PackedScene = DEFAULT_SCENES.get(bp_type, mob_scene)
		if selected_scene != null:
			mob = selected_scene.instantiate() as CharacterBody3D
		elif mob_scene != null:
			mob = mob_scene.instantiate() as CharacterBody3D
		else:
			mob = MobScript.new() as CharacterBody3D

		mob.blueprint_type = bp_type
		mob.level_override = level
		mob.is_boss = is_boss
		mob.mSpawnPoint = pos
		mob.position = pos

		add_child(mob)

		var bp: MobBlueprint = _blueprints.get(bp_type, null)
		if bp:
			mob.init_from_blueprint(bp, level, is_boss)

		if fade_in:
			mob.reset(pos, true, level)

		mob.mob_died.connect(_on_mob_died)

	if mob and not _active_mobs.has(mob):
		_active_mobs.append(mob)

	return mob

func _process(delta: float) -> void:
	_process_respawn_tickets(delta)
	_cleanup_removable_mobs()
	_process_logic_culling(delta)

## Procesa los tickets de respawn con jitter y throttling por frame (Sección 4)
func _process_respawn_tickets(delta: float) -> void:
	var spawned_count: int = 0
	var i: int = _respawn_tickets.size() - 1

	while i >= 0:
		var ticket: RespawnTicket = _respawn_tickets[i]
		ticket.time_remaining -= delta

		if ticket.time_remaining <= 0.0:
			if spawned_count < max_respawns_per_frame:
				spawn_mob(ticket.blueprint_name, ticket.spawn_pos, ticket.level, ticket.is_boss, true)
				_respawn_tickets.remove_at(i)
				spawned_count += 1
		i -= 1

## Mueve los mobs muertos y desvanecidos al Object Pool en vez de destruirlos (Sección 5.1)
func _cleanup_removable_mobs() -> void:
	for i in range(_active_mobs.size() - 1, -1, -1):
		var mob: CharacterBody3D = _active_mobs[i]
		if mob.has_method("is_removable") and mob.is_removable():
			_active_mobs.remove_at(i)
			_recycle_mob(mob)

func _recycle_mob(mob: CharacterBody3D) -> void:
	mob.hide()
	mob.set_process(false)
	mob.set_physics_process(false)
	if "collision_shape" in mob and mob.collision_shape:
		mob.collision_shape.disabled = true

	var bp_type: String = mob.get("mBlueprintName") if ("mBlueprintName" in mob) else ""
	if not _mob_pool.has(bp_type):
		_mob_pool[bp_type] = []
	_mob_pool[bp_type].append(mob)

## Agenda un ticket de reaparición con jitter (Sección 4)
func _on_mob_died(mob: CharacterBody3D, _killer: Node) -> void:
	var ticket := RespawnTicket.new()
	ticket.blueprint_name = mob.get("mBlueprintName") if ("mBlueprintName" in mob) else ""
	ticket.spawn_pos = mob.get("mSpawnPoint") if ("mSpawnPoint" in mob) else mob.global_position
	ticket.level = mob.get("level_override") if ("level_override" in mob) else -1
	ticket.is_boss = mob.get("is_boss") if ("is_boss" in mob) else false

	# Algoritmo de Jitter: T_base + RandomFloat(-Jitter, +Jitter), mínimo 1.0s (Sección 4.2)
	var jitter_offset := randf_range(-respawn_jitter, respawn_jitter)
	ticket.time_remaining = maxf(1.0, base_respawn_time + jitter_offset)

	_respawn_tickets.append(ticket)

## Logic Culling con histeresis para optimización de miles de entidades (Sección 5.2)
func _process_logic_culling(delta: float) -> void:
	_culling_check_timer += delta
	if _culling_check_timer < CULLING_CHECK_INTERVAL:
		return
	_culling_check_timer = 0.0

	var player_pos := _get_reference_player_position()
	if player_pos == Vector3.INF:
		return

	for mob in _active_mobs:
		# REGLA DE ORO / BYPASS: Si está en combate o retornando al spawn, NUNCA suspender (Sección 5.2.2)
		if mob.is_aggro() or mob.is_returning_to_spawn() or not mob.is_alive():
			if not mob.is_processing():
				mob.set_process(true)
				mob.set_physics_process(true)
			continue

		var dist := mob.global_position.distance_to(player_pos)

		if dist > SLEEP_RADIUS:
			# Fuera del rango de desactivación: Entra en reposo (Sleep)
			if mob.is_processing():
				mob.set_process(false)
				mob.set_physics_process(false)
		elif dist < WAKE_RADIUS:
			# Dentro del rango de activación: Se despierta (Wake)
			if not mob.is_processing():
				mob.set_process(true)
				mob.set_physics_process(true)

func _get_reference_player_position() -> Vector3:
	var tree := get_tree()
	if tree == null:
		return Vector3.INF
	var players := tree.root.find_child("Players", true, false)
	if players and players.get_child_count() > 0:
		var p = players.get_child(0) as Node3D
		if p:
			return p.global_position
	return Vector3.INF

func get_active_mob_count() -> int:
	return _active_mobs.size()

func get_pooled_mob_count(bp_type: String = "") -> int:
	if bp_type != "":
		return _mob_pool.get(bp_type, []).size()
	var total: int = 0
	for list in _mob_pool.values():
		total += list.size()
	return total

func get_pending_respawns_count() -> int:
	return _respawn_tickets.size()
