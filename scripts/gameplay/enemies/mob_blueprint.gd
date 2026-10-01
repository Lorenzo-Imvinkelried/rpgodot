class_name MobBlueprint
extends RefCounted

## Responsabilidad: Definición inmutable de arquetipos de enemigos (Blueprints)
## y generador de estadísticas escaladas polinomialmente por nivel y rango de Jefe.

enum Stance {
	PASSIVE, # Huye o ignora; no inicia combate
	NEUTRAL, # Pacífico hasta ser atacado
	VIOLENT  # Hostil a la vista del jugador
}

var type: String = ""
var name: String = "Enemigo"
var scale: Vector3 = Vector3.ONE
var level: int = 1
var max_hp: int = 100
var max_mp: int = 50
var strength: int = 0
var dexterity: int = 0
var intelligence: int = 0
var vitality: int = 0
var attack: int = 10
var defense: int = 5
var speed: float = 3.8 # Metros por segundo en 3D
var atk_speed: float = 1.0
var attack_delay_factor: float = 0.45 # Momento del impacto en la animación (0.0 a 1.0)
var attack_range: float = 2.0
var leash_radius: float = 18.0 # Rango máximo de persecución desde el Spawn
var range_violent: float = 10.0 # Rango de visión de agresión para Stance.VIOLENT
var malice: float = 0.0
var stance: Stance = Stance.NEUTRAL
var crit_chance: float = 5.0
var crit_damage: float = 150.0
var armor_penetration: int = 0
var accuracy: int = 100
var evasion: int = 0
var xp: int = 100
var weight_kg: float = 70.0
var ground_offset_y: float = 0.0

var skills: Array = []
var equipment_pool: Dictionary = {}

static func stance_from_string(s: String) -> Stance:
	match s.to_lower():
		"passive":
			return Stance.PASSIVE
		"violent":
			return Stance.VIOLENT
		_:
			return Stance.NEUTRAL

static func from_dict(d: Dictionary) -> MobBlueprint:
	var bp := MobBlueprint.new()
	bp.type = str(d.get("type", "mob"))
	bp.name = str(d.get("name", "Enemigo"))

	var stats_dict: Dictionary = d.get("stats", {})
	bp.level = int(stats_dict.get("level", 1))
	bp.max_hp = int(stats_dict.get("hp", 100))
	bp.max_mp = int(stats_dict.get("mp", 50))
	bp.strength = int(stats_dict.get("strength", 0))
	bp.dexterity = int(stats_dict.get("dexterity", 0))
	bp.intelligence = int(stats_dict.get("intelligence", 0))
	bp.vitality = int(stats_dict.get("vitality", 0))
	bp.attack = int(stats_dict.get("attack", 10))
	bp.defense = int(stats_dict.get("defense", 5))

	var raw_speed: float = float(stats_dict.get("speed", 3.8))
	bp.speed = raw_speed / 25.0 if raw_speed > 15.0 else raw_speed

	bp.atk_speed = float(stats_dict.get("atkSpeed", 1.0))
	bp.attack_delay_factor = float(stats_dict.get("attackDelayFactor", 0.45))

	var raw_atk_range: float = float(stats_dict.get("attackRange", 2.0))
	bp.attack_range = raw_atk_range / 20.0 if raw_atk_range > 10.0 else raw_atk_range

	var raw_leash: float = float(stats_dict.get("leashRadius", 18.0))
	bp.leash_radius = raw_leash / 25.0 if raw_leash > 50.0 else raw_leash

	var raw_violent: float = float(stats_dict.get("rangeViolent", 10.0))
	bp.range_violent = raw_violent / 20.0 if raw_violent > 30.0 else raw_violent

	bp.malice = float(stats_dict.get("malice", 0.0))
	bp.stance = stance_from_string(str(stats_dict.get("stance", "neutral")))

	bp.crit_chance = float(stats_dict.get("critChance", 5.0))
	bp.crit_damage = float(stats_dict.get("critDamage", 150.0))
	bp.armor_penetration = int(stats_dict.get("armorPenetration", 0))
	bp.accuracy = int(stats_dict.get("accuracy", 100))
	bp.evasion = int(stats_dict.get("evasion", 0))
	bp.xp = int(stats_dict.get("xp", 100))
	bp.weight_kg = float(stats_dict.get("weightKg", 70.0))
	bp.ground_offset_y = float(stats_dict.get("groundOffsetY", 0.0))

	var raw_scale = stats_dict.get("scale", [1.0, 1.0, 1.0])
	if raw_scale is Array and raw_scale.size() >= 3:
		bp.scale = Vector3(float(raw_scale[0]), float(raw_scale[1]), float(raw_scale[2]))
	elif raw_scale is Array and raw_scale.size() == 2:
		bp.scale = Vector3(float(raw_scale[0]), float(raw_scale[1]), float(raw_scale[0]))
	else:
		bp.scale = Vector3.ONE

	bp.skills = d.get("skills", [])
	bp.equipment_pool = d.get("equipment_pool", {})

	return bp

## Carga todos los blueprints del archivo mobs.json indexados por su campo "type"
static func load_all_blueprints(file_path: String = "res://config/gameplay/mobs.json") -> Dictionary:
	var parsed = GameConfig.load_json_data(file_path)
	var result: Dictionary = {}
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				var bp := from_dict(item)
				result[bp.type] = bp
	elif parsed is Dictionary:
		for k in parsed.keys():
			var entry = parsed[k]
			if entry is Dictionary:
				var bp := from_dict(entry)
				if bp.type == "":
					bp.type = str(k)
				result[bp.type] = bp
	return result

## Genera una instancia tipada de CharacterStats aplicando el escalado polinomial de nivel (Sección 9.1)
func create_character_stats(level_override: int = -1, is_boss: bool = false) -> CharacterStats:
	var target_level: int = level_override if level_override > 0 else level
	var delta_l: int = maxi(0, target_level - level)
	var dl: float = float(delta_l)
	var dl_sq: float = dl * dl

	var stats := CharacterStats.new()
	stats.character_name = name if not is_boss else ("¡JEFE! " + name)
	stats.level = target_level
	stats.weight_kg = weight_kg

	# Fórmulas polinomiales de escalado de la Sección 9.1:
	# HP_max = HP_base * (1.0 + dL * 0.20 + dL^2 * 0.12)
	var hp_mult := 1.0 + (dl * 0.20) + (dl_sq * 0.12)
	# Atk = Atk_base * (1.0 + dL * 0.12 + dL^2 * 0.005)
	var atk_mult := 1.0 + (dl * 0.12) + (dl_sq * 0.005)
	# Def = Def_base * (1.0 + dL * 0.10 + dL^2 * 0.003)
	var def_mult := 1.0 + (dl * 0.10) + (dl_sq * 0.003)
	# XP = XP_base * (1.0 + dL * 0.30 + dL^2 * 0.01)
	var xp_mult := 1.0 + (dl * 0.30) + (dl_sq * 0.01)

	var final_hp := int(round(float(max_hp) * hp_mult))
	var final_atk := int(round(float(attack) * atk_mult))
	var final_def := int(round(float(defense) * def_mult))
	var final_xp := int(round(float(xp) * xp_mult))

	if is_boss:
		final_hp = int(round(final_hp * 2.5))
		final_atk = int(round(final_atk * 1.35))
		final_def = int(round(final_def * 1.3))
		final_xp = int(round(final_xp * 3.0))

	stats.max_hp = final_hp
	stats.current_hp = final_hp
	stats.max_mp = max_mp
	stats.current_mp = max_mp

	stats.base_str = strength + delta_l
	stats.base_agi = dexterity + delta_l
	stats.base_int = intelligence + delta_l
	stats.base_vit = vitality + delta_l

	stats.attack = final_atk
	stats.defense = final_def
	stats.attack_speed = atk_speed
	stats.crit_chance = crit_chance
	stats.crit_damage = crit_damage
	stats.armor_pen_flat = float(armor_penetration)
	stats.accuracy = accuracy
	stats.evasion = evasion

	if is_boss:
		stats.tenacity_percent += 50.0

	return stats
