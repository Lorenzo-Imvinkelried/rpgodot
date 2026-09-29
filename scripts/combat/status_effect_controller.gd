class_name StatusEffectController
extends Node

## Responsabilidad: Gestiona la duración, refresco, multiplicadores y ticks periódicos de
## estados alterados (Stun, Bleed sin snapshotting, Slow) para cualquier entidad de combate.

signal stun_applied(duration: float)
signal stun_removed()
signal bleed_applied(duration: float)
signal bleed_tick_applied(damage: int)
signal bleed_removed()
signal slow_applied(move_percent: float, attack_percent: float, duration: float)
signal slow_removed()

const BLEED_TICK_INTERVAL: float = 1.0

# --- Estado de Aturdimiento (Stun) ---
var _stun_time_left: float = 0.0

# --- Estado de Sangrado Continuo (Bleed sin Snapshotting) ---
var _bleed_time_left: float = 0.0
var _bleed_tick_timer: float = 0.0
var _bleed_source_stats: CharacterStats = null
var _bleed_flat_damage: int = 0
var _bleed_percent_damage: float = 0.0
var _bleed_source_node: Node = null

# --- Estado de Ralentización (Slow) ---
var _slow_time_left: float = 0.0
var _slow_move_percent: float = 0.0
var _slow_attack_percent: float = 0.0

@onready var _combat_target: CombatTarget = get_parent().get_node_or_null("CombatTarget")

func _process(delta: float) -> void:
	update_status_effects(delta)

## Actualiza temporizadores de estados alterados y resuelve ticks de sangrado cada 1.0s.
func update_status_effects(delta: float) -> void:
	# 1. Aturdimiento
	if _stun_time_left > 0.0:
		_stun_time_left -= delta
		if _stun_time_left <= 0.0:
			_stun_time_left = 0.0
			stun_removed.emit()

	# 2. Ralentización
	if _slow_time_left > 0.0:
		_slow_time_left -= delta
		if _slow_time_left <= 0.0:
			_slow_time_left = 0.0
			_slow_move_percent = 0.0
			_slow_attack_percent = 0.0
			slow_removed.emit()

	# 3. Sangrado
	if _bleed_time_left > 0.0:
		_bleed_time_left -= delta
		_bleed_tick_timer += delta

		if _bleed_tick_timer >= BLEED_TICK_INTERVAL:
			_bleed_tick_timer -= BLEED_TICK_INTERVAL
			_execute_bleed_tick()

		if _bleed_time_left <= 0.0:
			_bleed_time_left = 0.0
			_bleed_tick_timer = 0.0
			_bleed_source_stats = null
			_bleed_source_node = null
			bleed_removed.emit()

## Aplica o renueva el estado de Aturdimiento (Stun).
func apply_stun(duration: float) -> void:
	if duration <= 0.05:
		return
	var was_stunned := is_stunned()
	_stun_time_left = maxf(_stun_time_left, duration)
	if not was_stunned:
		stun_applied.emit(_stun_time_left)

func is_stunned() -> bool:
	return _stun_time_left > 0.0

func get_stun_time_left() -> float:
	return _stun_time_left

## Aplica o renueva el estado de Sangrado sin Snapshotting:
## Actualiza los valores de daño con los stats ACTUALES del atacante sin resetear el timer de 1.0s.
func apply_bleed(
	source_stats: CharacterStats,
	duration: float,
	flat_damage: int,
	percent_damage: float,
	source_node: Node = null
) -> void:
	if duration <= 0.0:
		return

	var was_bleeding := is_bleeding()
	# Renueva la duración y actualiza stats en tiempo real (evita snapshotting)
	_bleed_time_left = maxf(_bleed_time_left, duration)
	_bleed_source_stats = source_stats
	_bleed_flat_damage = flat_damage
	_bleed_percent_damage = percent_damage
	_bleed_source_node = source_node

	# Si es la primera vez que se aplica, inicializar el tick timer en 0
	if not was_bleeding:
		_bleed_tick_timer = 0.0
		bleed_applied.emit(_bleed_time_left)

func is_bleeding() -> bool:
	return _bleed_time_left > 0.0

func _execute_bleed_tick() -> void:
	if _combat_target == null:
		_combat_target = get_parent().get_node_or_null("CombatTarget")
	if _combat_target == null or _bleed_source_stats == null:
		return

	var victim_stats := _combat_target.get_stats()
	var res := CombatCalculator.calculate_bleed_tick(
		_bleed_source_stats,
		victim_stats,
		_bleed_flat_damage,
		_bleed_percent_damage
	)

	if res and res.total_damage > 0:
		var parent_node := get_parent() as Node3D
		var hit_pos := parent_node.global_position + Vector3(0, 1.2, 0) if parent_node else Vector3.ZERO
		_combat_target.take_combat_result(res, hit_pos, _bleed_source_node)
		bleed_tick_applied.emit(res.total_damage)

## Aplica o renueva Ralentización (Slow) de movimiento y de ataque.
func apply_slow(move_pct: float, attack_pct: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var was_slowed := is_slowed()
	_slow_time_left = maxf(_slow_time_left, duration)
	_slow_move_percent = maxf(_slow_move_percent, move_pct)
	_slow_attack_percent = maxf(_slow_attack_percent, attack_pct)

	if not was_slowed:
		slow_applied.emit(_slow_move_percent, _slow_attack_percent, _slow_time_left)

func is_slowed() -> bool:
	return _slow_time_left > 0.0

## Multiplicador de velocidad de traslación (0.0 si está aturdido, reducido si está ralentizado).
func get_move_speed_multiplier() -> float:
	if is_stunned():
		return 0.0
	if is_slowed():
		return maxf(0.10, 1.0 - (_slow_move_percent / 100.0))
	return 1.0

## Multiplicador de velocidad de ataque (0.0 si está aturdido, reducido si está ralentizado).
func get_attack_speed_multiplier() -> float:
	if is_stunned():
		return 0.0
	if is_slowed():
		return maxf(0.10, 1.0 - (_slow_attack_percent / 100.0))
	return 1.0

## Limpia todos los estados alterados (útil en respawn o muerte).
func clear_all_effects() -> void:
	if is_stunned():
		_stun_time_left = 0.0
		stun_removed.emit()
	if is_bleeding():
		_bleed_time_left = 0.0
		_bleed_tick_timer = 0.0
		_bleed_source_stats = null
		_bleed_source_node = null
		bleed_removed.emit()
	if is_slowed():
		_slow_time_left = 0.0
		_slow_move_percent = 0.0
		_slow_attack_percent = 0.0
		slow_removed.emit()
