class_name CombatCalculator
extends RefCounted

## Responsabilidad: Calculadora pura y sin estado para resolución determinista de fórmulas de combate.
## No guarda estado interno ni depende de nodos 3D, garantizando reproducibilidad en cliente y servidor headless.

# --- Constantes de balance del sistema de combate ---
const LEVEL_DIFF_HIT_PENALTY: float = 0.002 # 0.2% por nivel de diferencia
const DEFENSE_CONSTANT_BASE: float = 100.0
const DEFENSE_CONSTANT_LEVEL_SCALE: float = 15.0
const LEVEL_DIFF_DAMAGE_PENALTY: float = 0.02 # 2% por nivel de diferencia
const MIN_LEVEL_MULTIPLIER: float = 0.10 # -90% daño mínimo por diferencial de nivel
const MAX_LEVEL_MULTIPLIER: float = 1.50 # +50% daño máximo por diferencial de nivel
const DEFAULT_VARIANCE_PERCENT: int = 6 # Variación de daño (+/- 6%)
const EVASION_WEIGHT_K: float = 0.25 # La precisión pesa 4 veces más que la evasión

# ==============================================================================
# 1. ACIERTO Y EVASIÓN
# ==============================================================================

## Calcula la probabilidad exacta (0.05 a 1.00) de que el atacante acierte al defensor.
static func get_hit_chance(attacker: CharacterStats, defender: CharacterStats) -> float:
	if attacker == null or defender == null:
		return 1.0

	var acc: float = attacker.accuracy
	var eva: float = defender.evasion

	# Ponderación de Evasión frente a Precisión (k = 0.25)
	var denom: float = acc + (eva * EVASION_WEIGHT_K)
	var stat_chance: float = 0.80
	if denom > 0.0001:
		stat_chance = acc / denom

	# Factor diferencial por nivel
	var level_diff: int = attacker.level - defender.level
	var level_factor: float = float(level_diff) * LEVEL_DIFF_HIT_PENALTY

	# Clamp de seguridad: mínimo 5% garantizado, máximo 100%
	return clampf(stat_chance + level_factor, 0.05, 1.00)

## Realiza una tirada aleatoria para determinar si el golpe conecta.
static func try_to_hit(attacker: CharacterStats, defender: CharacterStats) -> bool:
	var chance := get_hit_chance(attacker, defender)
	return randf() <= chance

# ==============================================================================
# 2. RESOLUCIÓN COMPLETA DE ATAQUE (Acierto + Cálculo de Daño)
# ==============================================================================

## Ejecuta la secuencia completa de un ataque: tirada de acierto seguida de cálculo de daño mitigado.
static func perform_attack(
	attacker: CharacterStats,
	defender: CharacterStats,
	allow_true_damage: bool = true,
	flat_bonus: float = 0.0,
	variance_percent: int = DEFAULT_VARIANCE_PERCENT
) -> DamageResult:
	if not try_to_hit(attacker, defender):
		var miss_result := DamageResult.new()
		miss_result.is_miss = true
		return miss_result

	return calculate_damage(attacker, defender, allow_true_damage, flat_bonus, variance_percent)

# ==============================================================================
# 3. PIPELINE DE CÁLCULO DE DAÑO
# ==============================================================================

## Calcula el daño bruto infligido (Fase 1) y procesa su mitigación final (Fase 3).
static func calculate_damage(
	attacker: CharacterStats,
	defender: CharacterStats,
	allow_true_damage: bool = true,
	flat_bonus: float = 0.0,
	variance_percent: int = DEFAULT_VARIANCE_PERCENT
) -> DamageResult:
	# 1. Ataque Base y Multiplicador Físico
	var raw_attack: float = ((attacker.attack if attacker else 0.0) + flat_bonus)
	var damage_multiplier: float = (attacker.physical_damage_bonus / 100.0) if attacker else 1.0
	var enhanced_damage: float = raw_attack * damage_multiplier

	# 2. Daño Porcentual por Vida Máxima del Defensor
	if attacker and defender and attacker.enemy_max_hp_damage_percent > 0.0:
		enhanced_damage += float(defender.max_hp) * (attacker.enemy_max_hp_damage_percent / 100.0)

	# 3. Variación Aleatoria de Daño (+/- variance_percent)
	if variance_percent > 0:
		var random_offset := randf_range(-float(variance_percent), float(variance_percent))
		enhanced_damage *= (1.0 + (random_offset / 100.0))

	# 4. Mecánica de Ejecución (Execute Damage)
	if attacker and defender and attacker.execute_threshold_factor > 0.0:
		var execution_hp := float(defender.max_hp) * attacker.execute_threshold_factor
		if float(defender.current_hp) < execution_hp:
			enhanced_damage *= attacker.execute_damage_multiplier

	# 5. Determinación de Golpe Crítico
	var is_crit: bool = false
	if attacker:
		var crit_chance: float = attacker.crit_chance
		var crit_avoid: float = defender.crit_avoidance_percent if defender else 0.0
		var final_crit_chance: float = maxf(0.0, crit_chance - crit_avoid)
		if randf() * 100.0 <= final_crit_chance:
			var crit_mult: float = attacker.crit_damage / 100.0
			enhanced_damage *= crit_mult
			is_crit = true

	# Pasar a la fase de mitigación
	return calculate_mitigated_damage(attacker, defender, enhanced_damage, true, allow_true_damage, is_crit)

# ==============================================================================
# 4. FASE DE MITIGACIÓN (Armadura, Bloqueo, Penetración, Nivel)
# ==============================================================================

## Aplica la mitigación defensiva completa sobre un monto de daño bruto.
static func calculate_mitigated_damage(
	attacker: CharacterStats,
	defender: CharacterStats,
	total_raw: float,
	is_physical: bool = true,
	allow_true_damage: bool = true,
	is_crit: bool = false
) -> DamageResult:
	var result := DamageResult.new()
	result.is_crit = is_crit

	# 1. Desglose de Daño Verdadero (True Damage)
	var true_pct: float = 0.0
	if attacker and allow_true_damage:
		true_pct = clampf(attacker.true_damage_percent / 100.0, 0.0, 1.0)

	if not is_physical:
		# Daño puro (mágico o ambiental) ignora armadura
		result.physical_damage = 0
		result.true_damage = maxi(0, int(round(total_raw)))
		result.total_damage = result.true_damage
		return result

	var raw_true: float = total_raw * true_pct
	var raw_phys: float = total_raw * (1.0 - true_pct)

	# 2. Comprobación de Bloqueo (Escudos / Postura)
	if defender and defender.block_chance > 0.0 and raw_phys > 0.001:
		if randf() * 100.0 <= defender.block_chance:
			result.is_blocked = true
			var block_val: float = defender.block_value_percent
			var multiplier: float = maxf(0.0, 1.0 - (block_val / 100.0))
			raw_phys *= multiplier

	# 3. Penetración de Armadura y Anti-Penetración
	var target_total_armor: float = float(defender.defense) if defender else 0.0
	var effective_pen_percent: float = 0.0
	var effective_pen_flat: float = 0.0

	if attacker and defender:
		effective_pen_percent = maxf(0.0, attacker.armor_pen_percent - defender.anti_armor_pen_percent)
		effective_pen_flat = maxf(0.0, attacker.armor_pen_flat - defender.anti_armor_pen_flat)

	var armor_after_percent: float = target_total_armor * (1.0 - (effective_pen_percent / 100.0))
	var effective_defense: float = maxf(0.0, armor_after_percent - effective_pen_flat)

	# 4. Curva Hiperbólica de Reducción por Armadura
	var target_level: int = defender.level if defender else 1
	var defense_constant: float = (float(target_level) * DEFENSE_CONSTANT_LEVEL_SCALE) + DEFENSE_CONSTANT_BASE
	var armor_reduction: float = effective_defense / (effective_defense + defense_constant)
	var reduced_phys: float = raw_phys * (1.0 - armor_reduction)

	# 5. Penalización / Bono por Diferencial de Nivel
	if attacker and defender:
		var level_diff: int = attacker.level - defender.level
		var level_multiplier: float = 1.0 + (float(level_diff) * LEVEL_DIFF_DAMAGE_PENALTY)
		level_multiplier = clampf(level_multiplier, MIN_LEVEL_MULTIPLIER, MAX_LEVEL_MULTIPLIER)
		reduced_phys *= level_multiplier
		raw_true *= level_multiplier

	# 6. Reducción de Daño Directo Porcentual
	if defender and defender.damage_reduction_percent > 0.0:
		reduced_phys *= maxf(0.0, 1.0 - (defender.damage_reduction_percent / 100.0))

	# 7. Conversión Final y Regla del Daño Mínimo
	result.physical_damage = maxi(0, int(round(reduced_phys)))
	result.true_damage = maxi(0, int(round(raw_true)))
	result.total_damage = result.physical_damage + result.true_damage

	# Si había daño entrante positivo pero la mitigación lo redujo a 0, garantizar al menos 1
	if result.total_damage < 1 and total_raw > 0.0:
		result.total_damage = 1
		if result.physical_damage == 0 and result.true_damage == 0:
			result.physical_damage = 1

	return result

# ==============================================================================
# 5. DAÑO DE HABILIDADES (Skill Damage)
# ==============================================================================

## Calcula el daño de una habilidad activa sumando su potencia fija al ataque del lanzador.
static func calculate_skill_damage(
	caster: CharacterStats,
	target: CharacterStats,
	skill_flat_damage: float,
	is_physical: bool = true,
	allow_true_damage: bool = true
) -> DamageResult:
	var base_atk: float = float(caster.attack) if caster else 0.0
	var input_raw: float = base_atk + skill_flat_damage
	return calculate_damage(caster, target, allow_true_damage, skill_flat_damage, DEFAULT_VARIANCE_PERCENT)
