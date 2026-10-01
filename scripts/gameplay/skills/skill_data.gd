class_name SkillData
extends RefCounted

## Responsabilidad: Definición inmutable de propiedades y balance de una habilidad activa.

var id: String = ""
var name: String = ""
var icon: String = ""
var key_label: String = ""
var mana_cost: int = 0
var cooldown: float = 0.0
var cast_time: float = 0.0 # 0.0 = instantáneo, >0 = canalizado con CastBar
var range_distance: float = 18.0
var flat_damage: float = 0.0
var is_aoe: bool = false
var aoe_radius: float = 6.0
var effect_type: String = "" # "slow", "bleed", "stun", ""
var effect_duration: float = 0.0
var effect_value: float = 0.0

static func create(
	p_id: String,
	p_name: String,
	p_icon: String,
	p_key: String,
	p_mana: int,
	p_cd: float,
	p_cast_time: float,
	p_damage: float,
	p_range: float = 18.0,
	p_is_aoe: bool = false,
	p_effect: String = "",
	p_effect_dur: float = 0.0,
	p_effect_val: float = 0.0
):
	var s = (load("res://scripts/gameplay/skills/skill_data.gd") as GDScript).new()
	s.id = p_id
	s.name = p_name
	s.icon = p_icon
	s.key_label = p_key
	s.mana_cost = p_mana
	s.cooldown = p_cd
	s.cast_time = p_cast_time
	s.flat_damage = p_damage
	s.range_distance = p_range
	s.is_aoe = p_is_aoe
	s.effect_type = p_effect
	s.effect_duration = p_effect_dur
	s.effect_value = p_effect_val
	return s
