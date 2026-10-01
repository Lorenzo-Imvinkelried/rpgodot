class_name SkillData
extends BaseSkill

## Responsabilidad: Adaptador y fábrica compatible para definiciones dinámicas de habilidades.
## Hereda de BaseSkill para integrarse con la arquitectura modular de habilidades.

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
) -> BaseSkill:
	var s: BaseSkill = (load("res://scripts/gameplay/skills/skill_data.gd") as GDScript).new()
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
