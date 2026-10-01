class_name SkillBloodySlash
extends BaseSkill

## Responsabilidad: Tajo lacerante que inflige daño instantáneo y aplica sangrado continuo (Slot 9 / Tecla 0).

func _init() -> void:
	id = "sangrado"
	name = "Tajo Sangriento"
	icon = "🩸"
	key_label = "0"
	slot_index = 9

	mana_cost = 20
	cooldown = 4.0
	cast_time = 0.0 # Instantáneo
	range_distance = 15.0

	flat_damage = 50.0
	damage_multiplier = 1.3
	anim_speed_multiplier = 1.35

	effect_type = "bleed"
	effect_duration = 4.0
	effect_value = 10.0 # 10 de daño por pulso de sangrado
	threat_multiplier = 1.4
