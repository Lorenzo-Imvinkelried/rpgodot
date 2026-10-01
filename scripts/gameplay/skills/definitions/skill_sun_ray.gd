class_name SkillSunRay
extends BaseSkill

## Responsabilidad: Haz solar radiante de alta concentración y canalización media (Slot 6 / Tecla 7).

func _init() -> void:
	id = "rayo_solar"
	name = "Rayo Solar"
	icon = "✨"
	key_label = "7"
	slot_index = 6

	mana_cost = 30
	cooldown = 6.0
	cast_time = 1.2
	range_distance = 20.0

	flat_damage = 90.0
	damage_multiplier = 1.6
	anim_speed_multiplier = 1.2
	threat_multiplier = 1.5
