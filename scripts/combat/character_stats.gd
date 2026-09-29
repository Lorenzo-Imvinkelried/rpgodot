class_name CharacterStats
extends Resource

## Responsabilidad: Almacena atributos primarios, secundarios, bonos de equipo y calcula
## de forma determinista las estadísticas derivadas de una entidad según las reglas de combate.
## Permite sobreescribir escalados y valores por defecto mediante config/combat_config.json.

# --- Constantes de balance y escalado por defecto ---
const HP_PER_VIT: float = 20.0
const DEF_PER_VIT: float = 2.0
const MP_PER_INT: float = 20.0
const ATK_PER_STR: float = 3.0
const BASE_ATK_SPEED_DEFAULT: float = 1.4
const ATK_SPEED_PER_AGI: float = 0.01 # 0.10 por cada 10 puntos de Agilidad
const CRIT_PER_AGI: float = 0.1 # 1.0% por cada 10 puntos de Agilidad

# --- Nivel y Nombre ---
@export_group("Identidad y Nivel")
@export var character_name: String = "Personaje"
@export var level: int = 1
@export var weight_kg: float = 75.0

# --- Atributos Primarios Base ---
@export_group("Atributos Primarios Base")
@export var base_str: int = 10
@export var base_agi: int = 10
@export var base_int: int = 10
@export var base_vit: int = 10

# Alias para compatibilidad conceptual con DEX
var base_dex: int:
	get: return base_agi
	set(v): base_agi = v

# --- Bonos Planos y Buffs de Atributos Primarios ---
@export_group("Bonos de Atributos")
@export var bonus_str: int = 0
@export var bonus_agi: int = 0
@export var bonus_int: int = 0
@export var bonus_vit: int = 0

var buff_str: int = 0
var buff_agi: int = 0
var buff_int: int = 0
var buff_vit: int = 0

# --- Bonos Porcentuales de Equipo en Atributos Primarios ---
@export_group("Porcentajes de Equipo en Atributos")
@export var equip_str_percent: float = 0.0
@export var equip_agi_percent: float = 0.0
@export var equip_int_percent: float = 0.0
@export var equip_vit_percent: float = 0.0

# --- Totales de Atributos Primarios (Calculados) ---
var total_str: float = 10.0
var total_agi: float = 10.0
var total_int: float = 10.0
var total_vit: float = 10.0

var total_dex: float:
	get: return total_agi

# --- Bases de Estadísticas Secundarias ---
@export_group("Bases Secundarias")
@export var base_max_hp: float = 0.0
@export var base_max_mp: float = 0.0
@export var base_attack: float = 0.0
@export var base_defense: float = 0.0
@export var base_accuracy: float = 100.0
@export var base_evasion: float = 200.0
@export var base_crit_chance: float = 5.0 # Porcentaje (5.0%)
@export var base_crit_damage: float = 150.0 # Porcentaje (150.0%)
@export var base_atk_speed: float = BASE_ATK_SPEED_DEFAULT

# --- Bonos de Equipo y Buffs Secundarios ---
@export_group("Bonos Planos de Equipo")
@export var equip_hp_bonus: float = 0.0
@export var equip_mp_bonus: float = 0.0
@export var equip_attack: float = 0.0
@export var equip_defense: float = 0.0
@export var equip_crit_chance: float = 0.0
@export var equip_crit_damage: float = 0.0
@export var equip_atk_speed: float = 0.0

@export_group("Porcentajes de Equipo Secundarios")
@export var equip_hp_percent: float = 0.0
@export var equip_mp_percent: float = 0.0
@export var equip_attack_percent: float = 0.0
@export var equip_defense_percent: float = 0.0

# Buffs efímeros en secundarias
var buff_hp: float = 0.0
var buff_mp: float = 0.0
var buff_atk: float = 0.0
var buff_def: float = 0.0
var buff_accuracy: float = 0.0
var buff_evasion: float = 0.0
var buff_crit_chance: float = 0.0
var buff_crit_damage: float = 0.0
var buff_atk_speed: float = 0.0
var bonus_accuracy: float = 0.0
var bonus_evasion: float = 0.0

# --- Estadísticas Derivadas Finales (Calculadas) ---
var max_hp: int = 100
var current_hp: int = 100
var max_mp: int = 100
var current_mp: int = 100
var attack: int = 30
var defense: int = 20
var accuracy: float = 100.0
var evasion: float = 200.0
var crit_chance: float = 5.0
var crit_damage: float = 150.0
var attack_speed: float = BASE_ATK_SPEED_DEFAULT

# --- Modificadores Ofensivos Avanzados ---
@export_group("Ofensiva Avanzada")
@export var armor_pen_flat: float = 0.0
@export var armor_pen_percent: float = 0.0
@export var true_damage_percent: float = 0.0
@export var execute_damage_multiplier: float = 1.50
@export var execute_threshold_factor: float = 0.25 # 25% HP
@export var enemy_max_hp_damage_percent: float = 0.0
@export var physical_damage_bonus: float = 100.0 # Base 100%

# --- Modificadores Defensivos Avanzados ---
@export_group("Defensiva Avanzada")
@export var block_chance: float = 0.0
@export var block_value_percent: float = 50.0
@export var thorns_percent: float = 0.0
@export var tenacity_percent: float = 0.0
@export var damage_reduction_percent: float = 0.0
@export var crit_avoidance_percent: float = 0.0
@export var anti_armor_pen_percent: float = 0.0
@export var anti_armor_pen_flat: float = 0.0

# --- Utilidad y Cadencia ---
@export_group("Utilidad y Cadencia")
@export var lifesteal_percent: float = 0.0
@export var mana_steal_percent: float = 0.0
@export var move_speed: float = 5.0
@export var cooldown_reduction: float = 0.0
@export var double_strike_chance: float = 0.0
@export var triple_strike_chance: float = 0.0

func _init() -> void:
	recalculate_stats(true)

## Recalcula deterministamente todas las estadísticas secundarias a partir de atributos y modificadores.
## Consulta config/combat_config.json para constantes de escalado si existen.
## Si reset_current_vitals es true, restablece vida y maná a su valor máximo.
func recalculate_stats(reset_current_vitals: bool = false) -> void:
	# Factores de escalado (con fallback a constantes base)
	var hp_scale: float = float(GameConfig.get_combat_value("stat_scaling", "hp_per_vit", HP_PER_VIT))
	var def_scale: float = float(GameConfig.get_combat_value("stat_scaling", "def_per_vit", DEF_PER_VIT))
	var mp_scale: float = float(GameConfig.get_combat_value("stat_scaling", "mp_per_int", MP_PER_INT))
	var atk_scale: float = float(GameConfig.get_combat_value("stat_scaling", "atk_per_str", ATK_PER_STR))
	var atk_speed_agi_scale: float = float(GameConfig.get_combat_value("stat_scaling", "atk_speed_per_agi", ATK_SPEED_PER_AGI))
	var crit_agi_scale: float = float(GameConfig.get_combat_value("stat_scaling", "crit_per_agi", CRIT_PER_AGI))

	# 1. Totales de atributos con bonos porcentuales de gemas/equipo
	total_str = (float(base_str) + float(bonus_str) + float(buff_str)) * (1.0 + equip_str_percent / 100.0)
	total_agi = (float(base_agi) + float(bonus_agi) + float(buff_agi)) * (1.0 + equip_agi_percent / 100.0)
	total_int = (float(base_int) + float(bonus_int) + float(buff_int)) * (1.0 + equip_int_percent / 100.0)
	total_vit = (float(base_vit) + float(bonus_vit) + float(buff_vit)) * (1.0 + equip_vit_percent / 100.0)

	# 2. Puntos de Vida Máximos (Max HP)
	var raw_max_hp: float = (total_vit * hp_scale) + base_max_hp + equip_hp_bonus + buff_hp
	raw_max_hp *= (1.0 + equip_hp_percent / 100.0)
	max_hp = maxi(1, int(round(raw_max_hp)))

	# 3. Defensa Física (Defense)
	var raw_def: float = (total_vit * def_scale) + base_defense + equip_defense + buff_def
	raw_def *= (1.0 + equip_defense_percent / 100.0)
	defense = maxi(0, int(round(raw_def)))

	# 4. Puntos de Maná Máximos (Max MP)
	var raw_max_mp: float = (total_int * mp_scale) + base_max_mp + equip_mp_bonus + buff_mp
	raw_max_mp *= (1.0 + equip_mp_percent / 100.0)
	max_mp = maxi(0, int(round(raw_max_mp)))

	# 5. Poder de Ataque (Attack)
	var raw_atk: float = (total_str * atk_scale) + base_attack + equip_attack + buff_atk
	raw_atk *= (1.0 + equip_attack_percent / 100.0)
	attack = maxi(0, int(round(raw_atk)))

	# 6. Precisión y Evasión
	accuracy = maxf(0.0, base_accuracy + bonus_accuracy + buff_accuracy)
	evasion = maxf(0.0, base_evasion + bonus_evasion + buff_evasion)

	# 7. Probabilidad y Daño Crítico
	var agi_units: float = total_agi / 10.0
	var raw_crit_chance: float = base_crit_chance + equip_crit_chance + (agi_units * (crit_agi_scale * 10.0)) + buff_crit_chance
	crit_chance = clampf(raw_crit_chance, 0.0, 100.0)
	crit_damage = maxf(0.0, base_crit_damage + equip_crit_damage + buff_crit_damage)

	# 8. Velocidad de Ataque
	attack_speed = maxf(0.05, base_atk_speed + equip_atk_speed + (agi_units * (atk_speed_agi_scale * 10.0)) + buff_atk_speed)

	# 9. Ajuste de vitales actuales
	if reset_current_vitals:
		current_hp = max_hp
		current_mp = max_mp
	else:
		current_hp = clampi(current_hp, 0, max_hp)
		current_mp = clampi(current_mp, 0, max_mp)

func is_alive() -> bool:
	return current_hp > 0

func apply_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)

func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)

func consume_mana(amount: int) -> bool:
	if current_mp >= amount:
		current_mp -= amount
		return true
	return false

func restore_mana(amount: int) -> void:
	current_mp = mini(max_mp, current_mp + amount)

# ==============================================================================
# Métodos de fábrica e importación desde Diccionario / JSON
# ==============================================================================

## Carga atributos y modificadores desde un Dictionary (por ejemplo, proveniente de JSON).
func load_from_dictionary(dict: Dictionary) -> void:
	if dict.has("character_name"): character_name = str(dict["character_name"])
	if dict.has("level"): level = int(dict["level"])
	if dict.has("weight_kg"): weight_kg = float(dict["weight_kg"])
	if dict.has("base_str"): base_str = int(dict["base_str"])
	if dict.has("base_agi"): base_agi = int(dict["base_agi"])
	if dict.has("base_int"): base_int = int(dict["base_int"])
	if dict.has("base_vit"): base_vit = int(dict["base_vit"])
	if dict.has("base_attack"): base_attack = float(dict["base_attack"])
	if dict.has("base_defense"): base_defense = float(dict["base_defense"])
	if dict.has("base_max_hp"): base_max_hp = float(dict["base_max_hp"])
	if dict.has("base_max_mp"): base_max_mp = float(dict["base_max_mp"])
	if dict.has("base_accuracy"): base_accuracy = float(dict["base_accuracy"])
	if dict.has("base_evasion"): base_evasion = float(dict["base_evasion"])
	if dict.has("base_crit_chance"): base_crit_chance = float(dict["base_crit_chance"])
	if dict.has("base_crit_damage"): base_crit_damage = float(dict["base_crit_damage"])
	if dict.has("base_atk_speed"): base_atk_speed = float(dict["base_atk_speed"])
	if dict.has("armor_pen_flat"): armor_pen_flat = float(dict["armor_pen_flat"])
	if dict.has("armor_pen_percent"): armor_pen_percent = float(dict["armor_pen_percent"])
	if dict.has("true_damage_percent"): true_damage_percent = float(dict["true_damage_percent"])
	if dict.has("execute_damage_multiplier"): execute_damage_multiplier = float(dict["execute_damage_multiplier"])
	if dict.has("execute_threshold_factor"): execute_threshold_factor = float(dict["execute_threshold_factor"])
	if dict.has("enemy_max_hp_damage_percent"): enemy_max_hp_damage_percent = float(dict["enemy_max_hp_damage_percent"])
	if dict.has("physical_damage_bonus"): physical_damage_bonus = float(dict["physical_damage_bonus"])
	if dict.has("block_chance"): block_chance = float(dict["block_chance"])
	if dict.has("block_value_percent"): block_value_percent = float(dict["block_value_percent"])
	if dict.has("thorns_percent"): thorns_percent = float(dict["thorns_percent"])
	if dict.has("tenacity_percent"): tenacity_percent = float(dict["tenacity_percent"])
	if dict.has("damage_reduction_percent"): damage_reduction_percent = float(dict["damage_reduction_percent"])
	if dict.has("crit_avoidance_percent"): crit_avoidance_percent = float(dict["crit_avoidance_percent"])
	if dict.has("anti_armor_pen_percent"): anti_armor_pen_percent = float(dict["anti_armor_pen_percent"])
	if dict.has("anti_armor_pen_flat"): anti_armor_pen_flat = float(dict["anti_armor_pen_flat"])
	if dict.has("lifesteal_percent"): lifesteal_percent = float(dict["lifesteal_percent"])
	if dict.has("mana_steal_percent"): mana_steal_percent = float(dict["mana_steal_percent"])
	if dict.has("move_speed"): move_speed = float(dict["move_speed"])
	if dict.has("cooldown_reduction"): cooldown_reduction = float(dict["cooldown_reduction"])
	if dict.has("double_strike_chance"): double_strike_chance = float(dict["double_strike_chance"])
	if dict.has("triple_strike_chance"): triple_strike_chance = float(dict["triple_strike_chance"])
	recalculate_stats(true)

## Crea una instancia de CharacterStats inicializada desde una sección específica de combat_config.json
static func create_from_config(category: String, default_name: String = "") -> CharacterStats:
	var stats := CharacterStats.new()
	if not default_name.is_empty():
		stats.character_name = default_name
	var cfg = GameConfig.load_json(GameConfig.PATH_COMBAT)
	if cfg.has(category) and cfg[category] is Dictionary:
		stats.load_from_dictionary(cfg[category])
		if not default_name.is_empty() and not cfg[category].has("character_name"):
			stats.character_name = default_name
	else:
		stats.recalculate_stats(true)
	return stats

## Crea una instancia de CharacterStats inicializada con los valores por defecto del jugador desde config/combat_config.json
static func create_player_default() -> CharacterStats:
	return create_from_config("player_default_stats", "Player")

## Crea una instancia de CharacterStats inicializada con los valores por defecto del dummy de práctica desde config/combat_config.json
static func create_dummy_default() -> CharacterStats:
	return create_from_config("dummy_default_stats", "TrainingDummy")

