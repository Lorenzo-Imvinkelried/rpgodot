class_name SkillMeteor
extends BaseSkill

## Responsabilidad: Impacto meteorítico de daño colosal y canalización extendida (Slot 7 / Tecla 8).

func _init() -> void:
	id = "meteorito"
	name = "Meteorito"
	icon = "☄"
	key_label = "8"
	slot_index = 7

	mana_cost = 45
	cooldown = 8.0
	cast_time = 1.5
	range_distance = 20.0

	flat_damage = 130.0
	damage_multiplier = 1.85
	anim_speed_multiplier = 1.3
	threat_multiplier = 1.8
