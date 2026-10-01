class_name SkillWhirlwind
extends BaseSkill

## Responsabilidad: Giro torbellino instantáneo con daño en área (AoE) alrededor del personaje (Slot 8 / Tecla 9).

func _init() -> void:
	id = "torbellino"
	name = "Torbellino"
	icon = "🌪"
	key_label = "9"
	slot_index = 8

	mana_cost = 25
	cooldown = 5.0
	cast_time = 0.0 # Instantáneo
	range_distance = 6.0
	is_aoe = true
	aoe_radius = 6.0

	flat_damage = 55.0
	damage_multiplier = 1.3
	anim_speed_multiplier = 1.5
	threat_multiplier = 1.5
