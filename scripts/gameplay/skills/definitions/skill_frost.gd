class_name SkillFrost
extends BaseSkill

## Responsabilidad: Habilidad de escarcha que inflige daño y ralentiza al objetivo (Slot 5 / Tecla 6).

func _init() -> void:
	id = "escarcha"
	name = "Escarcha"
	icon = "❄"
	key_label = "6"
	slot_index = 5

	mana_cost = 20
	cooldown = 5.0
	cast_time = 0.0 # Instantáneo
	range_distance = 16.0

	flat_damage = 40.0
	damage_multiplier = 1.15
	anim_speed_multiplier = 1.1

	effect_type = "slow"
	effect_duration = 3.0
	effect_value = 35.0 # 35% de ralentización
	threat_multiplier = 1.3
