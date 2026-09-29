class_name CombatCalculator
extends RefCounted

## Responsabilidad: Calculadora pura y sin estado para resolución determinista de fórmulas de combate.
## No guarda estado interno ni depende de nodos 3D, garantizando reproducibilidad en cliente y servidor headless.
## Parámetros de fórmulas editables en caliente desde config/combat_config.json.

# --- Constantes de balance por defecto (usadas como contingencia / fallback) ---
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

	var k: float = float(GameConfig.get_combat_value("formulas", "evasion_weight_k", EVASION_WEIGHT_K))

	# Ponderación de Evasión frente a Precisión (k = 0.25)
	var denom: float = acc + (eva * k)
	var stat_chance: float = 0.80
	if denom > 0.0001:
		stat_chance = acc / denom

	# Factor diferencial por nivel
	var level_diff: int = attacker.level - defender.level
	var level_penalty: float = float(GameConfig.get_combat_value("formulas", "level_diff_hit_penalty", LEVEL_DIFF_HIT_PENALTY))
	var level_factor: float = float(level_diff) * level_penalty

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
	variance_percent: int = -1
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
## Si variance_percent es negativo, se consulta el valor configurado en config/combat_config.json.
static func calculate_damage(
	attacker: CharacterStats,
	defender: CharacterStats,
	allow_true_damage: bool = true,
	flat_bonus: float = 0.0,
	variance_percent: int = -1
) -> DamageResult:
	# 1. Ataque Base y Multiplicador Físico
	var raw_attack: float = ((attacker.attack if attacker else 0.0) + flat_bonus)
	var damage_multiplier: float = (attacker.physical_damage_bonus / 100.0) if attacker else 1.0
	var enhanced_damage: float = raw_attack * damage_multiplier

	# 2. Daño Porcentual por Vida Máxima del Defensor
	if attacker and defender and attacker.enemy_max_hp_damage_percent > 0.0:
		enhanced_damage += float(defender.max_hp) * (attacker.enemy_max_hp_damage_percent / 100.0)

	# 3. Variación Aleatoria de Daño
	var actual_variance: int = variance_percent
	if actual_variance < 0:
		actual_variance = int(GameConfig.get_combat_value("formulas", "variance_percent", DEFAULT_VARIANCE_PERCENT))

	if actual_variance > 0:
		var random_offset := randf_range(-float(actual_variance), float(actual_variance))
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
	var def_const_base: float = float(GameConfig.get_combat_value("formulas", "defense_constant_base", DEFENSE_CONSTANT_BASE))
	var def_const_scale: float = float(GameConfig.get_combat_value("formulas", "defense_constant_level_scale", DEFENSE_CONSTANT_LEVEL_SCALE))
	var defense_constant: float = (float(target_level) * def_const_scale) + def_const_base
	var armor_reduction: float = effective_defense / (effective_defense + defense_constant)
	var reduced_phys: float = raw_phys * (1.0 - armor_reduction)

	# 5. Penalización / Bono por Diferencial de Nivel
	if attacker and defender:
		var level_diff: int = attacker.level - defender.level
		var level_dmg_penalty: float = float(GameConfig.get_combat_value("formulas", "level_diff_damage_penalty", LEVEL_DIFF_DAMAGE_PENALTY))
		var min_lvl_mult: float = float(GameConfig.get_combat_value("formulas", "min_level_multiplier", MIN_LEVEL_MULTIPLIER))
		var max_lvl_mult: float = float(GameConfig.get_combat_value("formulas", "max_level_multiplier", MAX_LEVEL_MULTIPLIER))
		var level_multiplier: float = 1.0 + (float(level_diff) * level_dmg_penalty)
		level_multiplier = clampf(level_multiplier, min_lvl_mult, max_lvl_mult)
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
	return calculate_damage(caster, target, allow_true_damage, skill_flat_damage, -1)

# ==============================================================================
# 6. EFECTOS ON-HIT Y CONTROL DE MASAS (Sección 7 Especificación)
# ==============================================================================

## Calcula la cantidad de vida curada por Robo de Vida (Lifesteal) a partir del daño total infligido.
static func calculate_lifesteal(attacker: CharacterStats, total_damage: int) -> int:
	if attacker == null or total_damage <= 0 or attacker.lifesteal_percent <= 0.0:
		return 0
	return maxi(0, int(round(float(total_damage) * (attacker.lifesteal_percent / 100.0))))

## Calcula la cantidad de maná restaurada por Robo de Maná (Mana Steal) a partir del daño total infligido.
static func calculate_mana_steal(attacker: CharacterStats, total_damage: int) -> int:
	if attacker == null or total_damage <= 0 or attacker.mana_steal_percent <= 0.0:
		return 0
	return maxi(0, int(round(float(total_damage) * (attacker.mana_steal_percent / 100.0))))

## Calcula el daño reflejado por Espinas (Thorns), mitigado por la armadura del atacante original.
## Retorna null si no hay espinas activas o si el daño original fue Daño Verdadero puro.
static func calculate_thorns_damage(
	defender: CharacterStats,
	attacker: CharacterStats,
	total_damage: int,
	is_pure_true_damage: bool = false
) -> DamageResult:
	if defender == null or attacker == null or total_damage <= 0:
		return null
	if defender.thorns_percent <= 0.0 or is_pure_true_damage:
		return null

	var raw_thorns := float(total_damage) * (defender.thorns_percent / 100.0)
	if raw_thorns <= 0.0:
		return null

	# El daño reflejado se mitiga con la armadura del atacante original
	var res := calculate_mitigated_damage(defender, attacker, raw_thorns, true)
	res.is_thorns = true
	return res

## Determina si un golpe aplica Aturdimiento (Stun) y calcula su duración efectiva mitigada por Tenacidad.
## Retorna 0.0 si falla la tirada o si la duración efectiva cae por debajo del umbral mínimo de 0.05s.
static func calculate_stun_duration(
	attacker: CharacterStats,
	defender: CharacterStats,
	forced_roll: float = -1.0
) -> float:
	if attacker == null or attacker.stun_chance <= 0.0 or attacker.stun_duration <= 0.0:
		return 0.0

	var roll := forced_roll if forced_roll >= 0.0 else (randf() * 100.0)
	if roll > attacker.stun_chance:
		return 0.0

	var tenacity: float = defender.tenacity_percent if defender else 0.0
	var effective_duration := attacker.stun_duration * maxf(0.0, 1.0 - (tenacity / 100.0))

	# Umbral mínimo de inmunidad de la especificación
	if effective_duration <= 0.05:
		return 0.0

	return effective_duration

## Calcula el daño de un tick de Sangrado periódico (1.0s), sumando daño plano y porcentaje de ataque actual.
static func calculate_bleed_tick(
	source: CharacterStats,
	victim: CharacterStats,
	flat_damage: int,
	percent_damage: float
) -> DamageResult:
	if source == null or victim == null:
		return null

	var current_atk: float = float(source.attack)
	var pct_val: float = current_atk * (percent_damage / 100.0)
	var total_raw := float(flat_damage) + pct_val
	if total_raw <= 0.0:
		return null

	var res := calculate_mitigated_damage(source, victim, total_raw, true)
	res.is_bleed = true
	return res

