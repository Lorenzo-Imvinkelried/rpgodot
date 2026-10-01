class_name Mob
extends CharacterBody3D

## Responsabilidad: Entidad 3D de enemigo (Mob/NPC) con FSM determinista,
## Leash estricto por distancia al cuadrado, inmunidad de retorno,
## separación anti-apilamiento (Boids), agro social y soporte para Object Pooling.

enum State {
	SPAWNING,  # Fade-in inicial, invulnerable
	IDLE,      # Reposo orgánico con temporizador aleatorio
	WALKING,   # Desplazamiento activo (patrulla, persecución, retorno)
	ATTACKING, # Ejecución de ataque con retraso de impacto (Hit Delay Factor)
	DEAD,      # Vida <= 0, desvinculación de agro y entrega de XP
	FADING,    # Desvanecimiento visual tras la muerte
	REMOVABLE  # Listo para reciclaje en MobPool y programación de RespawnTicket
}

enum AiDecision {
	IDLE,       # Sin acción táctica
	PATROLLING, # Patrulla orgánica polar respecto a SpawnPoint
	CHASING,    # Persecución activa del objetivo
	RETURNING   # Ruptura obligatoria por Leash y regreso veloz a SpawnPoint
}

signal mob_died(mob: Mob, killer: Node)
signal state_changed(old_state: State, new_state: State)
signal decision_changed(old_dec: AiDecision, new_dec: AiDecision)

const CombatCalculatorScript = preload("res://scripts/combat/combat_calculator.gd")
const HealthBar3DScene = preload("res://scenes/combat/health_bar_3d.tscn")

@export var blueprint_type: String = "goblin"
@export var level_override: int = -1
@export var is_boss: bool = false

@onready var combat_target: CombatTarget = get_node_or_null("CombatTarget")
@onready var health_bar: HealthBar3D = get_node_or_null("HealthBar3D")
@onready var status_controller: StatusEffectController = get_node_or_null("StatusEffectController")
@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

var mBlueprint: MobBlueprint = null
var mBlueprintName: String = ""
var mSpawnPoint: Vector3 = Vector3.ZERO
var mPatrolTarget: Vector3 = Vector3.ZERO
var mMoveDir: Vector3 = Vector3.ZERO

var mCurrentState: State = State.IDLE
var mAiDecision: AiDecision = AiDecision.IDLE
var mStance: MobBlueprint.Stance = MobBlueprint.Stance.NEUTRAL
var mIsBoss: bool = false
var mAggroTarget: Node3D = null

# Temporizadores y contadores internos
var _idle_timer: float = 0.0
var _fade_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _hit_delay_timer: float = 0.0
var _is_damage_pending: bool = false
var _pending_target: Node3D = null
var _spawn_fade_timer: float = 0.0
var _is_spawning_fade: bool = false

# Parámetros de ajuste de comportamiento
const PATROL_RADIUS: float = 5.0 # Radio polar de patrulla en metros
const ARRIVAL_THRESHOLD: float = 0.45 # Distancia para considerar destino alcanzado
const SEPARATION_RADIUS: float = 1.4 # Radio de repulsión entre mobs (Boids)
const SEPARATION_FORCE: float = 2.5 # Fuerza elástica de empuje anti-apilamiento
const FADE_OUT_DURATION: float = 1.5 # Duración del desvanecimiento post-muerte
const FADE_IN_DURATION: float = 1.0 # Duración de activación inicial

var _visual_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("targetable")
	_init_components()
	if mSpawnPoint == Vector3.ZERO:
		mSpawnPoint = global_position
	if mBlueprint == null:
		var all_bp := MobBlueprint.load_all_blueprints()
		if all_bp.has(blueprint_type):
			init_from_blueprint(all_bp[blueprint_type], level_override, is_boss)
		else:
			push_warning("Mob: Blueprint '%s' no encontrado. Creando contingencia." % blueprint_type)
			var fallback_bp := MobBlueprint.new()
			fallback_bp.type = blueprint_type
			fallback_bp.name = blueprint_type.capitalize()
			init_from_blueprint(fallback_bp, level_override, is_boss)
	_reset_idle_timer()

func _init_components() -> void:
	if combat_target == null:
		combat_target = CombatTarget.new()
		combat_target.name = "CombatTarget"
		add_child(combat_target)

	if not combat_target.hit_received.is_connected(_on_combat_target_hit):
		combat_target.hit_received.connect(_on_combat_target_hit)
	if not combat_target.died.is_connected(_on_combat_target_died):
		combat_target.died.connect(_on_combat_target_died)

	if status_controller == null:
		status_controller = StatusEffectController.new()
		status_controller.name = "StatusEffectController"
		add_child(status_controller)

	_cache_visual_materials()

func _cache_visual_materials() -> void:
	_visual_materials.clear()
	if visuals == null:
		return
	for child in visuals.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst: MeshInstance3D = child as MeshInstance3D
		if mesh_inst:
			var mat = mesh_inst.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				_visual_materials.append(mat)
			elif mesh_inst.mesh and mesh_inst.mesh.surface_get_material(0) is StandardMaterial3D:
				var dup: StandardMaterial3D = mesh_inst.mesh.surface_get_material(0).duplicate()
				mesh_inst.set_surface_override_material(0, dup)
				_visual_materials.append(dup)

## Inicializa la entidad a partir de un Blueprint inmutable
func init_from_blueprint(bp: MobBlueprint, p_level: int = -1, p_is_boss: bool = false) -> void:
	mBlueprint = bp
	mBlueprintName = bp.type
	mStance = bp.stance
	mIsBoss = p_is_boss

	# Generar estadísticas con escalado polinomial
	var stats := bp.create_character_stats(p_level, mIsBoss)
	combat_target.target_name = stats.character_name
	combat_target.stats = stats
	combat_target.max_health = float(stats.max_hp)
	combat_target.current_health = float(stats.current_hp)

	if mIsBoss:
		scale = bp.scale * 1.3
	else:
		scale = bp.scale

	if health_bar:
		var name_col := Color(1.0, 0.3, 0.3) if mIsBoss else (Color(1.0, 0.65, 0.2) if mStance == MobBlueprint.Stance.VIOLENT else Color(0.9, 0.85, 0.5))
		health_bar.set_entity_name(stats.character_name, name_col)
		health_bar.set_health(combat_target.current_health, combat_target.max_health, false)

## Reinicia la entidad para su reutilización desde el Object Pool (Sección 5.1)
func reset(start_pos: Vector3, start_with_fade_in: bool = true, p_level: int = -1) -> void:
	mSpawnPoint = start_pos
	global_position = start_pos
	velocity = Vector3.ZERO
	mMoveDir = Vector3.ZERO
	mAggroTarget = null
	_is_damage_pending = false
	_pending_target = null
	_attack_cooldown_timer = 0.0

	# Restaurar estadísticas completas al 100%
	if mBlueprint:
		var stats := mBlueprint.create_character_stats(p_level, mIsBoss)
		combat_target.stats = stats
		combat_target.max_health = float(stats.max_hp)
		combat_target.current_health = float(stats.max_hp)
		combat_target.is_invulnerable = false

	if health_bar and combat_target:
		health_bar.set_health(combat_target.current_health, combat_target.max_health, false)

	if status_controller:
		status_controller.cleanse_all()

	show()
	set_process(true)
	set_physics_process(true)
	if collision_shape:
		collision_shape.disabled = false

	if start_with_fade_in:
		_start_fade_in()
	else:
		_set_visual_alpha(1.0)
		_set_state(State.IDLE)
		_set_ai_decision(AiDecision.IDLE)
		_reset_idle_timer()

func _start_fade_in() -> void:
	_set_state(State.SPAWNING)
	_set_ai_decision(AiDecision.IDLE)
	_is_spawning_fade = true
	_spawn_fade_timer = 0.0
	_set_visual_alpha(0.0)
	if combat_target:
		combat_target.is_invulnerable = true

func _process(delta: float) -> void:
	# 1. Proceso de Fade-In inicial
	if _is_spawning_fade:
		_spawn_fade_timer += delta
		var alpha := clampf(_spawn_fade_timer / FADE_IN_DURATION, 0.0, 1.0)
		_set_visual_alpha(alpha)
		if _spawn_fade_timer >= FADE_IN_DURATION:
			_is_spawning_fade = false
			_set_visual_alpha(1.0)
			if combat_target:
				combat_target.is_invulnerable = false
			_set_state(State.IDLE)
			_reset_idle_timer()
		return

	# 2. Proceso de Fade-Out post-muerte
	if mCurrentState == State.FADING:
		_fade_timer += delta
		var alpha := clampf(1.0 - (_fade_timer / FADE_OUT_DURATION), 0.0, 1.0)
		_set_visual_alpha(alpha)
		if _fade_timer >= FADE_OUT_DURATION:
			_set_visual_alpha(0.0)
			_set_state(State.REMOVABLE)
		return

	if mCurrentState == State.DEAD or mCurrentState == State.REMOVABLE:
		return

	# 3. Enfriamiento de ataque básico
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	# 4. Resolución de daño con Hit Delay Factor (Sección 6.6)
	if _is_damage_pending:
		_hit_delay_timer -= delta
		if _hit_delay_timer <= 0.0:
			_is_damage_pending = false
			_resolve_pending_attack_damage()

func _physics_process(delta: float) -> void:
	if mCurrentState == State.SPAWNING or mCurrentState == State.DEAD or mCurrentState == State.FADING or mCurrentState == State.REMOVABLE:
		return

	# Bloqueo total por Aturdimiento (Stun) (Sección 6.9)
	if status_controller and status_controller.is_stunned():
		velocity.x = 0.0
		velocity.z = 0.0
		_is_damage_pending = false
		if mCurrentState == State.WALKING:
			_set_state(State.IDLE)
		move_and_slide()
		return

	_update_ai(delta)
	move_and_slide()

# ==============================================================================
# MÁQUINA DE ESTADOS FINITOS (FSM) Y TÁCTICA COGNITIVA (Sección 6)
# ==============================================================================

func _update_ai(delta: float) -> void:
	# --------------------------------------------------------------------------
	# A. REGLA ABSOLUTA DE LEASH (Sección 6.8 & 6.5)
	# --------------------------------------------------------------------------
	var dist_to_spawn_sq := global_position.distance_squared_to(mSpawnPoint)
	var leash_r: float = mBlueprint.leash_radius if mBlueprint else 18.0
	var leash_sq := leash_r * leash_r

	if mAiDecision == AiDecision.CHASING and dist_to_spawn_sq > leash_sq:
		return_to_spawn()
		return

	match mAiDecision:
		AiDecision.IDLE:
			_process_ai_idle(delta)
		AiDecision.PATROLLING:
			_process_ai_patrolling(delta)
		AiDecision.CHASING:
			_process_ai_chasing(delta)
		AiDecision.RETURNING:
			_process_ai_returning(delta)

func _process_ai_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	# Si es de temperamento Violento, escanear agresivamente la presencia de jugadores
	if mStance == MobBlueprint.Stance.VIOLENT:
		var target := _scan_closest_player(mBlueprint.range_violent if mBlueprint else 10.0)
		if target:
			on_aggroed_by(target)
			return

	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_start_patrol_destination()

func _start_patrol_destination() -> void:
	# Cálculo polar respecto al punto de Spawn original (Sección 6.4)
	var angle := randf_range(0.0, TAU)
	var r := randf_range(1.5, PATROL_RADIUS)
	var offset := Vector3(cos(angle) * r, 0.0, sin(angle) * r)
	mPatrolTarget = mSpawnPoint + offset

	_set_ai_decision(AiDecision.PATROLLING)
	_set_state(State.WALKING)

func _process_ai_patrolling(delta: float) -> void:
	# Escaneo visual durante patrulla si es violento
	if mStance == MobBlueprint.Stance.VIOLENT:
		var target := _scan_closest_player(mBlueprint.range_violent if mBlueprint else 10.0)
		if target:
			on_aggroed_by(target)
			return

	var diff := mPatrolTarget - global_position
	diff.y = 0.0
	var dist := diff.length()

	if dist <= ARRIVAL_THRESHOLD:
		# Llegada al destino polar
		velocity.x = 0.0
		velocity.z = 0.0
		_set_ai_decision(AiDecision.IDLE)
		_set_state(State.IDLE)
		_reset_idle_timer()
		return

	var desired_dir := diff.normalized()
	var sep_force := _calculate_separation_force()
	var final_dir := (desired_dir + sep_force).normalized()

	var move_speed: float = (mBlueprint.speed if mBlueprint else 3.8) * 0.65 # Velocidad tranquila de patrulla
	if status_controller:
		move_speed *= status_controller.get_move_speed_multiplier()

	velocity.x = final_dir.x * move_speed
	velocity.z = final_dir.z * move_speed
	_face_direction(final_dir)

func _process_ai_chasing(delta: float) -> void:
	# Validar existencia del objetivo
	if not is_instance_valid(mAggroTarget):
		return_to_spawn()
		return

	var tgt_ct: CombatTarget = mAggroTarget.get_node_or_null("CombatTarget")
	if tgt_ct and tgt_ct.current_health <= 0.0:
		return_to_spawn()
		return

	var diff := mAggroTarget.global_position - global_position
	diff.y = 0.0
	var dist_target_sq := diff.length_squared()
	var atk_range: float = mBlueprint.attack_range if mBlueprint else 2.0
	var stop_dist := atk_range * 0.85
	var stop_dist_sq := stop_dist * stop_dist

	# Comprobar si está en rango de frenado y ataque
	if dist_target_sq <= stop_dist_sq:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_direction(diff.normalized())

		if _attack_cooldown_timer <= 0.0 and not _is_damage_pending:
			_execute_attack_sequence()
		elif not _is_damage_pending and mCurrentState != State.ATTACKING:
			_set_state(State.IDLE)
		return

	# Persecución activa hacia el jugador con separación anti-apilamiento (Boids)
	var desired_dir := diff.normalized()
	var sep_force := _calculate_separation_force()
	var final_dir := (desired_dir + sep_force).normalized()

	var run_speed: float = mBlueprint.speed if mBlueprint else 4.0
	if status_controller:
		run_speed *= status_controller.get_move_speed_multiplier()

	velocity.x = final_dir.x * run_speed
	velocity.z = final_dir.z * run_speed
	_face_direction(final_dir)
	_set_state(State.WALKING)

func _process_ai_returning(delta: float) -> void:
	var diff := mSpawnPoint - global_position
	diff.y = 0.0
	var dist := diff.length()

	if dist <= ARRIVAL_THRESHOLD:
		# Llegada exacta al spawn: Curación completa instantánea y estabilización (Sección 6.8)
		global_position = mSpawnPoint
		velocity = Vector3.ZERO
		if combat_target:
			combat_target.current_health = combat_target.max_health
			if combat_target.stats:
				combat_target.stats.current_hp = combat_target.stats.max_hp
				combat_target.stats.current_mp = combat_target.stats.max_mp
			combat_target.health_changed.emit(combat_target.current_health, combat_target.max_health)
			combat_target.is_invulnerable = false

		if health_bar and combat_target:
			health_bar.set_health(combat_target.current_health, combat_target.max_health, false)

		_set_ai_decision(AiDecision.IDLE)
		_set_state(State.IDLE)
		_reset_idle_timer(2.0, 3.5)
		return

	var move_dir := diff.normalized()
	var sprint_speed: float = (mBlueprint.speed if mBlueprint else 4.0) * 1.25 # Sprint de retorno
	velocity.x = move_dir.x * sprint_speed
	velocity.z = move_dir.z * sprint_speed
	_face_direction(move_dir)
	_set_state(State.WALKING)

# ==============================================================================
# SECUENCIA DE COMBATE Y ATAQUE (Sección 6.6)
# ==============================================================================

func _execute_attack_sequence() -> void:
	_set_state(State.ATTACKING)

	var current_stats: CharacterStats = combat_target.get_stats() if combat_target else null
	var atk_speed: float = current_stats.attack_speed if current_stats else 1.2
	var t_atk := 1.0 / maxf(0.1, atk_speed)
	var delay_factor: float = mBlueprint.attack_delay_factor if mBlueprint else 0.45

	_attack_cooldown_timer = t_atk
	_hit_delay_timer = t_atk * delay_factor
	_is_damage_pending = true
	_pending_target = mAggroTarget

	# Animación visual o retroalimentación física
	_trigger_visual_attack_feedback(t_atk)

func _resolve_pending_attack_damage() -> void:
	if not is_instance_valid(_pending_target):
		_pending_target = null
		return

	var dist := global_position.distance_to(_pending_target.global_position)
	var atk_range: float = mBlueprint.attack_range if mBlueprint else 2.0
	var range_tolerance := atk_range + 1.2 # Tolerancia de esquiva de último momento

	if dist > range_tolerance:
		# El jugador esquivó el golpe a tiempo; el ataque falla por rango
		_pending_target = null
		return

	var attacker_stats: CharacterStats = combat_target.get_stats() if combat_target else null
	var defender_ct: CombatTarget = _pending_target.get_node_or_null("CombatTarget") as CombatTarget
	if defender_ct == null:
		_pending_target = null
		return

	var defender_stats: CharacterStats = defender_ct.get_stats()
	var result: DamageResult = CombatCalculatorScript.calculate_damage(attacker_stats, defender_stats)
	var hit_pos := _pending_target.global_position + Vector3(0.0, 1.0, 0.0)

	defender_ct.take_combat_result(result, hit_pos, self)
	_pending_target = null

# ==============================================================================
# LEASH, RETORNO E INMUNIDAD (Sección 6.8)
# ==============================================================================

## Desengancha inmediatamente al mob del combate y lo envía de regreso a su spawn con inmunidad total
func return_to_spawn() -> void:
	if mAiDecision == AiDecision.RETURNING:
		return

	_set_ai_decision(AiDecision.RETURNING)
	_set_state(State.WALKING)

	mAggroTarget = null
	_is_damage_pending = false
	_pending_target = null

	# Inmunidad total a daño y limpieza de debuffs
	if combat_target:
		combat_target.is_invulnerable = true
	if status_controller:
		status_controller.cleanse_all()

func is_returning_to_spawn() -> bool:
	return mAiDecision == AiDecision.RETURNING

func is_aggro() -> bool:
	return mAiDecision == AiDecision.CHASING and is_instance_valid(mAggroTarget)

func is_alive() -> bool:
	return mCurrentState != State.DEAD and mCurrentState != State.FADING and mCurrentState != State.REMOVABLE

func is_removable() -> bool:
	return mCurrentState == State.REMOVABLE

# ==============================================================================
# PERCEPCIÓN SENSORIAL Y AGRO SOCIAL (Sección 7)
# ==============================================================================

## Responde a un atacante que inflige daño o entra en agro
func on_aggroed_by(attacker: Node3D, alert_allies: bool = true) -> void:
	if not is_alive() or is_returning_to_spawn() or attacker == null or attacker == self:
		return

	# Si es pasivo, ignorar combate
	if mStance == MobBlueprint.Stance.PASSIVE:
		return

	var was_not_chasing := (mAiDecision != AiDecision.CHASING)
	mAggroTarget = attacker
	_set_ai_decision(AiDecision.CHASING)
	_set_state(State.WALKING)

	# Alerta de manada / Agro social (Pack Call) (Sección 7.2)
	if alert_allies and was_not_chasing:
		_alert_nearby_allies(attacker)

func _alert_nearby_allies(attacker: Node3D) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var allies := tree.get_nodes_in_group("enemies")
	var alert_radius := 10.0 # 10 metros en 3D (~250px)

	for node in allies:
		if node == self or not (node is Mob):
			continue
		var ally: Mob = node as Mob
		if ally.is_alive() and not ally.is_returning_to_spawn() and not ally.is_aggro():
			if ally.mBlueprintName == mBlueprintName or ally.mStance != MobBlueprint.Stance.PASSIVE:
				var d := global_position.distance_to(ally.global_position)
				if d <= alert_radius:
					ally.on_aggroed_by(attacker, false)

func _scan_closest_player(max_range: float) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var players_container := tree.root.find_child("Players", true, false)
	if players_container == null:
		return null

	var closest: Node3D = null
	var min_dist_sq := max_range * max_range

	for child in players_container.get_children():
		var p_node := child as Node3D
		if p_node and is_instance_valid(p_node):
			var d_sq := global_position.distance_squared_to(p_node.global_position)
			if d_sq <= min_dist_sq:
				min_dist_sq = d_sq
				closest = p_node

	return closest

# ==============================================================================
# SEPARACIÓN DE ENJAMBRE (BOIDS STEERING ANTI-STACKING) (Sección 8)
# ==============================================================================

func _calculate_separation_force() -> Vector3:
	var tree := get_tree()
	if tree == null:
		return Vector3.ZERO

	var mobs := tree.get_nodes_in_group("enemies")
	var push := Vector3.ZERO
	var r_sep_sq := SEPARATION_RADIUS * SEPARATION_RADIUS

	for node in mobs:
		if node == self or not (node is Node3D):
			continue
		var other: Node3D = node as Node3D
		var diff := global_position - other.global_position
		diff.y = 0.0
		var d_sq := diff.length_squared()

		if d_sq > 0.0001 and d_sq < r_sep_sq:
			var d := sqrt(d_sq)
			var weight := (1.0 - (d / SEPARATION_RADIUS)) * SEPARATION_FORCE
			push += (diff / d) * weight

	return push

# ==============================================================================
# MANEJO DE IMPACTOS Y MUERTE (Sección 10)
# ==============================================================================

func _on_combat_target_hit(damage: float, _hit_pos: Vector3, attacker: Node) -> void:
	if health_bar and combat_target:
		health_bar.set_health(combat_target.current_health, combat_target.max_health, false)

	if is_returning_to_spawn():
		return

	if attacker is Node3D:
		on_aggroed_by(attacker as Node3D)

	_flash_hit_feedback()

func _on_combat_target_died() -> void:
	if mCurrentState == State.DEAD or mCurrentState == State.FADING or mCurrentState == State.REMOVABLE:
		return

	_set_state(State.DEAD)
	_set_ai_decision(AiDecision.IDLE)
	velocity = Vector3.ZERO
	_is_damage_pending = false
	_pending_target = null

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	mob_died.emit(self, mAggroTarget)

	# Otorgar XP al atacante (Sección 6.10)
	var killer = mAggroTarget
	if killer and killer.has_method("add_experience") and mBlueprint:
		var xp_gain: int = combat_target.get_stats().level * 50 if combat_target.get_stats() else mBlueprint.xp
		killer.add_experience(xp_gain)

	# Pasar a Fading
	_set_state(State.FADING)
	_fade_timer = 0.0

# ==============================================================================
# AUXILIARES VISUALES Y FSM
# ==============================================================================

func _set_state(new_state: State) -> void:
	if mCurrentState == new_state:
		return
	var old := mCurrentState
	mCurrentState = new_state
	state_changed.emit(old, new_state)

func _set_ai_decision(new_dec: AiDecision) -> void:
	if mAiDecision == new_dec:
		return
	var old := mAiDecision
	mAiDecision = new_dec
	decision_changed.emit(old, new_dec)

func _reset_idle_timer(min_t: float = 1.5, max_t: float = 3.5) -> void:
	_idle_timer = randf_range(min_t, max_t)

func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		rotation.y = atan2(-dir.x, -dir.z)

func _set_visual_alpha(alpha: float) -> void:
	for mat in _visual_materials:
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a = alpha

func _flash_hit_feedback() -> void:
	if visuals == null:
		return
	for mat in _visual_materials:
		if mat:
			var prev_col := mat.albedo_color
			mat.albedo_color = Color(1.0, 0.25, 0.25, prev_col.a)
			var tween := create_tween()
			if tween:
				tween.tween_interval(0.08)
				tween.tween_callback(func():
					mat.albedo_color = prev_col
				)

func _trigger_visual_attack_feedback(duration: float) -> void:
	if visuals == null:
		return
	var tween := create_tween()
	if tween:
		tween.tween_property(visuals, "scale", Vector3(1.15, 0.85, 1.15), duration * 0.3)
		tween.tween_property(visuals, "scale", Vector3.ONE, duration * 0.7)
